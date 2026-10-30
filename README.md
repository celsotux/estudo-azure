# Deploy de Aplicação Web com Azure Container Apps, Bicep e Azure DevOps

Versão Azure do projeto [estudo-git](https://github.com/celsotux/estudo-git), que implanta a mesma aplicação de teste na AWS com ECS Fargate, CloudFormation e GitHub Actions. Aqui, toda a infraestrutura é descrita em **Bicep** e o deploy é feito por **Azure Pipelines**.

## Equivalência com o projeto AWS

| AWS (projeto original)             | Azure (este projeto)                          |
|------------------------------------|-----------------------------------------------|
| VPC + sub-redes                    | Virtual Network + sub-rede delegada           |
| AWS Cloud Map                      | Descoberta de serviços nativa do Container Apps Environment |
| ECS Cluster (Fargate)              | Container Apps Environment (perfil Consumption) |
| Application Load Balancer          | Ingress HTTPS nativo do Container Apps        |
| ECS Service + Task Definition      | Container App                                 |
| Amazon ECR                         | Azure Container Registry                      |
| CloudFormation                     | Bicep                                         |
| GitHub Actions (7 workflows)       | Azure Pipelines (2 pipelines)                 |
| Access keys nos secrets            | Service connection com workload identity (sem senha) |

## Estrutura do repositório

```
app/                     Aplicação web estática (HTML/CSS/JS) servida pelo Apache
infra/main.bicep         Infraestrutura base: rede, ACR, identidade e Container Apps Environment
infra/app.bicep          Container App (ingress, probes de health check e autoscaling)
infra/modules/           Módulos Bicep usados pelo main.bicep
azure-pipelines.yml      Pipeline de deploy (infra → build → deploy)
pipelines/destroy.yml    Pipeline manual que remove todo o ambiente
```

## Pré-requisitos

1. Assinatura Azure.
2. Organização e projeto no [Azure DevOps](https://dev.azure.com).
3. **Agentes hospedados liberados:** organizações novas não podem usar os agentes gratuitos da Microsoft até pedir a liberação no [formulário de paralelismo](https://aka.ms/azpipelines-parallelism-request). A aprovação pode levar alguns dias.
4. Os resource providers `Microsoft.App`, `Microsoft.ContainerRegistry` e `Microsoft.OperationalInsights` registrados na assinatura:
   ```bash
   az provider register --namespace Microsoft.App
   az provider register --namespace Microsoft.ContainerRegistry
   az provider register --namespace Microsoft.OperationalInsights
   ```

## Configuração

### 1. Importar o código para o Azure Repos

No projeto do Azure DevOps, vá em **Repos → Import repository**, ou envie este repositório pelo Git:

```bash
git remote add origin https://dev.azure.com/<organizacao>/<projeto>/_git/estudo-azure
git push -u origin main
```

### 2. Criar a service connection

1. Em **Project settings → Service connections → New service connection**, escolha **Azure Resource Manager**.
2. Escolha **Workload identity federation (automatic)**, selecione a assinatura e deixe o resource group em branco.
3. Dê o nome `sc-estudo-azure`. Se usar outro nome, ajuste a variável `azureServiceConnection` nos pipelines.

A service connection recebe o papel **Contributor**, que não basta para este projeto: o Bicep cria uma atribuição de papel (AcrPull) para o app baixar a imagem do ACR. Por isso, dê também o papel **Role Based Access Control Administrator** (ou **User Access Administrator**) à identidade da service connection, no escopo da assinatura:

```bash
az role assignment create \
  --assignee <client-id-da-service-connection> \
  --role "Role Based Access Control Administrator" \
  --scope /subscriptions/<id-da-assinatura>
```

O client ID aparece em **Service connections → sc-estudo-azure → Manage Service Principal**.

### 3. Criar os pipelines

Em **Pipelines → New pipeline → Azure Repos Git**, selecione o repositório e escolha **Existing Azure Pipelines YAML file**:

- `/azure-pipelines.yml`: deploy
- `/pipelines/destroy.yml`: remoção do ambiente

## Deploy

O pipeline `azure-pipelines.yml` roda automaticamente a cada push na `main` que altere `app/` ou `infra/`, e também pode ser executado manualmente. Ele tem três estágios:

| Estágio | O que faz |
|---------|-----------|
| 1 - Infraestrutura | Cria o resource group e aplica o `main.bicep` (VNet, ACR, identidade, Log Analytics e Container Apps Environment) |
| 2 - Build | Gera a imagem Docker e envia ao ACR com a tag do número do build |
| 3 - Deploy | Aplica o `app.bicep` com a nova imagem e mostra a URL pública no log |

Como o Bicep é declarativo, o pipeline pode ser executado quantas vezes for preciso: ele cria o que falta e atualiza o que mudou.

Os valores padrão (resource group `rg-estudo-containerapps`, região `brazilsouth`) ficam na seção `variables` do pipeline.

## Remoção do ambiente

Execute manualmente o pipeline `destroy.yml` e, no campo de confirmação, digite o nome do resource group (`rg-estudo-containerapps`). Ele exclui o resource group inteiro e todos os recursos dentro dele.

## Custos

Com uma réplica mínima, o Container Apps no perfil Consumption fica dentro ou perto da camada gratuita mensal. Os principais custos fixos são o ACR Basic (cerca de US$ 5/mês) e a ingestão de logs no Log Analytics. Lembre-se de rodar o pipeline de remoção ao terminar os estudos.

## Executando localmente

```bash
cd app
docker build -t hit-game-app .
docker run --rm -p 8080:80 hit-game-app
```

Acesse http://localhost:8080 e o health check em http://localhost:8080/healthcheck.

# Deploy de Aplicação Web com Azure Container Apps, Bicep e Azure DevOps

Versão Azure do projeto [estudo-git](https://github.com/celsotux/estudo-git), que implanta a mesma aplicação de teste na AWS com ECS Fargate, CloudFormation e GitHub Actions. Aqui o deploy é feito por **Azure Pipelines**, e a mesma infraestrutura existe em duas versões que rodam em paralelo: **Bicep** e **Terraform**.

## Equivalência com o projeto AWS

| AWS (projeto original)             | Azure (este projeto)                          |
|------------------------------------|-----------------------------------------------|
| VPC + sub-redes                    | Rede gerenciada pelo Container Apps (sem VNet própria) |
| AWS Cloud Map                      | Descoberta de serviços nativa do Container Apps Environment |
| ECS Cluster (Fargate)              | Container Apps Environment (perfil Consumption) |
| Application Load Balancer          | Ingress HTTPS nativo do Container Apps        |
| ECS Service + Task Definition      | Container App                                 |
| Amazon ECR                         | Azure Container Registry                      |
| CloudFormation                     | Bicep ou Terraform                            |
| GitHub Actions (7 workflows)       | Azure Pipelines (4 pipelines: deploy e remoção de cada versão) |
| Access keys nos secrets            | Service connection com workload identity (sem senha) |

## Estrutura do repositório

```
app/                     Aplicação web estática (HTML/CSS/JS) servida pelo Apache
infra/main.bicep         Infraestrutura base em Bicep: ACR, identidade, logs e Container Apps Environment
infra/app.bicep          Container App em Bicep (ingress, probes de health check e autoscaling)
infra/modules/           Módulos Bicep usados pelo main.bicep
terraform/base/          Mesma infraestrutura base, em Terraform
terraform/app/           Mesmo Container App, em Terraform
azure-pipelines.yml      Pipeline de deploy da versão Bicep (infra → build → deploy)
pipelines/destroy.yml    Pipeline manual que remove o ambiente Bicep
pipelines/terraform.yml  Pipeline de deploy da versão Terraform (infra → build → deploy)
pipelines/terraform-destroy.yml  Pipeline manual que remove o ambiente Terraform
pipelines/templates/     Passo reutilizável que roda Terraform com a service connection
pipelines/scripts/       Instala o Terraform, faz login e prepara o estado remoto
docs/passo-a-passo.md    Guia leigo de toda a configuração, do zero ao site no ar
```

Para um passo a passo detalhado e sem jargão, com os problemas encontrados e como resolvê-los, veja [docs/passo-a-passo.md](docs/passo-a-passo.md).

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

- `/azure-pipelines.yml`: deploy (Bicep)
- `/pipelines/destroy.yml`: remoção do ambiente (Bicep)
- `/pipelines/terraform.yml`: deploy (Terraform)
- `/pipelines/terraform-destroy.yml`: remoção do ambiente (Terraform)

Depois de criar, renomeie cada um em **⋮ → Rename/move** (por exemplo `bicep-deploy`, `bicep-destroy`, `terraform-deploy`, `terraform-destroy`), porque o Azure DevOps dá a todos o nome do repositório.

## Deploy

O pipeline `azure-pipelines.yml` roda automaticamente a cada push na `main` que altere `app/` ou `infra/`, e também pode ser executado manualmente. Ele tem três estágios:

| Estágio | O que faz |
|---------|-----------|
| 1 - Infraestrutura | Cria o resource group e aplica o `main.bicep` (ACR, identidade, Log Analytics e Container Apps Environment) |
| 2 - Build | Gera a imagem Docker e envia ao ACR com a tag do número do build |
| 3 - Deploy | Aplica o `app.bicep` com a nova imagem e mostra a URL pública no log |

Como o Bicep é declarativo, o pipeline pode ser executado quantas vezes for preciso: ele cria o que falta e atualiza o que mudou.

Os valores padrão (resource group `rg-estudo-containerapps`, região `brazilsouth`) ficam na seção `variables` do pipeline.

## Versão Terraform

Explicação completa, com diagrama, em [terraform/README.md](terraform/README.md).

O pipeline `pipelines/terraform.yml` faz o mesmo deploy, com os mesmos três estágios, mas usando Terraform no resource group `rg-estudo-containerapps-tf`. Ele roda automaticamente a cada push na `main` que altere `app/` ou `terraform/`, então uma mudança no site atualiza as duas versões.

| Estágio | O que faz |
|---------|-----------|
| 1 - Infraestrutura | Cria (se faltar) a Storage Account do estado e roda `terraform plan` e `apply` em `terraform/base` |
| 2 - Build | Gera a imagem Docker e envia ao ACR da versão Terraform |
| 3 - Deploy | Roda `terraform plan` e `apply` em `terraform/app` com a nova imagem e mostra a URL |

Detalhes:

- **Estado:** fica na Storage Account `sttf<início do ID da assinatura>`, no resource group `rg-estudo-tfstate`, com um arquivo por módulo (`base.tfstate` e `app.tfstate`). O pipeline cria esse armazenamento sozinho na primeira execução, e a remoção não apaga, para o próximo deploy reaproveitar.
- **Login:** usa a mesma service connection `sc-estudo-azure`, sem senha. O passo em `pipelines/templates/terraform-step.yml` repassa o token de workload identity ao Terraform (`ARM_USE_OIDC`).
- **Versões:** Terraform 1.16.7 (instalado pelo pipeline) e provider `azurerm` 4.x, travado no `.terraform.lock.hcl`.
- **Dois módulos:** `base` e `app` têm estados separados, como `main.bicep` e `app.bicep`. O `app` lê as saídas do `base` com `terraform_remote_state`.

Para testar localmente, com `az login` feito:

```bash
terraform -chdir=terraform/base init -backend=false
terraform -chdir=terraform/base validate
```

## Remoção do ambiente

- **Bicep:** execute manualmente o pipeline `destroy.yml` e, no campo de confirmação, digite `rg-estudo-containerapps`. Ele pede a exclusão do resource group e termina na hora (`--no-wait`). O Azure continua apagando em segundo plano por alguns minutos; confira em **Grupos de recursos**.
- **Terraform:** execute manualmente o pipeline `terraform-destroy.yml` e digite `rg-estudo-containerapps-tf`. Ele roda `terraform destroy` no app e depois na base. O resource group `rg-estudo-tfstate` com o estado continua existindo e custa centavos por mês.

## Custos

Com uma réplica mínima, o Container Apps no perfil Consumption fica dentro ou perto da camada gratuita mensal. Os principais custos fixos são o ACR Basic (cerca de US$ 5/mês por versão, então US$ 10 com as duas no ar) e a ingestão de logs no Log Analytics. Lembre-se de rodar os pipelines de remoção ao terminar os estudos.

## Executando localmente

```bash
cd app
docker build -t hit-game-app .
docker run --rm -p 8080:80 hit-game-app
```

Acesse http://localhost:8080 e o health check em http://localhost:8080/healthcheck.

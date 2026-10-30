# Prepara o Terraform dentro da tarefa AzureCLI@2 (com addSpnToEnvironment: true).
# Uso: source pipelines/scripts/terraform-env.sh
set -euo pipefail

TF_VERSION="1.16.7"

# Instala a versão fixa do Terraform, se o agente não tiver
if ! terraform version 2>/dev/null | grep -q "v${TF_VERSION}"; then
  curl -sSfLo /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip"
  mkdir -p "$HOME/.tfbin"
  unzip -oq /tmp/terraform.zip -d "$HOME/.tfbin"
  export PATH="$HOME/.tfbin:$PATH"
fi
terraform version | head -1

# Login do Terraform com a mesma service connection (workload identity, sem senha)
export ARM_CLIENT_ID="$servicePrincipalId"
export ARM_TENANT_ID="$tenantId"
export ARM_OIDC_TOKEN="$idToken"
export ARM_USE_OIDC=true
ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export ARM_SUBSCRIPTION_ID

# Onde o estado do Terraform fica guardado (fora do resource group do app, para sobreviver ao destroy)
export TFSTATE_RG="rg-estudo-tfstate"
export TFSTATE_ACCOUNT="sttf$(echo "$ARM_SUBSCRIPTION_ID" | tr -d '-' | cut -c1-12)"
export TFSTATE_CONTAINER="tfstate"
export TFSTATE_LOCATION="brazilsouth"

# O terraform/app lê o estado do terraform/base com estes valores
export TF_VAR_tfstate_resource_group="$TFSTATE_RG"
export TF_VAR_tfstate_storage_account="$TFSTATE_ACCOUNT"
export TF_VAR_tfstate_container="$TFSTATE_CONTAINER"

export TF_IN_AUTOMATION=true

# Cria a Storage Account do estado, se ainda não existir
tfstate_bootstrap() {
  az group create --name "$TFSTATE_RG" --location "$TFSTATE_LOCATION" --output none
  az storage account create \
    --name "$TFSTATE_ACCOUNT" \
    --resource-group "$TFSTATE_RG" \
    --location "$TFSTATE_LOCATION" \
    --sku Standard_LRS \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --output none
  if ! az storage container-rm show --resource-group "$TFSTATE_RG" --storage-account "$TFSTATE_ACCOUNT" --name "$TFSTATE_CONTAINER" --output none 2>/dev/null; then
    az storage container-rm create --resource-group "$TFSTATE_RG" --storage-account "$TFSTATE_ACCOUNT" --name "$TFSTATE_CONTAINER" --output none
  fi
}

# terraform init apontando para o estado remoto. Uso: tf_init <pasta> <arquivo de estado>
tf_init() {
  terraform -chdir="$1" init -input=false \
    -backend-config="resource_group_name=$TFSTATE_RG" \
    -backend-config="storage_account_name=$TFSTATE_ACCOUNT" \
    -backend-config="container_name=$TFSTATE_CONTAINER" \
    -backend-config="key=$2"
}

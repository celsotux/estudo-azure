variable "image" {
  description = "Imagem completa, ex.: acrxxx.azurecr.io/hit-game-app:123"
  type        = string
}

variable "app_name" {
  type    = string
  default = "hit-game-app"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "min_replicas" {
  type    = number
  default = 1
}

variable "max_replicas" {
  type    = number
  default = 3
}

# Onde está o estado do terraform/base; o pipeline preenche via TF_VAR_*
variable "tfstate_resource_group" {
  type = string
}

variable "tfstate_storage_account" {
  type = string
}

variable "tfstate_container" {
  type    = string
  default = "tfstate"
}

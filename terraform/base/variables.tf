variable "resource_group_name" {
  description = "Resource group onde ficam todos os recursos da versão Terraform"
  type        = string
  default     = "rg-estudo-containerapps-tf"
}

variable "location" {
  type    = string
  default = "brazilsouth"
}

variable "prefix" {
  description = "Prefixo usado no nome dos recursos (só letras minúsculas e números)"
  type        = string
  default     = "estudotf"
}

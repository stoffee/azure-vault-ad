variable "prefix" {
  description = "The prefix used for all resources in this example. Needs to be a short (6 characters) alphanumeric string. Example: `myprefix`."
}

variable "admin_username" {
  description = "The username of the administrator account for both the local accounts, and Active Directory accounts. Example: `myexampleadmin`"
}

variable "admin_password" {
  description = "The password of the administrator account for both the local accounts, and Active Directory accounts. Needs to comply with the Windows Password Policy. Example: `PassW0rd1234!`"
}

variable "vault_download_url" {
  description = "URL to download Vault binary"
}

variable "public_key" {}

variable "subscription_id" {
  default = ""
}

variable "client_id" {
  default = ""
}

variable "client_secret" {
  default = ""
}

variable "tenant_id" {
  default = ""
}

variable "active_directory_domain" {
  description = "The name of the Active Directory domain, for example `consoto.local`"
}

variable "region" {
  default = "West US 2"
}

variable "owner_tag" {
  default = "chrisd@hashicorp.com"
}

variable "ttl_tag" {
  default = "96h"
}

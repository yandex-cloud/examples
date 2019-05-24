locals {
  _user_data   = "${file(var.user_data)}"
  _deploy_root = "${file(var.ad_deploy_root)}"
  _deploy_dc   = "${file(var.ad_deploy_dc)}"
}

##########
# provider
##########

variable "service_account_key_file" {
  type        = "string"
  description = "your service account key file path"
}

variable "cloud_id" {
  type        = "string"
  description = "your cloud id"
}

variable "folder_id" {
  type        = "string"
  description = "your folder id"
}

##########
# vpc
##########

variable "vpc_name" {
  type        = "string"
  description = "vpc name"
}

##########
# network
##########

variable "subnet_name" {
  type    = "string"
  default = "msft-demo-subnet"
}

variable "subnet_cidr" {
  type = "string"
}

variable "zone_names" {
  type = "list"
}

variable "zone_short_names" {
  type = "list"
}

##########
# instance
##########

variable "name" {
  type = "string"
}

variable "number" {
  type = "string"
}

variable "cores" {
  type    = "string"
  default = 2
}

variable "memory" {
  type    = "string"
  default = 4
}

variable "boot_disk_image_family" {
  type    = "string"
  default = "windows-2016-gvlk"
}

variable "boot_disk_size" {
  type    = "string"
  default = 30
}

variable "user" {
  type = "string"
}

variable "pass" {
  type = "string"
}

variable "user_data" {
  type = "string"
}

##########
# active directory
##########

variable "ad_smadminpass" {
  type = "string"
}

variable "ad_domainname" {
  type = "string"
}

variable "ad_deploy_root" {
  type = "string"
}

variable "ad_deploy_dc" {
  type = "string"
}

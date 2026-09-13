# variables.tf
#
# WHAT THIS FILE DOES:
# "variables" are Terraform's version of function parameters - values you
# can change without editing the actual resource code. Anywhere you see
# var.something in the other .tf files, it's pulling the value from here
# (or from what you type/pass in when you run terraform apply).
#
# Each variable can have:
#   - a description (shows up when you run `terraform plan` and in docs)
#   - a type (string, number, bool, etc. - Terraform validates this for you)
#   - a default (optional - if set, you don't have to supply a value)

variable "location" {
  description = "Azure region to deploy into"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group that will contain everything"
  type        = string
  default     = "rg-3tier-webapp-tf"
}

variable "unique_suffix" {
  description = "A short unique string appended to globally-unique resource names (e.g. your initials + a few digits). Change this to something only you would pick."
  type        = string
}

variable "sql_admin_login" {
  description = "Admin username for the Azure SQL server"
  type        = string
  default     = "sqladmin"
}

# `sensitive = true` tells Terraform to hide this value in the plan/apply
# output and in the CLI logs - it will still be visible in the state file
# (state files are never fully "secret" - see the README for how to handle
# that in a real project).
variable "sql_admin_password" {
  description = "Admin password for the Azure SQL server - never put the real value in this file or in terraform.tfvars if that file is committed to git"
  type        = string
  sensitive   = true
}

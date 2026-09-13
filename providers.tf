# providers.tf
#
# WHAT THIS FILE DOES:
# Every Terraform project needs to declare two things before it can do
# anything else:
#   1. Which "providers" it needs (plugins that know how to talk to a
#      specific cloud - here, Azure).
#   2. Configuration for those providers (e.g. "use my logged-in Azure CLI
#      session, don't ask me for credentials separately").
#
# The "terraform" block below is metadata about the project itself: which
# Terraform CLI version it needs, and which provider (and version) to
# download when you run `terraform init`.

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}

# The "provider" block configures the azurerm plugin itself.
# `features {}` is required even when empty - it's where you'd customize
# provider-wide behavior (e.g. auto-delete resources on destroy), but the
# defaults are fine for this project.
#
# Authentication: this uses whatever you're logged into via `az login`.
# Terraform does NOT need your password - it borrows your Azure CLI session.
provider "azurerm" {
  features {}
}

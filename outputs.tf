# outputs.tf
#
# WHAT THIS FILE DOES:
# "outputs" are values Terraform prints to your screen after a successful
# apply, and that other tools/scripts can read programmatically (e.g.
# `terraform output application_url`). Think of them as the "here's what
# you got" summary at the end of the build.

output "application_url" {
  description = "Public entry point - browse to this"
  value       = "http://${azurerm_public_ip.appgw.ip_address}"
}

output "backend_app_url" {
  description = "Direct URL to the backend App Service (useful for debugging, blocked by access restriction from anywhere but the web subnet)"
  value       = "https://${azurerm_linux_web_app.backend.default_hostname}"
}

output "frontend_app_url" {
  description = "Direct URL to the frontend App Service"
  value       = "https://${azurerm_linux_web_app.frontend.default_hostname}"
}

output "sql_server_fqdn" {
  description = "Private SQL server hostname"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

# NOTE ON SECRETS: local.sql_connection_string contains the SQL password
# in plain text. We deliberately do NOT create an output for it here -
# outputs are easy to accidentally print, share, or log. It's already
# stored inside the backend App Service's connection string setting
# directly (see appservice.tf), which is all this project needs.
#
# The password DOES still exist in plain text inside terraform.tfstate
# (the state file) - see the README section "About the state file and
# secrets" for what this means and how a production project handles it
# differently (typically: Key Vault + a Key Vault reference in app
# settings, so the secret is never resolved through Terraform variables
# at all).

# autoscale.tf
#
# WHAT THIS FILE DOES:
# Autoscale rules on the shared App Service Plan. Maps to Step 8 of the
# portal guide.

resource "azurerm_monitor_autoscale_setting" "main" {
  name                = "autoscale-3tier-${var.unique_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  target_resource_id  = azurerm_service_plan.main.id
  enabled             = true

  profile {
    name = "DefaultProfile"

    capacity {
      minimum = "2" # 2 instances minimum for high availability
      maximum = "5" # cap at 5 to bound cost
      default = "2"
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}

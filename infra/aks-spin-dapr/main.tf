resource "random_id" "infix" {
  byte_length = 4
}

# Local for tag to attach to all items
locals {
  base_name = "${var.resource_prefix}${random_id.infix.hex}"
  tags = merge(
    var.tags,
  )
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.base_name}"
  location = var.location
  tags     = local.tags
}

module "loganalytics" {
  source              = "../modules/az/loganalytics"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
  resource_prefix     = local.base_name
}

module "aks" {
  source              = "../modules/az/aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
  resource_prefix     = local.base_name
  cluster_admins      = var.cluster_admins
  system_nodepool     = var.system_nodepool
  user_nodepools      = var.user_nodepools
  loganalytics_id     = module.loganalytics.LOGANALYTICS_ID
  loganalytics_name   = module.loganalytics.LOGANALYTICS_NAME
  acr_id              = module.acr.CONTAINER_REGISTRY_ID
}

module "app-insights" {
  source              = "../modules/az/app-insights"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
  resource_prefix     = local.base_name
  loganalytics_id     = module.loganalytics.LOGANALYTICS_ID
}

module "grafana" {
  count               = var.monitoring == "grafana" ? 1 : 0
  source              = "../modules/az/grafana"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
  resource_prefix     = local.base_name
  loganalytics_id     = module.loganalytics.LOGANALYTICS_ID
  cluster_id          = module.aks.CLUSTER_ID
  cluster_name        = module.aks.CLUSTER_NAME
}

module "container-insights" {
  count               = var.monitoring == "container-insights" ? 1 : 0
  source              = "../modules/az/container-insights"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
  resource_prefix     = local.base_name
  loganalytics_id     = module.loganalytics.LOGANALYTICS_ID
  cluster_id          = module.aks.CLUSTER_ID
}

module "acr" {
  source              = "../modules/az/acr"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
  resource_prefix     = local.base_name
}

module "servicebus" {
  source              = "../modules/az/servicebus"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Premium"
  tags                = var.tags
  resource_prefix     = local.base_name
}

module "storage" {
  source              = "../modules/az/storage"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
  resource_prefix     = local.base_name
}

module "dapr" {
  count               = var.dapr_deploy ? 1 : 0
  source              = "../modules/helm/dapr"
  resource_group_name = azurerm_resource_group.rg.name
  cluster_name        = module.aks.CLUSTER_NAME
  dapr_namespace      = var.dapr_namespace
  dapr_version        = var.dapr_version
  dapr_agentpool      = coalesce(var.dapr_agentpool, module.aks.DEFAULT_NODEPOOL_NAME)
  providers = {
    helm = helm
  }
  depends_on = [
    module.aks
  ]
}

module "kwasm" {
  count              = var.kwasm_deploy ? 1 : 0
  source             = "../modules/helm/kwasm"
  namespace          = var.kwasm_namespace
  installer_image    = var.kwasm_installer_image
  node_selector      = var.kwasm_node_selector
  runtime_class_name = var.kwasm_runtime_class_name
  providers = {
    kubernetes = kubernetes
  }
  depends_on = [
    module.aks
  ]
}

# module "cert_manager" {
#   count              = var.spin_deploy == "operator" ? 1 : 0
#   source             = "../modules/helm/cert-manager"
#   providers = {
#     kubernetes = kubernetes
#   }
#   depends_on = [
#     module.aks
#   ]
# }
#
# module "spin_operator" {
#   count              = var.spin_deploy == "operator" ? 1 : 0
#   source             = "../modules/helm/spin-operator"
#   providers = {
#     kubernetes = kubernetes
#   }
#   depends_on = [
#     module.cert_manager
#   ]
# }
#
module "keda" {
  count     = var.keda_deploy ? 1 : 0
  source    = "../modules/helm/keda"
  namespace = var.keda_namespace
  providers = {
    kubernetes = kubernetes
  }
  depends_on = [
    module.aks
  ]
}

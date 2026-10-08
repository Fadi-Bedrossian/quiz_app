resource "azurerm_user_assigned_identity" "cluster" {
  name                = "${var.prefix}-quiz-aks-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_role_assignment" "network" {
  scope                = var.resource_group_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
}

resource "time_sleep" "network_rbac_propagation" {
  create_duration = "30s"
  depends_on      = [azurerm_role_assignment.network]
}

resource "azurerm_kubernetes_cluster" "main" {
  name                              = "${var.prefix}-quiz-aks"
  location                          = var.location
  resource_group_name               = var.resource_group_name
  dns_prefix                        = "${var.prefix}-quiz"
  sku_tier                          = "Free"
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  role_based_access_control_enabled = true
  automatic_upgrade_channel         = "patch"
  node_os_upgrade_channel           = "NodeImage"

  api_server_access_profile {
    authorized_ip_ranges = ["0.0.0.0/32"]
  }

  azure_active_directory_role_based_access_control {
    tenant_id          = var.tenant_id
    azure_rbac_enabled = true
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = var.node_vm_size
    vnet_subnet_id               = var.subnet_id
    auto_scaling_enabled         = true
    node_count                   = 2
    min_count                    = 2
    max_count                    = 3
    os_disk_size_gb              = 64
    os_sku                       = "AzureLinux3"
    type                         = "VirtualMachineScaleSets"
    only_critical_addons_enabled = false
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    service_cidr        = "10.50.0.0/16"
    dns_service_ip      = "10.50.0.10"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  lifecycle {
    ignore_changes = [default_node_pool[0].node_count]
  }

  depends_on = [time_sleep.network_rbac_propagation]
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

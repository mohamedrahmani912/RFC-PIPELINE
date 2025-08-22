# main.tf
# Groupe de ressources
resource "azurerm_resource_group" "rfc_rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "Infrastructure"
    Project     = "RFC-AD-Deployment"
    Owner       = "Stagiaire"
  }
}

# Réseau virtuel
resource "azurerm_virtual_network" "rfc_vnet" {
  name                = "vnet-rfc-infra-we"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rfc_rg.location
  resource_group_name = azurerm_resource_group.rfc_rg.name

  tags = {
    Environment = "Infrastructure"
    Project     = "RFC-AD-Deployment"
  }
}

# Sous-réseau pour les contrôleurs de domaine
resource "azurerm_subnet" "ad_subnet" {
  name                 = "snet-ad-rfc-infra-we"
  resource_group_name  = azurerm_resource_group.rfc_rg.name
  virtual_network_name = azurerm_virtual_network.rfc_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Sous-réseau pour les serveurs membres
resource "azurerm_subnet" "member_subnet" {
  name                 = "snet-member-rfc-infra-we"
  resource_group_name  = azurerm_resource_group.rfc_rg.name
  virtual_network_name = azurerm_virtual_network.rfc_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Groupe de sécurité réseau pour AD
resource "azurerm_network_security_group" "ad_nsg" {
  name                = "nsg-ad-rfc-infra-we"
  location            = azurerm_resource_group.rfc_rg.location
  resource_group_name = azurerm_resource_group.rfc_rg.name

  security_rule {
    name                       = "Allow_RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow_LDAP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow_Kerberos"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "88"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Infrastructure"
    Project     = "RFC-AD-Deployment"
  }
}

# Association NSG au sous-réseau AD
resource "azurerm_subnet_network_security_group_association" "ad_nsg_assoc" {
  subnet_id                 = azurerm_subnet.ad_subnet.id
  network_security_group_id = azurerm_network_security_group.ad_nsg.id
}

# Interface réseau pour le serveur AD
resource "azurerm_network_interface" "ad_nic" {
  name                = "nic-ad-rfc-infra-we"
  location            = azurerm_resource_group.rfc_rg.location
  resource_group_name = azurerm_resource_group.rfc_rg.name

  ip_configuration {
    name                          = "ipconfig-ad"
    subnet_id                     = azurerm_subnet.ad_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ad_pip.id
  }
}

# Interface réseau pour le serveur membre
resource "azurerm_network_interface" "member_nic" {
  name                = "nic-member-rfc-infra-we"
  location            = azurerm_resource_group.rfc_rg.location
  resource_group_name = azurerm_resource_group.rfc_rg.name

  ip_configuration {
    name                          = "ipconfig-member"
    subnet_id                     = azurerm_subnet.member_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.member_pip.id
  }
}

# Adresses IP publiques
resource "azurerm_public_ip" "ad_pip" {
  name                = "pip-ad-rfc-infra-we"
  location            = azurerm_resource_group.rfc_rg.location
  resource_group_name = azurerm_resource_group.rfc_rg.name
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "member_pip" {
  name                = "pip-member-rfc-infra-we"
  location            = azurerm_resource_group.rfc_rg.location
  resource_group_name = azurerm_resource_group.rfc_rg.name
  allocation_method   = "Static"
}

# Groupe de disponibilité
resource "azurerm_availability_set" "rfc_as" {
  name                         = "as-rfc-infra-we"
  location                     = azurerm_resource_group.rfc_rg.location
  resource_group_name          = azurerm_resource_group.rfc_rg.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

# Machine virtuelle Active Directory
resource "azurerm_virtual_machine" "ad_vm" {
  name                  = "vm-ad-dc-rfc-infra-we"
  location              = azurerm_resource_group.rfc_rg.location
  resource_group_name   = azurerm_resource_group.rfc_rg.name
  network_interface_ids = [azurerm_network_interface.ad_nic.id]
  vm_size               = "Standard_B2s"
  availability_set_id   = azurerm_availability_set.rfc_as.id

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "disk-os-ad-rfc-infra-we"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "AD-DC01"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

  tags = {
    Environment = "Infrastructure"
    Role        = "DomainController"
    Project     = "RFC-AD-Deployment"
  }
}

# Machine virtuelle membre
resource "azurerm_virtual_machine" "member_vm" {
  name                  = "vm-member01-rfc-infra-we"
  location              = azurerm_resource_group.rfc_rg.location
  resource_group_name   = azurerm_resource_group.rfc_rg.name
  network_interface_ids = [azurerm_network_interface.member_nic.id]
  vm_size               = "Standard_B2s"
  availability_set_id   = azurerm_availability_set.rfc_as.id

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "disk-os-member-rfc-infra-we"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "MEMBER01"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

  tags = {
    Environment = "Infrastructure"
    Role        = "MemberServer"
    Project     = "RFC-AD-Deployment"
  }
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "rfc_law" {
  name                = "law-rfc-infra-we"
  location            = azurerm_resource_group.rfc_rg.location
  resource_group_name = azurerm_resource_group.rfc_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Extension de monitoring pour VM AD
resource "azurerm_virtual_machine_extension" "ad_monitoring" {
  name                 = "MonitoringAgent"
  virtual_machine_id   = azurerm_virtual_machine.ad_vm.id
  publisher            = "Microsoft.EnterpriseCloud.Monitoring"
  type                 = "MicrosoftMonitoringAgent"
  type_handler_version = "1.0"
  settings = jsonencode({
    workspaceId = azurerm_log_analytics_workspace.rfc_law.workspace_id
  })
  protected_settings = jsonencode({
    workspaceKey = azurerm_log_analytics_workspace.rfc_law.primary_shared_key
  })
}

# Extension de monitoring pour VM membre
resource "azurerm_virtual_machine_extension" "member_monitoring" {
  name                 = "MonitoringAgent"
  virtual_machine_id   = azurerm_virtual_machine.member_vm.id
  publisher            = "Microsoft.EnterpriseCloud.Monitoring"
  type                 = "MicrosoftMonitoringAgent"
  type_handler_version = "1.0"
  settings = jsonencode({
    workspaceId = azurerm_log_analytics_workspace.rfc_law.workspace_id
  })
  protected_settings = jsonencode({
    workspaceKey = azurerm_log_analytics_workspace.rfc_law.primary_shared_key
  })
}
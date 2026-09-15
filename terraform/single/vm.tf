variable "ssh_public_key" {
  type = string
  description = "SSH public key for VM"
}

variable "mysql_admin_password" {
  type = string
  description = "MySQL admin password"
}

# 1. 批量创建 40 台应用网络网卡 (Static IP: 10.200.10.11 ~ 10.200.10.50)
resource "azurerm_network_interface" "nic_app" {
  count               = 1
  name                = "emb-app-${format("%02d", count.index + 1)}-nic"
  location            = azurerm_resource_group.rg_prod.location
  resource_group_name = azurerm_resource_group.rg_prod.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_app.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.200.10.${count.index + 11}"
  }

  tags = azurerm_resource_group.rg_prod.tags
}

# 2. 批量部署 40 台 Ubuntu 22.04 应用主机 (Standard_D4s_v3)
resource "azurerm_linux_virtual_machine" "vm_app" {
  count               = 1
  name                = "emb-app-${format("%02d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.rg_prod.name
  location            = azurerm_resource_group.rg_prod.location
  size                = "Standard_D4s_v3"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.nic_app[count.index].id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # 关键：开启系统分配的托管标识，授权其安全读取 Key Vault
  identity {
    type = "SystemAssigned"
  }

  tags = azurerm_resource_group.rg_prod.tags
}

# ==============================================================================
# DATABASE PROVISIONING (PaaS - Azure Database for MySQL Flexible Server)
# ==============================================================================

# 3. 创建私有 DNS 区域及虚拟网络链接，实现内网 FQDN 无缝解析
resource "azurerm_private_dns_zone" "mysql_dns" {
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.rg_prod.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql_dns_link" {
  name                  = "vnet-emberline-prod-link"
  resource_group_name   = azurerm_resource_group.rg_prod.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet_spoke.id
}

# 4. 创建 Azure Database for MySQL 灵活服务器高可用实例
resource "azurerm_mysql_flexible_server" "mysql" {
  name                         = "emberline-mysql-prod"
  resource_group_name          = azurerm_resource_group.rg_prod.name
  location                     = azurerm_resource_group.rg_prod.location
  administrator_login          = "emberlineadmin"
  administrator_password       = "Emberline_Admin_Secure_Password_2026"
  backup_retention_days        = 35
  geo_redundant_backup_enabled = true
  delegated_subnet_id          = azurerm_subnet.subnet_db.id
  private_dns_zone_id          = azurerm_private_dns_zone.mysql_dns.id
  sku_name                     = "B_Standard_B1ms"
  version                      = "8.0.21"
  zone                         = "1"

  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }

  storage {
    auto_grow_enabled = true
    size_gb           = 1536
    iops              = 20000
  }

  tags = azurerm_resource_group.rg_prod.tags
}

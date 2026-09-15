terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.60.0"
    }
  }

}

provider "azurerm" {
  features {}
  subscription_id = "3bbc5821-b30f-476a-81c2-795ae462405a"
}

# 1. 创建核心生产资源组
resource "azurerm_resource_group" "rg_prod" {
  name     = "rg-emberline-prod"
  location = "East Asia"
  tags = {
    Environment = "Production"
    Project     = "Emberline-Migration"
    Owner       = "Emberline-IT"
  }
}

# 2. 创建核心分支虚拟网络 (Spoke VNet)
resource "azurerm_virtual_network" "vnet_spoke" {
  name                = "VNet-Spoke-Prod"
  location            = azurerm_resource_group.rg_prod.location
  resource_group_name = azurerm_resource_group.rg_prod.name
  address_space       = ["10.200.0.0/16"]
  tags                = azurerm_resource_group.rg_prod.tags
}

# 3. 创建应用子网 (AppSubnet)
resource "azurerm_subnet" "subnet_app" {
  name                 = "AppSubnet"
  resource_group_name  = azurerm_resource_group.rg_prod.name
  virtual_network_name = azurerm_virtual_network.vnet_spoke.name
  address_prefixes     = ["10.200.10.0/24"]
}

# 4. 创建数据库子网 (DBSubnet)
resource "azurerm_subnet" "subnet_db" {
  name                 = "DBSubnet"
  resource_group_name  = azurerm_resource_group.rg_prod.name
  virtual_network_name = azurerm_virtual_network.vnet_spoke.name
  address_prefixes     = ["10.200.20.0/24"]

  # 委托给 MySQL 灵活服务器以支持私网集成
  delegation {
    name = "mysql-delegation"
    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# 5. 创建网络安全组 - 数据库层 (NSG-Prod-DB)
resource "azurerm_network_security_group" "nsg_db" {
  name                = "NSG-Prod-DB"
  location            = azurerm_resource_group.rg_prod.location
  resource_group_name = azurerm_resource_group.rg_prod.name

  # 仅允许应用网段以 TCP 3306 端口访问数据库
  security_rule {
    name                       = "Allow-App-MySQL"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "10.200.10.0/24"
    destination_address_prefix = "10.200.20.0/24"
  }

  # 默认拦截所有其余未授权流量
  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 65000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = azurerm_resource_group.rg_prod.tags
}

# 6. 关联数据库网络安全组至数据库子网
resource "azurerm_subnet_network_security_group_association" "db_nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet_db.id
  network_security_group_id = azurerm_network_security_group.nsg_db.id
}

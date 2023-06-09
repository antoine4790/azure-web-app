# Configure the Azure provider
terraform {
  backend "remote" {
    # The name of your Terraform Cloud organization.
    organization = "solution-optimum"

    # The name of the Terraform Cloud workspace to store Terraform state files in.
    workspaces {
      name = "azure-web-app"
    }
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.50"
    }
    //for managing repo , users, organizations
    /* github = {
      source  = "integrations/github"
      version = "~> 4.0"
    } */
  }

  required_version = ">= 1.3.0"
}
provider "azurerm" {
  subscription_id = "05553212-7bf6-424a-871f-31fdd74b1374"
  client_id       = "cdffefe8-2796-4632-97d8-7f36e7804903"
  client_secret   = "~z.8Q~0KFZdKvqoKA-dPyq5yOBdif8YuVErTJc4b"
  tenant_id       = "cfd43742-6d98-4e8e-ab62-04bfa5ccdf00"
  features {}
}
/* provider "github" {
  token = "<personal-access-token>"
  owner = "antoine4790"
} */

#utilisation d'un subnet deja créé sur Azure
/* data "azurerm_subnet" "subnet1" {
  name                 = "Subnet1"
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.resource_group_name
} */

#Used for Azure Key Vault
data "azurerm_client_config" "current" {}

/* data "cloudinit_config" "linux_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = "packages: ['nginx']"
  }

} */

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = "westeurope"

  tags = {
    Environment = "Terraform Webapp Plan Youtube Getting Started"
    Team        = "DevOps"
  }
}

#For deployment of a webapp
resource "azurerm_service_plan" "app_service_plan" {
  name                = "app-service-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "B1"
  os_type             = "Windows"
  depends_on          = [azurerm_resource_group.rg]
}

resource "azurerm_windows_web_app" "web_app" {
  name                = "web-app20230525"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.app_service_plan.location
  service_plan_id     = azurerm_service_plan.app_service_plan.id

  site_config {

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v7.0"
    }
  }
  depends_on = [azurerm_service_plan.app_service_plan,
  azurerm_resource_group.rg]
}

resource "azurerm_app_service_source_control" "source_control" {
  app_id                 = azurerm_windows_web_app.web_app.id
  repo_url               = "https://github.com/nurseplaning/NursePlanning"
  branch                 = "master_working"
  use_manual_integration = true
  use_mercurial          = false
  depends_on             = [azurerm_windows_web_app.web_app]
}

//doublon par rapport la creation via github.com du token pour Tf
/* resource "azurerm_source_control_token" "github_token" {
  type  = "GitHub"
  token = "ghaot-YgP7GawK4MiQrW2B"
} */

resource "azurerm_sql_server" "sql_server" {
  name                         = "sql-server20230525"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = var.vm_password

}

resource "azurerm_sql_database" "sql-database" {
  name                = "WebNursePlanningBD"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  server_name         = azurerm_sql_server.sql_server.name
  depends_on          = [azurerm_sql_server.sql_server]
}

resource "azurerm_sql_firewall_rule" "app_server_firewall_rule" {
  name                = "app-server-firewall-rule"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_sql_server.sql_server.name
  start_ip_address    = "86.210.22.148"
  end_ip_address      = "86.210.22.148"
  depends_on = [
    azurerm_sql_server.sql_server,
    azurerm_resource_group.rg
  ]
}
//allow azure services to acces sql server and sql db
resource "azurerm_sql_firewall_rule" "app_server_firewall_rule_azure_services" {
  name                = "app-server-firewall-rule-azure-services"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_sql_server.sql_server.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
  depends_on = [
    azurerm_sql_server.sql_server,
    azurerm_resource_group.rg
  ]
}

resource "null_resource" "init_sql_script" {
  provisioner "local-exec" {
    command = "sqlcmd -S sql-server20230525.database.windows.net -U sqladmin -P Azure@123 -d app-db -i init.sql"
  }
  depends_on = [ azurerm_sql_server.sql_server ]
}
/* resource "azurerm_storage_account" "storage_account" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  depends_on               = [azurerm_resource_group.rg]
}

#container pour stocker des fichiers
resource "azurerm_storage_container" "data" {
  name                  = var.storage_container_name
  storage_account_name  = azurerm_storage_account.storage_account.name
  container_access_type = "blob"
  depends_on            = [azurerm_storage_account.storage_account]
}

resource "azurerm_storage_blob" "IIS_config" {
  name                   = var.Custom_IISconfig_file_name
  storage_account_name   = azurerm_storage_account.storage_account.name
  storage_container_name = azurerm_storage_container.data.name
  type                   = "Block"
  source                 = var.Custom_IISconfig_file_name
  depends_on             = [azurerm_storage_container.data]
} 

resource "azurerm_virtual_network" "app_network" {
  name                = var.virtual_network_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  depends_on          = [azurerm_resource_group.rg]
}

resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on           = [azurerm_virtual_network.app_network]
}

//utile pour definir des filtres sur des ports
resource "azurerm_network_security_group" "app-network-group" {
  name                = var.network_security_group_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  security_rule {
    name                       = "security-rule-80"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "security-rule-22"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "network_group_association" {
  subnet_id                 = azurerm_subnet.subnet1.id
  network_security_group_id = azurerm_network_security_group.app-network-group.id
  depends_on = [
    azurerm_network_security_group.app-network-group,
    azurerm_subnet.subnet1
  ]
}

resource "azurerm_network_interface" "app_interface" {
  name                = "app-interface"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app_public_ip.id
  }
  depends_on = [
    azurerm_virtual_network.app_network,
    azurerm_public_ip.app_public_ip,
    azurerm_subnet.subnet1
  ]
}

resource "azurerm_linux_virtual_machine" "linux_machine" {
  name                = "linux-machine"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "linuxusr"
  admin_password      = var.vm_password
  custom_data         = data.cloudinit_config.linux_config.rendered #applique une config specifique sur la Vm
  network_interface_ids = [
    azurerm_network_interface.app_interface.id,
  ]

  admin_ssh_key {
    username   = "linuxusr"
    public_key = file("~/.ssh/id_rsa.pub")
    # public_key = tls_private_key.linux_key.public_key_openssh (ssh cmd authentication without key doesn't work)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  depends_on = [
    azurerm_network_interface.app_interface,
    # tls_private_key.linux_key
  ]
}

resource "azurerm_public_ip" "app_public_ip" {
  name                = "app-public-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  depends_on          = [azurerm_resource_group.rg]
}
#Data disk for azure VM
resource "azurerm_managed_disk" "data_disk" {
  name                 = "data-disk"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "16"
  depends_on           = [azurerm_linux_virtual_machine.linux_machine]
}

resource "azurerm_virtual_machine_data_disk_attachment" "data_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.data_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.linux_machine.id
  lun                = "10"
  caching            = "ReadWrite"
  depends_on = [
    azurerm_linux_virtual_machine.linux_machine,
    azurerm_managed_disk.data_disk
  ]
}

resource "azurerm_availability_set" "app_set" {
  name                         = "app-set"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  platform_fault_domain_count  = 3
  platform_update_domain_count = 3
  managed                      = true
  depends_on                   = [azurerm_resource_group.rg]
}

//#install webserver on virtual machine via script IIS_config.ps1
//resource "azurerm_virtual_machine_extension" "app_vm_extension" {
//  name                 = "app-vm-extension"
//  virtual_machine_id   = azurerm_linux_virtual_machine.linux_machine.id
//  publisher            = "Microsoft.Compute"
//  type                 = "CustomScriptExtension"
//  type_handler_version = "1.9"
//  depends_on           = [azurerm_storage_blob.IIS_config]
//  settings             = <<SETTINGS
// {
//  "fileUris": ["https://${azurerm_storage_account.storage_account.name}.blob.core.windows.net/${azurerm_storage_container.data.name}/${azurerm_storage_blob.IIS_config.name}"],
//  "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file ${azurerm_storage_blob.IIS_config.name}"
// }
//SETTINGS

//}

resource "azurerm_key_vault" "app_keyvault" {
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Get"
    ]

    secret_permissions = [
      "Set",
      "Get",
      "Delete",
      "Purge",
      "Recover"
    ]

    storage_permissions = [
      "Get",
    ]
  }
  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_key_vault_secret" "vm_password_secret" {
  name         = "vm-password-secret"
  value        = var.vm_password
  key_vault_id = azurerm_key_vault.app_keyvault.id
  depends_on   = [azurerm_key_vault.app_keyvault]
}

resource "tls_private_key" "linux_key" {
  algorithm = "RSA"
}


resource "local_file" "linux_private_key" {
  content  = tls_private_key.linux_key.private_key_pem
  filename = "linuxkey.pem"
}
*/

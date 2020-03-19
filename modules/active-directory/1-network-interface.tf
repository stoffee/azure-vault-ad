resource "azurerm_public_ip" "static" {
  name                         = "${var.prefix}-client-ppip"
  location                     = "${var.location}"
  resource_group_name          = "${var.resource_group_name}"
  public_ip_address_allocation = "static"
}

resource "azurerm_network_interface" "primary-dc" {
  name                      = "${var.prefix}-dc-primary"
  location                  = "${var.location}"
  resource_group_name       = "${var.resource_group_name}"
  internal_dns_name_label   = "${local.virtual_machine_name}-dc"
  network_security_group_id = "${azurerm_network_security_group.tf_nsg.id}"

  ip_configuration {
    name                          = "primary-dc"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.static.id}"
  }
}

resource "azurerm_network_security_group" "tf_nsg" {
  name                = "${var.prefix}-nsg-dc"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  security_rule {
    name                       = "ALL"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "ALL_OUT"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

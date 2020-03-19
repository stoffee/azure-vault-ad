locals {
  virtual_machine_name       = "${var.prefix}-client"
  virtual_machine_name_vault = "${var.prefix}-vault"
}

resource "azurerm_virtual_machine" "vault" {
  name                          = "${local.virtual_machine_name_vault}"
  location                      = "${var.location}"
  resource_group_name           = "${var.resource_group_name}"
  network_interface_ids         = ["${azurerm_network_interface.primary.id}"]
  vm_size                       = "Standard_F2"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }


  storage_os_disk {
    name              = "${local.virtual_machine_name_vault}-disk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.virtual_machine_name_vault}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
    custom_data    = "${data.template_file.setup.rendered}"
  }

  os_profile_linux_config {
    disable_password_authentication = false

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${var.public_key}"
    }
  }

  //depends_on = ["null_resource.wait-for-domain-to-provision"]
}

// NOTE: this is a hack.
// the AD Domain takes ~7m to provision, so we don't try and join an non-existant domain we sleep
// unfortunately we can't depend on the Domain Creation VM Extension since there's a reboot.
// We sleep for 12 minutes here to give Azure some breathing room.
/*
resource "null_resource" "wait-for-domain-to-provision" {
  provisioner "local-exec" {
    #command = "sleep 720"
    command = "sleep 60"
  }
}
*/

data "template_file" "setup" {
  template = "${file("${path.module}/setup.tpl")}"

  vars = {
    vault_download_url = "${var.vault_download_url}"
    active_directory_domain          = "${var.active_directory_domain}"
    ad_ip              = "${var.ad_ip}"
  }
}


data "template_file" "format_ssh" {
  template = "connect to host with following command: ssh $${user}@$${admin}"

  vars {
    admin = "${azurerm_public_ip.static-vault.ip_address}"    
    user  = "${var.admin_username}"
  }
}
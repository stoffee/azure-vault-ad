output "public_ip_address_vault" {
  value = "${azurerm_public_ip.static-vault.ip_address}"
}

output "ssh_info" {
  value = "${data.template_file.format_ssh.rendered}"
}

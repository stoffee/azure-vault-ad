provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
  version         = "=1.3.1"
}

locals {
  resource_group_name = "${var.prefix}-rg-rg"
}

resource "azurerm_resource_group" "test" {
  name     = "${local.resource_group_name}"
  location = "${var.region}"

  tags = {
    Owner = "${var.owner_tag}"
    TTL   = "${var.ttl_tag}"
  }
}

module "network" {
  source              = "./modules/network"
  prefix              = "${var.prefix}"
  resource_group_name = "${azurerm_resource_group.test.name}"
  location            = "${azurerm_resource_group.test.location}"
}

module "active-directory-domain" {
  source              = "./modules/active-directory"
  resource_group_name = "${azurerm_resource_group.test.name}"
  location            = "${azurerm_resource_group.test.location}"
  prefix              = "${var.prefix}"
  subnet_id           = "${module.network.domain_controllers_subnet_id}"

  #active_directory_domain       = "${var.prefix}.local"
  active_directory_domain       = "${var.active_directory_domain}.local"
  active_directory_netbios_name = "${var.active_directory_domain}"
  admin_username                = "${var.admin_username}"
  admin_password                = "${var.admin_password}"
}

module "linux-client" {
  source              = "./modules/linux-client"
  resource_group_name = "${azurerm_resource_group.test.name}"
  location            = "${azurerm_resource_group.test.location}"
  prefix              = "${var.prefix}"
  subnet_id           = "${module.network.domain_clients_subnet_id}"

  #active_directory_domain   = "${var.prefix}.local"
  active_directory_domain   = "${var.active_directory_domain}"
  active_directory_username = "${var.admin_username}"
  active_directory_password = "${var.admin_password}"
  admin_username            = "${var.admin_username}"
  admin_password            = "${var.admin_password}"
  public_key                = "${var.public_key}"
  vault_download_url        = "${var.vault_download_url}"

  ad_ip = "${module.active-directory-domain.public_ip_address}"
}

output "ad_public_ip" {
  value = "${module.active-directory-domain.public_ip_address}"
}

data "template_file" "ad_script" {
  template = <<EOF

Run the following commands on the Windows Host via powershell. Restart the host when finished.

New-ADOrganizationalUnit -Name ‘Admin' -Path 'DC=$${active_directory_domain},DC=local';
New-ADOrganizationalUnit -Name ‘General' -Path ‘OU=Admin,DC=$${active_directory_domain},DC=local';
New-ADOrganizationalUnit -Name 'Users' -Path ‘OU=General,OU=Admin,DC=$${active_directory_domain},DC=local';
New-ADOrganizationalUnit -Name 'Group' -Path 'OU=General,OU=Admin,DC=$${active_directory_domain},DC=local';
New-ADGroup -Name 'engineering' -SamAccountName engineering -GroupScope Global -Path 'OU=Group,OU=General,OU=Admin,DC=$${active_directory_domain},DC=local';
New-ADUser -SamAccountName alex -Name 'alex' -UserPrincipalName alex@na.local -AccountPassword (ConvertTo-SecureString -AsPlainText 'Password1!' -Force) -Enabled $true -PasswordNeverExpires $true -Path 'OU=Users,OU=General,OU=Admin,DC=$${active_directory_domain},DC=local';
New-ADUser -SamAccountName chris  -Name 'chris'  -UserPrincipalName chris@na.local -AccountPassword (ConvertTo-SecureString -AsPlainText 'Password1!' -Force) -Enabled $true -PasswordNeverExpires $true -Path 'OU=Users,OU=General,OU=Admin,DC=$${active_directory_domain},DC=local';
Add-ADGroupMember -Identity engineering -Members  'CN=alex,OU=Users,OU=General,OU=Admin,DC=$${active_directory_domain},DC=local';
Add-ADGroupMember -Identity engineering -Members  'CN=chris,OU=Users,OU=General,OU=Admin,DC=$${active_directory_domain},DC=local';
Add-ADPrincipalGroupMembership -Identity 'CN=alex,OU=Users,OU=General,OU=Admin,DC=$${active_directory_domain},DC=local' -MemberOf Administrators;
Add-ADPrincipalGroupMembership -Identity 'CN=chris,OU=Users,OU=General,OU=Admin,DC=$${active_directory_domain},DC=local' -MemberOf Administrators;
Add-WindowsFeature Adcs-Cert-Authority -IncludeManagementTools;
Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -Force;

  EOF

  vars {
    active_directory_domain = "${var.active_directory_domain}"
  }
}

data "template_file" "vault_ad_secrets_script" {
  template = <<EOF

Run the following commands on the Vault instance after a CA cert has been added!

vault login password
vault secrets enable ad
vault write ad/config \
    binddn="cn=alex,ou=User,OU=General,OU=Admin,dc=$${active_directory_domain},dc=local" \
    bindpass='Password1!' \
    url="ldaps://$${ad_ip}" \
    userdn="ou=User,OU=General,OU=Admin,dc=$${active_directory_domain},dc=local" \
    insecure_tls=true
vault write ad/roles/my-application     service_account_name="chris@$${active_directory_domain}.local"
vault read ad/creds/my-application

  EOF

  vars {
    active_directory_domain = "${var.active_directory_domain}"
    ad_ip                   = "${module.active-directory-domain.public_ip_address}"
    ad_pass                 = "${var.admin_password}"
  }
}

output "Windows_script_info" {
  value = "${data.template_file.ad_script.rendered}"
}

output "vault_ad_secrets_info" {
  value = "${data.template_file.vault_ad_secrets_script.rendered}"
}

output "linux_ssh_info" {
  value = "${module.linux-client.ssh_info}"
}

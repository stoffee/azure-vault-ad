# Vault + AD demos
Do not use in production.

# 0. Terraform
Fill in terraform.tfvars (use the .tfvars.example) then
```
$ terraform apply
```
This can take up to 10 minutes.

# 1. Setup Windows
RDP into the windows instance (Use Azure GUI). Use the admin username and password from your terraform variables setup.

```
username: stoffee\na.local
password: Y0urPas$w0rd!1
```

Then run the windows script from your terraform output in a powershell terminal. it should look similar to below.

```bash
New-ADOrganizationalUnit -Name 'User' -Path 'DC=na,DC=local'; 
New-ADOrganizationalUnit -Name 'Group' -Path 'DC=na,DC=local'; 
New-ADGroup -Name 'engineering' -SamAccountName engineering -GroupScope Global -Path 'OU=Group,DC=na,DC=local';
New-ADUser -SamAccountName alex -Name 'alex' -UserPrincipalName alex@na.local -AccountPassword (ConvertTo-SecureString -AsPlainText 'Password1!' -Force) -Enabled $true -PasswordNeverExpires $true -Path 'OU=User,DC=na,DC=local'; 
New-ADUser -SamAccountName chris  -Name 'chris'  -UserPrincipalName chris@na.local -AccountPassword (ConvertTo-SecureString -AsPlainText 'Password1!' -Force) -Enabled $true -PasswordNeverExpires $true -Path 'OU=User,DC=na,DC=local'; 
Add-ADGroupMember -Identity engineering -Members  'CN=alex,OU=User,DC=na,DC=local'; 
Add-ADGroupMember -Identity engineering -Members  'CN=chris,OU=User,DC=na,DC=local'; 
Add-ADPrincipalGroupMembership -Identity 'CN=alex,OU=User,DC=na,DC=local' -MemberOf Administrators; 
Add-ADPrincipalGroupMembership -Identity 'CN=chris,OU=User,DC=na,DC=local' -MemberOf Administrators; 
Add-WindowsFeature Adcs-Cert-Authority -IncludeManagementTools; 
Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -Force;
```
IMPORTANT: Now restart the Windows box

# 2. Vault LDAP Auth 
SSH into the linux box (wait a minute or two for windows to start back up, instructions are in terraform output)

login to Vault via ldap. Use the 'alex' user we created in the last step.
```
$ vault login -method=ldap username=alex password=Password1!

Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                    Value
---                    -----
token                  713c1f94-eada-2a03-ddfd-4d8153ecec4d
token_accessor         1851ccc9-2deb-fe95-a281-0c2472c6ee96
token_duration         768h
token_renewable        true
token_policies         ["default" "vault-admin"]
identity_policies      []
policies               ["default" "vault-admin"]
```
use `vault read auth/ldap/config` to see the configuration. The script that configures vault is under `modules/linux-client/setup.tpl` in this repo.

# 3. Vault AD secrets engine
RDP back into the windows instance. We need to export a CA cert for use by Vault.

open a cmd prompt ("cmd" not powershell)
```
certutil  -ca.cert vault.cer
```

copy the vault.cer file over to the linux machine. and perform the following commands.

```
sudo mkdir /usr/share/ca-certificates/extra
sudo cp vault.cer /usr/share/ca-certificates/extra/vault.crt
sudo dpkg-reconfigure ca-certificates
#space bar to add CA at GUI screen
```

Now configure Vault to use the AD secret backend. (Your ad domain and IP address will be different, check the terraform output)

```
vault secrets enable ad

vault write ad/config \
    binddn="cn=alex,ou=User,dc=na,dc=local" \
    bindpass='Password1!' \
    url="ldaps://168.63.5.98:636" \
    userdn="ou=User,dc=na,dc=local" \
    insecure_tls=true


vault write ad/roles/my-application     service_account_name="chris@na.local"
```
Now rotate creds
```
akadmin@na-vault:~$ vault read ad/creds/my-application
Key                 Value
---                 -----
current_password    ?@09AZVZF4bz5fKQUinj+rawBD+nr6/dNPsWfijyPXLarDMByl9eA8FsCSQkCY8M
username            chris
```

Enjoy

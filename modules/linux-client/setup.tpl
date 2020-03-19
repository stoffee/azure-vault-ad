#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_API_ADDR=http://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true

sudo apt update
sudo apt-get install -y unzip 
sudo apt-get install -y jq 
sudo apt -y install ldap-utils

sudo cat << EOF > /etc/profile.d/vault.sh
export VAULT_ADDR="http://127.0.0.1:8200"
EOF

cd /tmp
sudo curl ${vault_download_url} -o /tmp/vault.zip

logger "Installing vault"
sudo unzip -o /tmp/vault.zip -d /usr/bin/

nohup /usr/bin/vault server -dev \
  -dev-root-token-id="password" \
  -dev-listen-address="0.0.0.0:8200" 0<&- &>/dev/null &

export VAULT_ADDR=http://127.0.0.1:8200

sleep 7
vault login password

echo '
path "*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}' | vault policy write vault-admin -
vault auth enable userpass
vault write auth/userpass/users/vault password=vault policies=vault-admin

vault auth enable ldap

vault write auth/ldap/config \
  url="ldap://${ad_ip}:389" \
  groupdn="ou=Group,ou=General,ou=Admin,dc=${active_directory_domain},dc=local" \
  starttls=false \
  binddn="cn=alex,ou=Users,OU=General,OU=Admin,dc=${active_directory_domain},dc=local" \
  bindpass='Password1!' \
  userattr="cn" \
  userdn="ou=Users,OU=General,OU=Admin,dc=${active_directory_domain},dc=local"

vault write auth/ldap/groups/engineering policies=vault-admin

#vault login -method=ldap username=alex password=Password1!
#vault login -method=ldap username=chris  password=Password1!




#!/bin/bash
# William Trelawny

### Pre-flight sanity checks ###
# Exit immediately if sudo not installed or user is not in sudoers group:
[[ -z $(which sudo) ]] && echo "'sudo' not installed! Exiting..." && exit 1
[[ ! $(groups) =~ "sudo" ]] && echo "Current user not in 'sudo' group! Exiting..." && exit 1



# Input Graylog minor version:
read -p "Graylog minor version: [4.3] " GL_MINOR_VERSION
GL_MINOR_VERSION_OPTS=("4.0" "4.1" "4.2" "4.3")

# Default value is 4.3 (latest as of this writing):
[[ -z $GL_MINOR_VERSION ]] && GL_MINOR_VERSION="4.3"

# If user supplied version is not in list of valid versions, die:
[[ ! "${GL_MINOR_VERSION_OPTS[@]}" =~ $GL_MINOR_VERSION ]] && echo -e "Graylog version not valid! Valid choices are:\n`printf "%s\n" "${GL_MINOR_VERSION_OPTS[@]}"`"



# Input MongoDB version:
read -p "MongoDB version: [4.4] " MONGODB_VERSION
MONGODB_VERSION_OPTS=("3.6" "4.0" "4.2" "4.4")

# Default value is 4.4 (latest supported by Graylog 4.3 as of this writing):
[[ -z $MONGODB_VERSION ]] && MONGODB_VERSION="4.4"

# If user supplied version is not in list of valid versions, die:
[[ ! "${MONGODB_VERSION_OPTS[@]}" =~ $MONGODB_VERSION ]] && echo -e "MongoDB version not valid! Valid choices are:\n`printf "%s\n" "${MONGODB_VERSION_OPTS[@]}"`"



# Install deps:
sudo apt update && sudo apt upgrade -y 
sudo apt install -y apt-transport-https openjdk-11-jre-headless uuid-runtime pwgen dirmngr gnupg wget

# Configure MongoDB repo:
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list

# Configure Graylog repo:
cd /tmp
wget https://packages.graylog2.org/repo/packages/graylog-4.3-repository_latest.deb
sudo dpkg -i graylog-4.3-repository_latest.deb

# Install MongoDB & Graylog:
sudo apt update && sudo apt install -y mongodb-org graylog-server graylog-enterprise-plugins graylog-integrations-plugins graylog-enterprise-integrations-plugins

# Fix mode/ownership of /etc/graylog/server/server.conf:
[[ ! $(groups) =~ "graylog" ]] && echo "[WARN] Current user not in 'graylog' group! Add them to this group so they do not need 'sudo' to edit Graylog server.conf."
sudo chown .graylog /etc/graylog/server
sudo chmod 0775 /etc/graylog/server
sudo chown .graylog /etc/graylog/server/server.conf
sudo chmod 0664 /etc/graylog/server/server.conf

# Generate password_secret & set admin password:
SECRET=$(pwgen -N 1 -s 96)
echo -n "Enter Password: " && PASS=$(head -1 </dev/stdin | tr -d '\n' | sha256sum | cut -d" " -f1)

# Set password_secret and root_password_sha2 in server.conf:
sudo sed -i "s/password_secret =/password_secret = $SECRET/" /etc/graylog/server/server.conf
sudo sed -i "s/root_password_sha2 =/root_password_sha2 = $PASS/" /etc/graylog/server/server.conf

# Configure systemd services:
sudo systemctl daemon-reload
sudo systemctl enable mongod.service graylog-server.service
sudo systemctl restart mongod.service graylog-server.service

# Lastly, output systemd service statuses of MongoDB and Graylog:
sudo systemctl status mongod graylog-server

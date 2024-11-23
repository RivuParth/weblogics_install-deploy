#!/bin/bash

# Update the system
sudo yum update -y

# Install required packages
sudo yum install -y unzip wget tar

# Download and install JDK
wget https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.tar.gz
tar -xzvf jdk-21_linux-x64_bin.tar.gz
sudo mkdir -p /usr/java
sudo mv jdk-21.0.5 /usr/java/

# Set JAVA_HOME and update PATH
echo 'export JAVA_HOME=/usr/java/jdk-21.0.5' >> ~/.bashrc
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
java -version

# Download WebLogic installer
wget https://test-weblogics.s3.us-east-1.amazonaws.com/fmw_14.1.1.0.0_wls_lite_generic.jar

# Create Oracle installation directory
sudo mkdir -p /opt/Oracle
sudo chown -R $USER:$USER /opt/Oracle

# Create response file for silent installation
cat <<EOL > response_file.rsp
[ENGINE]
Response File Version=1.0.0.0.0

[GENERIC]
ORACLE_INSTALL_LOG_DIR=/tmp/weblogic_install_logs
ORACLE_HOME=/u01/app/wls
INSTALL_TYPE=WebLogic Server
MYORACLESUPPORT_USERNAME=
MYORACLESUPPORT_PASSWORD=
DECLINE_SECURITY_UPDATES=true
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
PROXY_HOST=
PROXY_PORT=
EOL

# Create and enable swap file
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Ensure swap file persists after reboot
echo "/swapfile swap swap defaults 0 0" | sudo tee -a /etc/fstab

# Create Oracle groups and users
sudo groupadd oracle
sudo useradd -g oracle oracle
sudo usermod -aG oracle ec2-user

# Create oraInventory directory
sudo mkdir -p /opt/oracle/oraInventory
sudo chown -R oracle:oracle /opt/oracle/oraInventory

# Create oraInst.loc file
echo "inventory_loc=/u01/app/oraInventory" | sudo tee /etc/oraInst.loc
echo "inst_group=oinstall" | sudo tee -a /etc/oraInst.loc

# Create oinstall group and add ec2-user to it
sudo groupadd oinstall
sudo usermod -aG oinstall ec2-user

# Create necessary directories and set permissions
sudo mkdir -p /u01/app/oraInventory
sudo chown -R ec2-user:oinstall /u01/app/oraInventory
sudo mkdir -p /u01/app/wls
sudo chown -R ec2-user:oinstall /u01/app/wls

# Run WebLogic installer
source ~/.bashrc
java -jar fmw_14.1.1.0.0_wls_lite_generic.jar -silent -responseFile /home/ec2-user/response_file.rsp -invPtrLoc /etc/oraInst.loc


# Server Setup & Running 

export MW_HOME=/u01/app/wls
export WL_HOME=$MW_HOME/wlserver
export PATH=$PATH:$WL_HOME/server/bin

# Start WLST
$MW_HOME/oracle_common/common/bin/wlst.sh <<EOF

# Select the WebLogic Server template
selectTemplate('Basic WebLogic Server Domain')

# Load the template
loadTemplates()

# Set AdminServer configurations
cd('/Servers/AdminServer')
set('ListenAddress', '')  # Listen on all IPs
set('ListenPort', 7001)  # Default port

# Set WebLogic Admin username and password
cd('/Security/base_domain/User/weblogic')
cmo.setPassword('YourStrongPassword1!')  # Change to your desired password

# Write the domain to the specified directory
writeDomain('/u01/app/wls/user_projects/domains/base_domain')

# Close the template after writing the domain
closeTemplate()

# Exit WLST
exit()
EOF

# Go inside domain directory
cd /u01/app/wls/user_projects/domains/base_domain/bin
./startWebLogic.sh &

# Give the server some time to start
sleep 30

# Print the URL to access the WebLogic Console
echo "Access the WebLogic Console at: http://your-ip:7001/console"
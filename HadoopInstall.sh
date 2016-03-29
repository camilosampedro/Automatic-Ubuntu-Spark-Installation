#!/bin/bash

# Execute a command with message, checking if there are errors
# 	$1 Message
#	$2 Error message
#	$3 Command
function executeWithMessage {
	echo -ne "\n => $1"
	$3 || error "$?" "$2"
	echo -ne " ... :)\n"
}

# Show error message with exit code
#	$1 Exit code
#	$2 Error message
function error {
	echo "There was an error: $2 with exit code ($1)"
	exit
}

# Verifies if Java is installed, and if it's not installed, install it.
function isJavaInstalled {
	echo
	# Trying to execute java
	java -version
	
	# Getting the exit code of the execution.
  	EXITCODE="$?"
  	echo -ne "... "
  	
  	# If the code is different from zero, it is not installed
	if [ "$EXITCODE" != "0" ];
	then
		echo -ne "Java is not installed :(.\n"
		
		# Proceed to install java
		installJava
	else
		echo -ne "Java is installed :).\n"
	fi
}

# Java Ubuntu install
function installJava {
	
	# Clone my another gist with Java installation for Ubuntu
	executeWithMessage "Cloning java installation repository" "It was not possible to clone the repository" "git clone https://gist.github.com/7128552e33c6c4c6ab51.git"
	executeWithMessage "Getting into the folder" "It was not possible to get into the folder" "cd 7128552e33c6c4c6ab51"
	
	# Give it permissions and execute it
	executeWithMessage "Proceeding to install java" "Java installation failed" "chmod +x Install\ Java.sh && ./Install\ Java.sh"
	
}

# Installs Hadoop
function installHadoop {
	# Stand in /opt/ directory
	executeWithMessage "Getting into /opt/" "Cannot get into opt folder" "cd /opt/"
	
	# Hadoop install steps
	executeWithMessage "(1/4) Downloading Hadoop" "Could not download Hadoop tar gz" "sudo wget http://www-us.apache.org/dist/hadoop/common/hadoop-2.7.2/hadoop-2.7.2.tar.gz"
	executeWithMessage "(2/4) Decompressing Hadoop" "Could not decompress Hadoop tar gz" "sudo tar -xvzf hadoop-2.7.1.tar.gz"
	executeWithMessage "(3/4) Creating a symbolic link to hadoop" "Could not create a symbolic link to hadoop" "sudo ln -s hadoop-2.7.1 hadoop"
	executeWithMessage "(4/4) Adding permissions" "Failed to add execute and read permissions to hadoop folder recursively" "sudo chmod -R +rx hadoop"
}

# Create Hadoop user
function createUser {
	echo -ne "=> Creating Hadoop user..."
	sudo useradd -d /home/hadoop -m hadoop
	echo -ne "... :) \n"
	
	echo "Enter the new password for the Hadoop user. (It will have sudo's permissions)"
	sudo passwd hadoop
	usermod -a -G sudo hadoop
	usermod -s /bin/bash hadoop
	echo "Log with the new Hadoop password here. It's now adding the key and testing the hadoop user."
	sudo -u hadoop exit
	
	echo -ne "=> Adding environment variables to ~/.bashrc"
	{
		echo "export HADOOP_HOME=/usr/local/hadoop"
		echo "export PATH=\$PATH:\$HADOOP_HOME/bin"
		echo "export PATH=\$PATH:\$HADOOP_HOME/sbin"
		echo "export HADOOP_MAPRED_HOME=\${HADOOP_HOME}"
		echo "export HADOOP_COMMON_HOME=\${HADOOP_HOME}"
		echo "export HADOOP_HDFS_HOME=\${HADOOP_HOME}"
		echo "export YARN_HOME=\${HADOOP_HOME}"
	} >> /home/hadoop/.bashrc
	echo -ne "... :) \n"
}

# Adds network settings for Hadoop
function networkSettings {
	
	echo "=> Installing ssh..."
	sudo apt-get install -y ssh
	
	echo "=> Generating public key for hadoop user"
	sudo -u hadoop ssh-keygen -t rsa -f ~/.ssh/id_rsa
	
	echo "=> Adding localhost public key to authorized keys"
	cat ~/.ssh/id_rsa.pub | sudo -u hadoop tee -a ~/.ssh/authorized_keys > /dev/null
	
	echo "=> Updating ssh files permissions..."
	sudo -u hadoop sudo chmod go-w "$HOME" "$HOME/.ssh"
	sudo -u hadoop chmod 600 "$HOME"/.ssh/authorized_keys
	sudo -u hadoop chown "$(whoami)" "$HOME/.ssh/authorized_keys"
	
	echo "=> Disabling IPv6"
	{
		echo "net.ipv6.conf.all.disable_ipv6 = 1"
		echo "net.ipv6.conf.default.disable_ipv6 = 1"
		echo "net.ipv6.conf.lo.disable_ipv6 = 1"
	} >> /etc/sysctl.conf
}

# Edit Hadoop single host configuration
function editMainConfig {
	echo "Editing the config files under /opt/hadoop/etc/hadoop/"
	cd /opt/hadoop/etc/hadoop/ || exit
	echo -ne "[1/4] core-site.xml... "
	{
		echo "<?xml version=\"1.0\"?>"
		echo "<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>"
		echo "<configuration>"
		echo "  <property>"
		echo "    <name>fs.default.name</name>"
		  echo "    <value>hdfs://localhost:8020</value>"
		echo "    <description>Nombre del filesystem por defecto.</description>"
		echo "  </property>"
		echo "</configuration>"
	} > core-site.xml
	echo -ne " OK\n"
	
	echo -ne "[2/4] hdfs-site.xml... "
	{
		echo "<?xml version=\"1.0\"?>"
		echo "<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>"
		echo "<configuration>"
		echo "  <property>"
		echo "    <name>dfs.namenode.name.dir</name>"
		echo "    <value>file:/home/hadoop/workspace/dfs/name</value>"
		echo "    <description>Path del filesystem donde el namenode almacenará los metadatos.</description>"
		echo "  </property>"
		echo "  <property>"
		echo "    <name>dfs.datanode.data.dir</name>"
		echo "    <value>file:/home/hadoop/workspace/dfs/data</value>"
		echo "    <description>Path del filesystem donde el datanode almacenará los bloques.</description>"
		echo "  </property>"
		echo "  <property>"
		echo "    <name>dfs.replication</name>"
		echo "    <value>1</value>"
		echo "    <description>Factor de replicación. Lo ponemos a 1 porque sólo tenemos 1 máquina.</description>"
		echo "  </property>"
		echo "</configuration>"
	} > hdfs-site.xml
	echo -ne "OK\n"
	
	echo -ne "[3/4] Creating hdfs directories /home/hadoop/workspace/dfs/name... "
	sudo -u hadoop mkdir -p /home/hadoop/workspace/dfs/name
	sudo -u hadoop mkdir -p /home/hadoop/workspace/dfs/data
	echo -ne "OK \n"
	
	echo -ne "[4/4] Copying the mapred-site.xml template file... "
	sudo cp mapred-site.xml.template mapred-site.xml
	echo -ne "OK \n"
	
	{
		echo "<configuration>"
		echo "<property>"
		echo "  <name>yarn.nodemanager.aux-services</name>"
		echo "  <value>mapreduce_shuffle</value>"
		echo "</property>"
		echo "<property>"
		echo "  <name>yarn.nodemanager.aux-services.mapreduce_shuffle.class</name>"
		echo "  <value>org.apache.hadoop.mapred.ShuffleHandler</value>"
		echo "</property>"
		echo "</configuration>"
	} >> yarn-site.xml
}

# Start point for the program
function main {
	# Verify if Java is installed
	isJavaInstalled
	
	# Install Hadoop
	installHadoop
	
	sudo su 
	
	# User creation
	createUser
	
	# Network settings
	networkSettings
	
	# Config files
	editMainConfig
	
	# Format hdfs
	sudo hdfs namenode -format
	
	echo "Installation complete, after you log in with hadoop user, run Hadoop using:"
	echo "start-dfs.sh & star-yarn.sh"
	echo ""
}

read -p "WARNING! This script is under development and can cause problems. (IT IS STILL NOT WORKING! and should ONLY be used for testing!) Are you sure you want to continue? " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
    main
fi



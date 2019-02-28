#!/bin/bash
# Kalum Umesh

# Unset env_setup
unset https_proxy
unset http_proxy
unset no_proxy

if [ ! -f /etc/profile.d/devopsenv.sh ];
then
	echo "ERROR : env not found /etc/profile.d/devopsenv.sh , Refer readme.txt " 
	exit 1
fi

. /etc/profile.d/devopsenv.sh

if [ $DEV_DEBUG == "true" ];
then
	set -x
fi

cd $DEV_OPS_HOME/scripts/aws

CURRENT_FOLDER=${PWD##*/}
DATE=$(date '+%Y-%m-%d')
CONFIG_FILE=$DEV_OPS_HOME/config/$CURRENT_FOLDER.properties

MAIL_HOST=`cat $CONFIG_FILE|grep "^MAIL_HOST"|cut -d"=" -f2`
HTTP_PROXY=`cat $CONFIG_FILE|grep "^HTTP_PROXY"|cut -d"=" -f2`
HTTPS_PROXY=`cat $CONFIG_FILE|grep "^HTTPS_PROXY"|cut -d"=" -f2`
NO_PROXY=`cat $CONFIG_FILE|grep "^NO_PROXY"|cut -d"=" -f2`

check_package(){
	which $1 >> /dev/null 2>&1
	if [ $? -eq 1 ];
	then
		echo "$1 not found"
		exit 1
	fi	
}

check_proxy(){

	# check proxy

	if [ `cat $CONFIG_FILE|grep "^PROXY_ENABLE"|cut -d"=" -f2` == "true" ];
		then
			export https_proxy=$HTTPS_PROXY
			export http_proxy=$HTTP_PROXY
			export no_proxy=$NO_PROXY
			
			if [ `grep -r proxy /etc/apt/|wc -l` -eq 0 ];
			then
				echo "Proxy not found for apt-get"
				if [ -f /etc/apt/apt.conf ];
				then
					echo "add below to the /etc/apt/apt.conf"
					echo "Acquire::http::proxy $HTTP_PROXY;"
					echo "Acquire::https::proxy $HTTPS_PROXY;" 
					exit 1
				else
					echo "Creat a new file /etc/apt/apt.conf with below lines"
					echo "Acquire::http::proxy $HTTP_PROXY;"
					echo "Acquire::https::proxy $HTTPS_PROXY;"
					exit 1
				fi
			fi
		fi

}

env_check(){

	package_install="$DEV_OPS_HOME/config/package.install"
	while IFS= read -r package
	do
	  package_install_command=`echo $package|cut -d"=" -f2`
	  sudo $package_install_command
	  package_name=`echo $package|cut -d"=" -f1`
	  check_package $package_name
	done < "$package_install"

	
	# check aws cli
	which aws >> /dev/null 2>&1
	if [ $? -eq 1 ];
	then
		echo "AWS cli not found"
		echo "Installing aws cli ...."
		check_proxy
		sudo apt-get update
		curl -O https://bootstrap.pypa.io/get-pip.py
		python get-pip.py
		pip install awscli
		
	fi

}

env_setup_checkup(){

	env_check
	if [ ! -d $DEV_OPS_HOME/logs ];
	then
		mkdir $DEV_OPS_HOME/logs
	fi

	export ALERT_EMAIL_LIST=`cat $CONFIG_FILE|grep "^ALERT_EMAIL_LIST"|cut -d"=" -f2`

}

env_setup_checkup
#!/bin/bash
# Kalum Umesh

MAIL_HOST=`cat $CONFIG_FILE|grep "^MAIL_HOST"|cut -d"=" -f2`
HTTP_PROXY=`cat $CONFIG_FILE|grep "^HTTP_PROXY"|cut -d"=" -f2`
HTTPS_PROXY=`cat $CONFIG_FILE|grep "^HTTPS_PROXY"|cut -d"=" -f2`
NO_PROXY=`cat $CONFIG_FILE|grep "^NO_PROXY"|cut -d"=" -f2`

check_package(){
	which $1 >> /dev/null 2>&1
	if [ $? -eq 1 ];
	then
		echo "$1 not found"
		echo "Run environment/package setup script as root"
		echo "$DEV_OPS_HOME/scripts/common/environment_setup.sh"
		exit 1
	fi	
}

env_check(){
# check aws cli
which aws >> /dev/null 2>&1
if [ $? -eq 1 ];
then
	echo "AWS cli not found"
	exit 1	
fi

# check proxy

if [ `cat $CONFIG_FILE|grep "^PROXY_ENABLE"|cut -d"=" -f2` == "true" ];
	then
		export https_proxy=$HTTPS_PROXY
		export http_proxy=$HTTP_PROXY
		export no_proxy=$NO_PROXY
		
		if [ `grep -r -i proxy /etc/apt/|wc -l` -eq 0 ];
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

	package_install="$DEV_OPS_HOME/config/package.install"
	while IFS= read -r package
	do
	  package_name=`echo $package|cut -d"=" -f1`
	  check_package $package_name
	done < "$package_install"
	
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
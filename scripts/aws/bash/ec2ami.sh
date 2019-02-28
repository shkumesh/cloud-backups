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
EXTRA_TAGS="Key=Group,Value=service"
DATE=$(date '+%Y-%m-%d')
CONFIG_FILE=$DEV_OPS_HOME/config/$CURRENT_FOLDER.properties

# Setting common routings
. $DEV_OPS_HOME/scripts/common/env_setup.sh
. $DEV_OPS_HOME/scripts/common/logger.sh
. $DEV_OPS_HOME/scripts/common/emailservice.sh

env_setup_checkup

unset https_proxy
unset http_proxy
unset no_proxy

SNAPSHOTS_PERIOD=`cat $CONFIG_FILE|grep "^SNAPSHOTS_PERIOD"|cut -d"=" -f2`
LOG_FILE=$DEV_OPS_HOME/logs/`cat $CONFIG_FILE|grep "^LOG_FILE"|cut -d"=" -f2`_$DATE
AWS_BIN=`which aws` >> $LOG_FILE 2>&1
#REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed -e 's/.$//')  >> $LOG_FILE 2>&1
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
HOSTNAME=`hostname`
AWS="$AWS_BIN"

if [ `cat $CONFIG_FILE|grep "^PROXY_ENABLE"|cut -d"=" -f2` == "true" ];
then
	export https_proxy=$HTTPS_PROXY
	export http_proxy=$HTTP_PROXY
	export no_proxy=$NO_PROXY
fi

# create a AMI
INFO " Creating AMI for INSTANCE_ID $INSTANCE_ID"
AMI=$($AWS_BIN ec2 create-image --instance-id $INSTANCE_ID --name "$HOSTNAME-$DATE" --no-reboot)
RET=$?
if [ $RET != 0 ]; then
    ERROR "create-ami failed:$RET"
	send_mail "$ALERT_EMAIL_LIST" "$HOSTNAME : ami backup" "create-ami failed:$RET" "FAIL :$AMI"
else
	AMI_ID=$(echo $AMI | jq -r '.ImageId')
	$AWS ec2 create-tags --resources "$AMI_ID" --tags "Key=Name,Value=$HOSTNAME" "Key=Hostname,Value=autobackup" $EXTRA_TAGS 
	INFO "$AMI_ID \($HOSTNAME $DATE\) created."
	send_mail "$ALERT_EMAIL_LIST" "$HOSTNAME : AMI backup" "$AMI_ID $HOSTNAME $DATE created." "SUCCESS"
fi
INFO "Deleting old amis and snaps."
# getting ids :
if [ $SNAPSHOTS_PERIOD -ge 1 ]; then
	DELETE_DATE=`date '+%Y-%m-%d' --date="-$SNAPSHOTS_PERIOD day"`
	OLD_AMI_IDS=`aws ec2  describe-images --filters "Name=tag:Name,Values=$HOSTNAME" --query "Images[?CreationDate <= '$DELETE_DATE']"|jq -r ' .[].ImageId'`
	OLD_SNAP_IDS=`aws ec2  describe-images --filters "Name=tag:Name,Values=$HOSTNAME" --query "Images[?CreationDate <= '$DELETE_DATE']"|jq -r ' .[].BlockDeviceMappings[].Ebs.SnapshotId'`
	for d_ami in $OLD_AMI_IDS
	do 
		INFO "Deleting old ami: $d_ami"
		$AWS ec2 deregister-image --image-id $d_ami
		RET=$?
		if [ $RET != 0 ]; then
			ERROR "delete-ami $d_ami failed:$RET"
			send_mail "$ALERT_EMAIL_LIST" "$HOSTNAME : ami backup" "delete-ami $d_ami failed:$RET" "FAIL"
		fi
	done
	
	for d_ami_snap in $OLD_SNAP_IDS
	do 
		INFO "Deleting old snap: $d_ami_snap"
		$AWS ec2 delete-snapshot --snapshot-id  $d_ami_snap
		RET=$?
		if [ $RET != 0 ]; then
			ERROR "delete-snap $d_ami_snap failed:$RET"
			send_mail "$ALERT_EMAIL_LIST" "$HOSTNAME : snap backup" "delete-snap $d_ami_snap failed:$RET" "FAIL"
		fi
	done
else
	INFO "No need to delete the snanps"
fi

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

# Setting common routings
. $DEV_OPS_HOME/scripts/common/env_setup.sh
. $DEV_OPS_HOME/scripts/common/logger.sh
. $DEV_OPS_HOME/scripts/common/emailservice.sh

env_setup_checkup

unset https_proxy
unset http_proxy
unset no_proxy

SNAPSHOTS_PERIOD=`cat $CONFIG_FILE|grep "^SNAPSHOTS_PERIOD"|cut -d"=" -f2`
EXTRA_TAGS="Key=Group,Value=service"
LOG_FILE=$DEV_OPS_HOME/logs/`cat $CONFIG_FILE|grep "^LOG_FILE"|cut -d"=" -f2`_$DATE
AWS_BIN=`which aws` >> $LOG_FILE 2>&1
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed -e 's/.$//')  >> $LOG_FILE 2>&1
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
HOSTNAME=$(hostname -s)

AWS="$AWS_BIN --region $REGION"

if [ `cat $CONFIG_FILE|grep "^PROXY_ENABLE"|cut -d"=" -f2` == "true" ];
then
	export https_proxy=$HTTPS_PROXY
	export http_proxy=$HTTP_PROXY
	export no_proxy=$NO_PROXY
fi

# Target EBS volume id
VOL_IDS=$($AWS ec2 describe-instances --instance-ids "$INSTANCE_ID" | jq -r '.Reservations[].Instances[].BlockDeviceMappings[].Ebs.VolumeId') >> $LOG_FILE 2>&1
if [ -z "$VOL_IDS" ]; then
    ERROR "no EBS ID."
	send_mail "$ALERT_EMAIL_LIST" "$HOSTNAME : snapshot backup" "no EBS ID." "FAIL"
    exit 1
fi
for VOL_ID in $VOL_IDS
do
# create a snapshot
INFO " Creating snapshot for VOL_ID $VOL_ID"
SNAPSHOT=$($AWS ec2 create-snapshot --volume-id "$VOL_ID" --description "Created by ec2snapshot ($INSTANCE_ID) from $VOL_ID") >> $LOG_FILE 2>&1
RET=$?
if [ $RET != 0 ]; then
    INFO "$SNAPSHOT"
    ERROR "create-snapshot failed:$RET"
	send_mail "$ALERT_EMAIL_LIST" "$HOSTNAME : snapshot backup" "create-snapshot failed:$RET" "FAIL"
fi
SNAPSHOT_ID=$(echo $SNAPSHOT | jq -r '.SnapshotId')
$AWS ec2 create-tags --resources "$SNAPSHOT_ID" --tags "Key=Name,Value=$HOSTNAME $DATE" "Key=Hostname,Value=autobackup" $EXTRA_TAGS 
INFO "$SNAPSHOT_ID \($HOSTNAME $DATE\) created."
send_mail "$ALERT_EMAIL_LIST" "$HOSTNAME : snapshot backup" "$SNAPSHOT_ID $HOSTNAME $DATE created." "SUCCESS"

# delete old snapshots
if [ $SNAPSHOTS_PERIOD -ge 1 ]; then
	INFO "Deleting old snapshots."
	SNAPSHOTS=$($AWS ec2 describe-snapshots --owner-ids self --filters "Name=volume-id,Values=$VOL_ID" "Name=tag:Hostname,Values=autobackup" --query "Snapshots[*].[SnapshotId,StartTime]") >> $LOG_FILE 2>&1
	echo $SNAPSHOTS > SNAPSHOTS.$$ 
	sed -i 's/\[ \[ //g' SNAPSHOTS.$$ 
	sed -i 's/"//g' SNAPSHOTS.$$
	sed -i 's/ \], \[ /\n/g' SNAPSHOTS.$$ 
	sed -i 's/ \] \]//g' SNAPSHOTS.$$ 
	cat SNAPSHOTS.$$ >> $LOG_FILE 2>&1
	SNAP_COUNT=`wc -l SNAPSHOTS.$$|awk '{print $1}'` >> $LOG_FILE 2>&1
	INFO "currnet snap count : $SNAP_COUNT"
	if [ $SNAP_COUNT -ge $SNAPSHOTS_PERIOD ];
	then
		SNAP_EXP_COUNT=`expr $SNAP_COUNT - $SNAPSHOTS_PERIOD`
		INFO "Snap count for exparation : $SNAP_EXP_COUNT"
		tail -$SNAP_EXP_COUNT SNAPSHOTS.$$ > SNAPSHOTS_DELETE.$$ 
		cat SNAPSHOTS_DELETE.$$ >> $LOG_FILE 2>&1
		while IFS= read line
		do
			snapshotid=`echo "$line"|cut -d"," -f1` >> $LOG_FILE 2>&1
			INFO "deleting $snapshotid"
			$AWS ec2 delete-snapshot --snapshot-id "$snapshotid" >> $LOG_FILE 2>&1
			RET=$?
			if [ $RET != 0 ]; then
					ERROR "delete-snapshot $snapshotid failed:$RET"
					send_mail "$ALERT_EMAIL_LIST" "$HOSTNAME : snapshot backup" "delete-snapshot $snapshotid failed:$RET" "FAIL"
			fi
		done <SNAPSHOTS_DELETE.$$
	else
			INFO "No need to delete the snanps $SNAPSHOTS"
	fi
fi
done
rm -rf SNAPSHOTS*
exit 0

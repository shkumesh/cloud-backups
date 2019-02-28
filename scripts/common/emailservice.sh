#!/bin/bash
# Kalum Umesh

MAIL_HOST=`cat $CONFIG_FILE|grep "^MAIL_HOST"|cut -d"=" -f2`
MAIL_PORT=`cat $CONFIG_FILE|grep "^MAIL_PORT"|cut -d"=" -f2`

send_mail(){

TO_ADDRESS="$1"
SUBJECT="$2"
MESSAGE="$3"
STATUS="$4"

unset https_proxy
unset http_proxy
unset no_proxy

}
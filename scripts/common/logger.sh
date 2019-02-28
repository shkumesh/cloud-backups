#!/bin/bash
# Kalum Umesh

INFO(){
echo `date`" INFO $1" >> $LOG_FILE 2>&1
}

DEBUG(){
echo `date`" DEBUG $1" >> $LOG_FILE 2>&1
}

ERROR(){
echo `date`" ERROR $1" >> $LOG_FILE 2>&1
}
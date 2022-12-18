#!/bin/bash

## Script to stop Wialon services as well as check if stopped and trying
## to stop again if failed for some reason

# Separate log files for standart -`LOGFILE` log and errors - `ERRFILE`

WORKDIR=/home/wialon/wl_storage_backup
LOGDIR=/var/log/wialon-poweroff-cmd
LOGFILE=wl_power.log
ERRFILE=wl_power.err
LOG=$LOGDIR/$LOGFILE
ERR=$LOGDIR/$ERRFILE
LOG_PERMISSIONS=644

# Check if log dir and files are presend, else - creating them

function log_check {
  if [ ! -d "$LOGDIR" ]; then
      mkdir -p $LOGDIR && chmod $LOG_PERMISSIONS $LOGDIR
  fi
  if [ ! -f "$LOG" ]; then
      touch $LOG && chmod $LOG_PERMISSIONS $LOG
  fi
  if [ ! -f "$ERR" ]; then
     touch $ERR $$ chmod $LOG_PERMISSIONS $ERR
  fi
}

# Stop Wialon services

function wl_stop {
  systemctl stop wlocal >> $LOG 2>> $ERR
  bash $WORKDIR/adf_script stop >> $LOG 2>> $ERR
}

# -----------------------------------------------------------------------------
# Entrypoint
# ----------------------------------------------------------------------------

log_check
wl_stop
# Give system some time

sleep 5

# Check if services have stopped

<< 'Description'
Infinite `while` loop with `if` statement inside that checks if
"node" or "adf_service" processes are running, if so - trying
to stop again and wait some time. Else - break `while` loop
Description

while :
do
  if pgrep -x "node" > /dev/null || pgrep -x "adf_service" > /dev/null; then
     echo "SERVICE STOP FAILED. Wialon is still running!!!" >> $ERR
     wl_stop
     sleep 5
  else
    echo "All wialon services have stopped successfully" >> $LOG
    break
  fi
done

# Shutdown the system
/sbin/shutdown -h +0 >> $LOG 2>> $ERR

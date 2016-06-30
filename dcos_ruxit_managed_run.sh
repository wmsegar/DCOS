#!/bin/bash

#######
# This script takes the TENANT and TOKEN from the arguments and installs Ruxit
# It unregisters RuxitAgent from systemd and runs the watchdog manually
# Don't modify this file!
#######

if [ -z "$BASH_VERSION" ]
then
  exec bash "$0" "$@"
fi

ADDING_TOOL=
ADDING_TOOL_PARAMS=
ADDING_TOOL_SUFFIX_PARAMS=
PATH_TO_SCRIPT=
INITDFILE=ruxitagent
PA_RECOVERY_SCRIPT=ruxitagentproc
INIT_FOLDER=

function quit() {
  exit 0
}

function removeFromAutostart() {
    echo "Executing: $ADDING_TOOL $ADDING_TOOL_PARAMS "$PATH_TO_SCRIPT""$1" $ADDING_TOOL_SUFFIX_PARAMS "
    TEMP_RESULT=$($ADDING_TOOL $ADDING_TOOL_PARAMS "$PATH_TO_SCRIPT""$1" $ADDING_TOOL_SUFFIX_PARAMS 2>&1 )
    STATUS=$?

    if [ "${STATUS}" -gt 0 ] ; then
        echo "Error during removing from autostart: "
        echo "$TEMP_RESULT"
    fi
}

function removeSystemvAutostart() {
        if [ -d /etc/init.d ] ; then
                       INIT_FOLDER=/etc/init.d
               elif [ -d /sbin/init.d ] ; then
                       INIT_FOLDER=/sbin/init.d
               elif [ -d /etc/rc.d ] ; then
                       INIT_FOLDER=/etc/rc.d
               else
                       INIT_FOLDER="/opt/ruxit/agent/initscripts"
       fi


        #Order of checking is important
        #For example oracle installer creates sometimes broken chkconfig script on ubuntu

        #Ubuntu
        if [ -x /usr/bin/update-rc.d ] ; then
                ADDING_TOOL="/usr/bin/update-rc.d"
                ADDING_TOOL_PARAMS="-f"
                ADDING_TOOL_SUFFIX_PARAMS="remove"
        elif [ -x /usr/sbin/update-rc.d ] ; then
                ADDING_TOOL="/usr/sbin/update-rc.d"
                ADDING_TOOL_PARAMS="-f"
                ADDING_TOOL_SUFFIX_PARAMS="remove"
        #RedHat
        elif [ -x /sbin/chkconfig ] ; then
                ADDING_TOOL="/sbin/chkconfig"
                ADDING_TOOL_PARAMS="--del"
        ##Suse
        elif [ -x /usr/lib/lsb/install_initd ] ; then
                ADDING_TOOL="/usr/lib/lsb/install_initd"
                PATH_TO_SCRIPT="${INIT_FOLDER}/"
        #AIX
        elif [ -d /etc/rc.d/rc2.d ] && [ -w /etc/rc.d/rc2.d ] && [ -x /etc/rc.d/rc2.d ] && [ -w /etc/inittab ] ; then
                rm -f ${INIT_FOLDER}/${INITDFILE} /etc/rc.d/rc2.d/S99${INITDFILE}
                (echo "g/ruxitagent/d"; echo 'wq') | ex -s /etc/inittab
        #SOLARIS
        elif [ -d /etc/rc2.d ] && [ -w /etc/rc2.d ] && [ -x /etc/rc2.d ] && [ -w /etc/inittab ] ; then
                rm -f /etc/rc2.d/S99${INITDFILE}
                (echo "g/ruxitagent/d"; echo 'wq') | ex -s /etc/inittab
        #HPUX
        elif [ -d /sbin/rc2.d ] && [ -w /sbin/rc2.d ] && [ -x /sbin/rc2.d ] && [ -w /etc/inittab ] ; then
                rm -f /sbin/rc2.d/S999${INITDFILE}
                (echo "g/ruxitagent/d"; echo 'wq') | ex -s /etc/inittab
        fi

        #removing from autostart using detected tool
        if [ ! -z "$ADDING_TOOL" ] ; then
                removeFromAutostart "${INITDFILE}"
                removeFromAutostart "$PA_RECOVERY_SCRIPT"
        fi
}

RUXIT_ENVIRONMENT=$1
RUXIT_TOKEN=$2

[ "x$RUXIT_ENVIRONMENT" == "x" ] && echo "Need to set RUXIT_ENVIRONMENT" && quit;
[ "x$RUXIT_TOKEN" == "x" ] && echo "Need to set RUXIT_TOKEN" && quit;

echo "Downloading Ruxit..."

if which curl >/dev/null;
then
curl_output=$(curl -o /tmp/ruxit-Agent-Linux.sh https://$RUXIT_ENVIRONMENT/installer/agent/unix/latest/$RUXIT_TOKEN)
[ $? -ne 0 ] && echo "curl failed! - $curl_output" && quit;
elif which wget >/dev/null;
then
wget_output=$(wget --no-check-certificate -O /tmp/ruxit-Agent-Linux.sh https://$RUXIT_ENVIRONMENT/installer/agent/unix/latest/$RUXIT_TOKEN)
[ $? -ne 0 ] && echo "wget failed! - $wget_output" && quit;
else
  echo "No wget or curl found to download Ruxit Agent"
  quit
fi

echo "Trying to install Ruxit..."
chmod 755 /tmp/ruxit-Agent-Linux.sh
chown root:root /tmp/ruxit-Agent-Linux.sh
/tmp/ruxit-Agent-Linux.sh
echo "Installation of Ruxit Agent completed."

systemctl stop ruxitagent.service 2>/dev/null
systemctl disable ruxitagent.service 2>/dev/null

removeSystemvAutostart

cd /opt/ruxit/agent/bin
trap "(/opt/ruxit/agent/uninstall.sh & ) &" SIGTERM
/opt/ruxit/agent/lib64/ruxitwatchdog -vm=/opt/ruxit/agent/lib64/ruxitagent -logdir /opt/ruxit/log -ini ../conf/ruxitwatchdog.ini

quit


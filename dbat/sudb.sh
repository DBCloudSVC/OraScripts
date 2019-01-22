#!/bin/sh
#Version: 0.91
#This script could be run by root user (to switch any instance) or to one instance of the current owner
#Change history
#Managed by Git from 26/10/2017
export ORATAB=/etc/oratab
ECHO=echo
OS=`uname -s`
case $OS in
AIX) ECHO=echo
	export OLDPATH=/usr/bin:/etc:/usr/sbin:/usr/ucb:$HOME/bin:/usr/bin/X11:/sbin:.
	export CUSER='eval echo $LOGIN'
	;;
Linux) ECHO="echo -e"
	export OLDPATH=/usr/kerberos/bin:/usr/local/bin:/bin:/usr/bin:$HOME/bin
	export CUSER='eval echo $LOGNAME'
	;;
esac
TSHELL="eval grep \"^\$ORACLE_OWNER:\" /etc/passwd|awk -F: '{print \$7}'"
OSID=`$ECHO $ORACLE_SID`
unset ORACLE_SID
TMPFILE=sudb_$$_$RANDOM
if [ $($CUSER) == root ]; then
	case $OS in
	AIX)
		export OLDPATH=/usr/bin:/etc:/usr/sbin:/usr/ucb:/usr/bin/X11:/sbin:$HOME/bin
		;;
	Linux)
		export OLDPATH=/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:$HOME/bin
		;;
	esac
else
	id|grep -E -w '(oinstall|dba)' >/dev/null
	if [ $? -ne 0 ]; then
		$ECHO "The current user can not access databases!"
		exit
	fi
fi

echo ${OD_LIBPATH}|grep 'OD_LIBPATH' >/dev/null
if [ $? -ne 0 ]; then
	if [ "x$LIBPATH" == "x" ]; then
		OD_LIBPATH=OD_LIBPATH 
	else
		OD_LIBPATH=$LIBPATH:OD_LIBPATH
	fi
fi
echo ${OD_LD_LIBRARY_PATH}|grep 'OD_LD_LIBRARY_PATH' >/dev/null
if [ $? -ne 0 ]; then
	if [ "x${LD_LIBRARY_PATH}" == "x" ]; then
		OD_LD_LIBRARY_PATH=OD_LD_LIBRARY_PATH
	else
		OD_LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:OD_LD_LIBRARY_PATH
	fi
fi
export OD_LIBPATH OD_LD_LIBRARY_PATH

if [ $# -ne 1 ]; then
	$ECHO Need one and just one parameter as the ORACLE_SID!
	exit
fi

#For the special SID, try to get the ORACLE_HOME from the running process first
#Change some below lines to compatible with original sudb syntax.
SSID=`echo $1|sed 's/^ORACLE_SID=//'`
ps -eo args|grep -v grep|grep -w "ora_smon_$SSID" >/dev/null 2>&1
if [ $? -eq 0 ]; then
	ORACLE_SID=$SSID
else
	grep -v '^#' $ORATAB|grep -v '^\ *$'|awk -F: '{print $1}'|grep -w "$SSID" >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		ORACLE_SID=$SSID
	fi
fi
if [ "x$ORACLE_SID" != "x" ]; then
	export ORACLE_SID
	grep "^${ORACLE_SID}:" $ORATAB|awk -F: '{print $2}' >/tmp/$TMPFILE
	for PID in `ps -eo pid,args|grep -v grep|grep -w "ora_smon_${ORACLE_SID}"|awk '{print $1}'`; do
		if [ $($CUSER) != "root" ]; then
			ps -eo pid,user|grep -w "$($CUSER)" >/dev/null 2>&1
			if [ $? -ne 0 ]; then
				echo "Please note there is a instance $ORACLE_SID running in another user!"
				continue
			fi
		fi
		ls -l /proc/$PID/cwd 2>/dev/null|sed 's/^.*-> //'|grep -v "/proc/$PID"|sed 's/\/dbs\/\{0,1\}//' >>/tmp/$TMPFILE
	done
	CHOME=`sort -u /tmp/$TMPFILE|wc -l`
	if [ $CHOME -eq 1 ]; then
		export ORACLE_HOME=`cat /tmp/$TMPFILE|sort -u`
		export LD_LIBRARY_PATH=${ORACLE_HOME}/lib:$OD_LD_LIBRARY_PATH
		export LIBPATH=${ORACLE_HOME}/lib:$OD_LIBPATH
		export ORACLE_BASE=`echo $ORACLE_HOME|sed 's/\/product.*//'`
		rm /tmp/$TMPFILE
	else
		i=1
		for HNAME in `sort -u /tmp/$TMPFILE`; do
			$ECHO [${i}]: $HNAME|tee -a /tmp/${TMPFILE}2
			let i=i+1
		done
		$ECHO "Which ORACLE_HOME do you want to switch to?: \c"; read CNUM
		export ORACLE_HOME=`grep "^\[${CNUM}\]:" /tmp/${TMPFILE}2|sed 's/]: /]:/'|awk -F: '{print $2}'`
		export LD_LIBRARY_PATH=${ORACLE_HOME}/lib:$OD_LD_LIBRARY_PATH
		export LIBPATH=${ORACLE_HOME}/lib:$OD_LIBPATH
		export ORACLE_BASE=`echo $ORACLE_HOME|sed 's/\/product.*//'`
		rm /tmp/${TMPFILE} /tmp/${TMPFILE}2
	fi
	ORACLE_OWNER=`ls -l $ORACLE_HOME/bin/oracle|awk '{print $3}'`
	export ORA_NLS33=$ORACLE_HOME/ocommon/nls/admin/data
	export PATH=$ORACLE_HOME/OPatch:$ORACLE_HOME/bin:$OLDPATH
	export PS1='$ORACLE_SID'@`hostname -s`'[$PWD]$ '
	if [ $($CUSER) == root ]; then
		$ECHO Oracle environment will be switched to $ORACLE_SID \($ORACLE_HOME\)
		echo $($TSHELL)|grep 'ksh' >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			PROFILE="eval grep \"^\$ORACLE_OWNER:\" /etc/passwd|awk -F: '{print \$6\"/.profile\"}'"
			RCFILE=`grep -v '^#' $($PROFILE)|grep -E '(^ENV=|\ ENV=)'|sed 's/;.*$//'|sed 's/\(^.*ENV=\)\([!;]*\)/\2/'`
			if [ "X$RCFILE" == "X" ]; then
				RCFILE=`grep "^$ORACLE_OWNER:" /etc/passwd|awk -F: '{print $6"/.kshrc"}'`
			fi
			export ENV=$RCFILE
		fi
		su $ORACLE_OWNER
	elif [ $($CUSER) == $ORACLE_OWNER ]; then
		$ECHO "Oracle environment has been switched to $ORACLE_SID ($ORACLE_HOME)"
	else
		$ECHO "The instance $ORACLE_SID is owned by another user, please exit to root user then to it."
	fi
else
	$ECHO "Can not find the named instance, nothing changed!"
	export ORACLE_SID=`$ECHO $OSID`
fi

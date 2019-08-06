#!/bin/sh
#This script is used to prepare the OS for the Oracle installation.
#The current support platform: Linux
#Platforms will be supported in the future: Solaris, AIX, HP-UX

#Check the running user
id|grep 'uid=0(' > /dev/null
if [ $? -ne 0 ]; then $ECHO Please run this script as root user\!; exit; fi

#Check the OS platform
OS=`uname -s`
case $OS in
AIX)
	ECHO=echo
	ORATAB=/etc/oratab
	ORALOC=/etc/oraInst.loc
	;;
Linux)
	ECHO="echo -e"
	ORATAB=/etc/oratab
	ORALOC=/etc/oraInst.loc
	;;
esac

#The Yum source must be configurated to install the required packages
#Below is a sample file.
#cat /etc/yum.repos.d/source_disc.repo
#[source_disc]
#name=Red Hat Enterprise Linux $releasever - $basearch -Source_Disc
#baseurl=file:///mnt/iso
#enabled=1
#gpgcheck=0

#Install the needed packages
case $OS in
Linux)
	#For RedHat-Like systems
	if [ -f /etc/redhat-release ]; then
		if uname -a|grep 'x86_64' >/dev/null
		then
			grep -E '(release 6|release 7|release 8)' /etc/redhat-release >/dev/null
			if [ $? -eq 0 ]; then
				bit32=i686
        grep 'release 8' /etc/redhat-release >/dev/null && DNFOPT='--setopt=strict=0'
			else
				bit32=i386
			fi
			yum -y $DNFOPT install tar bzip2 gzip install bc nscd perl-TermReadKey unzip zip parted openssh-clients bind-utils wget nfs-utils smartmontools\
				binutils.x86_64 compat-db.x86_64 compat-libcap1.x86_64 compat-libstdc++-296.${bit32} compat-libstdc++-33.x86_64 compat-libstdc++-33.${bit32} \
				elfutils-libelf-devel.x86_64 gcc.x86_64 gcc-c++.x86_64 glibc.x86_64 glibc.${bit32} glibc-devel.x86_64 glibc-devel.${bit32} ksh.x86_64 libaio.x86_64 net-tools.x86_64\
				libaio-devel.x86_64 libaio.${bit32} libaio-devel.${bit32} libgcc.${bit32} libgcc.x86_64 libgnome.x86_64 libgnomeui.x86_64 libstdc++.x86_64 libstdc++-devel.x86_64 \
				libstdc++.${bit32} libstdc++-devel.${bit32} libXp.${bit32} libXt.${bit32} libXtst.x86_64 libXtst.${bit32} make.x86_64 pdksh.x86_64 sysstat.x86_64 unixODBC.x86_64 \
				unixODBC-devel.x86_64 unixODBC.${bit32} unixODBC-devel.${bit32} xorg-x11-utils.x86_64 libnsl.x86_64
		else
			yum -y install bc nscd perl-TermReadKey unzip zip parted openssh-clients bind-utils wget nfs-utils smartmontools binutils compat-db compat-libcap1 compat-libstdc++-296 \
				compat-libstdc++-33 elfutils-libelf-devel gcc gcc-c++ glibc glibc-devel ksh libaio net-tools libaio-devel libgcc libgnome libgnomeui libstdc++ libstdc++-devel \
				libXp libXt libXtst make pdksh sysstat unixODBC unixODBC-devel xorg-x11-utils
		fi
	elif [ -f /etc/SuSE-release ]; then
		if uname -a|grep 'x86_64' >/dev/null; then
			zypper -n in -l --no-recommends binutils gcc gcc48 glibc glibc-32bit glibc-devel glibc-devel-32bit \
				mksh libaio1 libaio-devel libcap1 libstdc++48-devel libstdc++48-devel-32bit libstdc++6 libstdc++6-32bit \
				libstdc++-devel libstdc++-devel-32bit libgcc_s1 libgcc_s1-32bit make sysstat xorg-x11-driver-video \
				xorg-x11-server xorg-x11-essentials xorg-x11-Xvnc xorg-x11-fonts-core xorg-x11 xorg-x11-server-extra xorg-x11-libs xorg-x11-fonts
		fi
	fi
	;;
esac

#Fix for RHEL8
grep 'release 8' /etc/redhat-release >/dev/null && ( ln -s /lib64/libnsl.so.1 /lib64/libnsl.so 2>/dev/null; \
  $ECHO
  $ECHO "Please remember to downgrade your libaio* packages to RHEL7 level if you want to install Oracle 11g!"; \
  read -p "Enter to continue..." )

#Check the Memory and SWAP size
ETSWAP=N
case $OS in
Linux)
	TMEM=`grep MemTotal /proc/meminfo|awk '{printf "%d", $2/1024}'`
	TSWAP=`grep SwapTotal /proc/meminfo|awk '{printf "%d", $2/1024}'`
	;;
esac
if [ $TMEM -le 2048 ]; then
	if [ $TSWAP -lt `echo $TMEM*1.5/1|bc` ]; then
		ETSWAP=Y
		RSWAP=`echo $TMEM*1.5/1|bc`
	fi
elif [ $TMEM -gt 2048 -a $TMEM -le 16384 ]; then
	if [ $TSWAP -lt $TMEM ]; then
		ETSWAP=Y
		RSWAP=$TMEM
	fi
else
	if [ $TSWAP -lt 16384 ]; then
		ETSWAP=Y
		RSWAP=16384
	fi
	$ECHO "The total physical memory is large than 16G, so the HugePage feature is recommended."
	$ECHO "Do you want to enable it? (Y/y/Enter to accept, other to continue): \c"; read  A_HPAGE
	[ x"$A_HPAGE" == "x" ] || [ x"$A_HPAGE" == "xY" ] || [ x$A_HPAGE == "xy" ] && { 
	$ECHO "Please input the expected total SGA size (include the ASM instance) in MB:\c"; read A_SGASIZE
	if [ $A_SGASIZE -le 8192 ]; then
		$ECHO "Normal memory page should be OK for such total SGA size, so will not configure HugePage."
	else
		HPG_SZ=`grep Hugepagesize /proc/meminfo | awk '{print $2}'`
		if [ x"$HPG_SZ" == "x" ]; then
			$ECHO "The HugePage may not be supported in this system."
		else
			NUM_HPAGE=`$ECHO "$A_SGASIZE*1024/$HPG_SZ+10"|bc`
			$ECHO "Will configure $NUM_HPAGE huge memory pages."
			$ECHO "Please note Automatic Memory Management (AMM) should be disabled."
		fi
	fi }
	#According to Best Practice (Doc ID 811306.1), will set the vm.min_free_kbytes=512M
	$ECHO "Will set the kernel parameter vm.min_free_kbytes=512M"
	[ `sysctl vm.min_free_kbytes|awk '{printf "%d",$3/1024}'` -le 512 ] && MIN_FM=524288
fi

#If the swap size is not enough, will try to extend it automatically
if [ "$ETSWAP" == "Y" ]; then
	case $OS in
	Linux)
		SWAPDEV=`grep 'swap' /etc/fstab|head -1|cut -d\  -f1`
		swapoff $SWAPDEV
		lvresize -L ${RSWAP}M $SWAPDEV >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "The swap has been resized to ${RSWAP}M!"
			mkswap $SWAPDEV >/dev/null 2>&1
			swapon $SWAPDEV >/dev/null 2>&1
		else
			echo "Failed to extend the swap size automatically, please resize it manually."
			echo "The expected swap size is ${RSWAP}M!"
			swapon $SWAPDEV
			$ECHO "Do you want to continue to other steps or extend the swap now?(c/C to continue, others to quit) \c"; read A_CONFEXTSWAP
			if [ x$A_CONFEXTSWAP != "xc" -a x$A_CONFEXTSWAP != "xC" ]; then
				exit
			fi
		fi
		;;
	esac
fi

INGI=NO
if [ x"$1" != x -a -f "$1" ]; then
	ORAIDFILE="$1"
	$ECHO
	$ECHO Please make sure below group IDs and user IDs are not used currently.
	$ECHO Group IDs:
	grep 'GRP' $ORAIDFILE|cut -d: -f3|sort -u
	$ECHO User IDs:
	grep 'ID' $ORAIDFILE|cut -d: -f3|sort -u
	$ECHO
	$ECHO "OK for you? (Enter or input Y/y to confirm, any other to reject): \c"; read A_CONFMID
	if [ "x$A_CONFMID" != "x" -a "$A_CONFMID" != "Y" -a "$A_CONFMID" != "y" ]; then
		$ECHO "Please fix this issue first then run this script again."
		exit
	fi
	IDMAP=$(awk -F: '{print $1,$2,$3}' $ORAIDFILE)
	while read IDTYPE IDVALUE GUID
	do
		case $IDTYPE in
		OIGRP|DBAGRP|OPERGRP)
			eval $(echo $IDTYPE)=$IDVALUE
			groupadd -g $GUID $IDVALUE 2>/dev/null
			;;
		ASMADMGRP|ASMDBAGRP|ASMOPERGRP)
			INGI=YES
			eval $(echo $IDTYPE)=$IDVALUE
			groupadd -g $GUID $IDVALUE 2>/dev/null
			;;
		DBAID)
			export DBAID=$IDVALUE
			if [ $INGI == "YES" ]; then
				useradd -m -u $GUID -g $OIGRP -G $DBAGRP,$OPERGRP,$ASMDBAGRP $IDVALUE
			else
				useradd -m -u $GUID -g $OIGRP -G $DBAGRP,$OPERGRP $IDVALUE
			fi
			;;
		GIID)
			export GIID=$IDVALUE
			useradd -m -u $GUID -g $OIGRP -G $DBAGRP,$ASMADMGRP,$ASMOPERGRP,$ASMDBAGRP $IDVALUE
			;;
		*)
			;;
		esac
	done<<-EOF
	$IDMAP
	EOF
	$ECHO
	$ECHO "The following groups and users have been created:"
	$ECHO "Oracle Inventory group:      $OIGRP"
	$ECHO "Oracle DBA group:            $DBAGRP"
	$ECHO "Oracle DB Operatering group: $OPERGRP"
	$ECHO "Oracle DB owner:             $DBAID"
	if [ "$INGI" == "YES" ]; then
		$ECHO "ASM Administration group:    $ASMADMGRP"
		$ECHO "ASM Operatering group:       $ASMOPERGRP"
		$ECHO "ASM DBA group:               $ASMDBAGRP"
		$ECHO "Grid Infrastructure owner:   $GIID"
	fi 
	$ECHO
else
	CONFMID=NO
	while [ $CONFMID != "YES" ]; do
		#Check user and groups
		$ECHO
		$ECHO "Do you want to create seperate groups for Oracle software installation? (Y|N): \c"; read SPGRP
		if [ "$SPGRP" == "Y" -o "$SPGRP" == "y" ]; then
			if [ -f $ORALOC ]; then
				OIGRP=`grep inst_group $ORALOC|awk -F= '{print $2}'|sed 's/ //g'`
			else
				OIGRP=oinstall
			fi
			$ECHO "The Oracle software installation group is ${OIGRP}, OK for you? (Enter to accept, or input a new group name): \c"; read A_OIGRP
			if [ "x$A_OIGRP" != "x" ]; then
				OIGRP=$A_OIGRP
			fi
		fi
		$ECHO "The default Oracle database administration group is dba, OK for you? (Enter to accept, or input a new group name): \c"; read A_DBAGRP
		if [ "x$A_DBAGRP" != "x" ]; then
			DBAGRP=$A_DBAGRP
		else
			DBAGRP=dba
		fi
		$ECHO "Do you want to make the $DBAGRP as the database operation group? (Enter to accept, or input a new group name): \c"; read A_OPERGRP
		if [ "x$A_OPERGRP" != "x" ]; then
			OPERGRP=$A_OPERGRP
		else
			OPERGRP=$DBAGRP
		fi
		$ECHO "The default Oracle database user is oracle, OK for you? (Enter to accept, or input a new user name): \c"; read A_DBAID
		if [ "x$A_DBAID" != "x" ]; then
			DBAID=$A_DBAID
		else
			DBAID=oracle
		fi

		$ECHO "Do you want to install GI (Y|N)? \c"; read INGI
		if [ "$INGI" == "Y" -o "$INGI" == "y" ]; then
			$ECHO "Do you want to create seperated groups for GI installation? (Y|N)? \c"; read SPGI
			$ECHO "The default ASM administration group is asmadmin, OK for you? (Enter to accept, or input a new group name): \c"; read A_ASMADMGRP
			if [ "x$A_ASMADMGRP" != "x" ]; then
				ASMADMGRP=$A_ASMADMGRP
			else
				ASMADMGRP=asmadmin
			fi
			if [ "$SPGI" == "Y" -o "$SPGI" == "y" ]; then
				$ECHO "The default ASM DBA group is asmdba, OK for you? (Enter to accept, or input a new group name): \c"; read A_ASMDBAGRP
				if [ "x$A_ASMDBAGRP" != "x" ]; then
					ASMDBAGRP=$A_ASMDBAGRP
				else
					ASMDBAGRP=asmdba
				fi
				$ECHO "Do you want to make the $ASMADMGRP as the ASM operation group? (Enter to accept, or input a new group name): \c"; read A_ASMOPERGRP
				if [ "x$A_ASMOPERGRP" != "x" ]; then
					ASMOPERGRP=$A_ASMOPERGRP
				else
					ASMOPERGRP=$ASMADMGRP
				fi
			else
				ASMDBAGRP=$ASMADMGRP
				ASMOPERGRP=$ASMADMGRP
			fi
			$ECHO "The default GI user is grid, OK for you? (Enter to accept, or input a new user name): \c"; read A_GIID
			if [ "x$A_GIID" != "x" ]; then
				GIID=$A_GIID
			else
				GIID=grid
			fi
		fi
		$ECHO
		$ECHO "The following groups and users will be created:"
		$ECHO "Oracle Inventory group:      $OIGRP"
		$ECHO "Oracle DBA group:            $DBAGRP"
		$ECHO "Oracle DB Operatering group: $OPERGRP"
		$ECHO "Oracle DB owner:             $DBAID"
		if [ "$INGI" == "Y" -o "$INGI" == "y" ]; then
			$ECHO "ASM Administration group:    $ASMADMGRP"
			$ECHO "ASM Operatering group:       $ASMOPERGRP"
			$ECHO "ASM DBA group:               $ASMDBAGRP"
			$ECHO "Grid Infrastructure owner:   $GIID"
		fi 
		$ECHO
		$ECHO "OK for you? (Enter or input Y/y to confirm): \c"; read A_CONFMID
		if [ "x$A_CONFMID" == "x" -o "$A_CONFMID" == "Y" -o "$A_CONFMID" == "y" ]; then
			CONFMID=YES
		fi
	done

	case $OS in
	Linux)
		if [ "x$OIGRP" != "x" ]; then
			groupadd $OIGRP 2>/dev/null
		else
			OIGRP=$DBAGRP
		fi
		groupadd $DBAGRP 2>/dev/null
		groupadd $OPERGRP 2>/dev/null
		id $DBAID >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			PREGRPS=`id $DBAID|awk '{print $3}'|sed -r 's/(groups=|[0-9][0-9]*\(|\))//g'`
			usermod -g $OIGRP -G $DBAGRP,$OPERGRP,$PREGRPS $DBAID
		else
			useradd -m -g $OIGRP -G $DBAGRP,$OPERGRP $DBAID
		fi
		if [ "$INGI" == "Y" -o "$INGI" == "y" ]; then
			groupadd $ASMADMGRP 2>/dev/null
			groupadd $ASMDBAGRP 2>/dev/null
			groupadd $ASMOPERGRP 2>/dev/null
			PREGRPS=`id $DBAID|awk '{print $3}'|sed -r 's/(groups=|[0-9][0-9]*\(|\))//g'`
			usermod -g $OIGRP -G $PREGRPS,$ASMDBAGRP $DBAID
			id $GIID >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				PREGRPS=`id $GIID|awk '{print $3}'|sed -r 's/(groups=|[0-9][0-9]*\(|\))//g'`
				usermod -g $OIGRP -G $ASMADMGRP,$ASMDBAGRP,$ASMOPERGRP,$DBAGRP,$PREGRPS $GIID
			else
				useradd -m -g $OIGRP -G $ASMADMGRP,$ASMDBAGRP,$ASMOPERGRP,$DBAGRP $GIID
			fi
		fi
		$ECHO OIGRP:$OIGRP:`cat /etc/group|grep -w "^$OIGRP"|awk -F: '{print $3}'` > /tmp/oraidmap
		$ECHO DBAGRP:$DBAGRP:`cat /etc/group|grep -w "^$DBAGRP"|awk -F: '{print $3}'` >> /tmp/oraidmap
		$ECHO OPERGRP:$OPERGRP:`cat /etc/group|grep -w "^$OPERGRP"|awk -F: '{print $3}'` >> /tmp/oraidmap
		if [ "$INGI" == "Y" -o "$INGI" == "y" ]; then
			$ECHO ASMADMGRP:$ASMADMGRP:`cat /etc/group|grep -w "^$ASMADMGRP"|awk -F: '{print $3}'` >> /tmp/oraidmap
			$ECHO ASMDBAGRP:$ASMDBAGRP:`cat /etc/group|grep -w "^$ASMDBAGRP"|awk -F: '{print $3}'` >> /tmp/oraidmap
			$ECHO ASMOPERGRP:$ASMOPERGRP:`cat /etc/group|grep -w "^$ASMOPERGRP"|awk -F: '{print $3}'` >> /tmp/oraidmap
		fi
		$ECHO DBAID:$DBAID:`cat /etc/passwd|grep -w "^$DBAID"|awk -F: '{print $3}'` >>/tmp/oraidmap
		if [ "$INGI" == "Y" -o "$INGI" == "y" ]; then
			$ECHO GIID:$GIID:`cat /etc/passwd|grep -w "^$GIID"|awk -F: '{print $3}'` >>/tmp/oraidmap
		fi
		$ECHO You can use /tmp/oraidmap file as reference file to create oracle/grid users on other servers with the same group/user IDs.
		$ECHO File content as below:
		cat /tmp/oraidmap
		$ECHO
		;;
	esac
fi

#Check the kernel parameters
case $OS in
Linux)
	#Check SELinux settings
	if [ -h /etc/sysconfig/selinux ]; then
		SETARGET=`ls -l /etc/sysconfig/selinux|awk -F'> ' '{print $2}'`
		if echo $SETARGET|grep '^/' >/dev/null
		then
			SEFILE=$SETARGET
		else
			SEFILE=/etc/sysconfig/$SETARGET
		fi
	else
		SEFILE=/etc/sysconfig/selinux
	fi
	if [ -f $SEFILE ]; then
		sed -i.orap-bak -e 's/^SELINUX=enforcing$/SELINUX=permissive/' $SEFILE
	fi
	#Check NOZEROCONF configuration
	if [ -f /etc/sysconfig/network ]; then
		grep -i 'NOZEROCONF=yes' /etc/sysconfig/network >/dev/null
		if [ $? -ne 0 ]; then
			echo "NOZEROCONF=yes">>/etc/sysconfig/network
		fi
	fi
	#Check configuration of options in /etc/resolv.conf
	if [ -d /etc/dhcp ]; then
		DHCOPTIONS="options timeout:1 attempts:2"
		if ! grep -Fxq "$DHCOPTIONS" /etc/resolv.conf
		then
			$ECHO $DHCOPTIONS >>/etc/resolv.conf
			cat >> /etc/dhcp/dhclient-exit-hooks <<-EOF
#!/bin/bash

OPTIONS="$DHCOPTIONS"

if grep -Fxq "\$OPTIONS" /etc/resolv.conf
then
    exit
else
    echo "; generated by /etc/dhcp/dhclient-exit-hooks" >> /etc/resolv.conf
    echo \${OPTIONS} >> /etc/resolv.conf
fi
			EOF
			chmod 755 /etc/dhcp/dhclient-exit-hooks
		fi
	fi
	#chk_kernel_paras()
	#{
	#}
	#sysctl -a|grep -E -w '(fs.aio-max-nr|fs.file-max|kernel.shmall|kernel.shmmax|kernel.shmmni|kernel.sem|net.ipv4.ip_local_port_range|net.core.rmem_default|net.core.rmem_max|net.core.wmem_default|net.core.wmem_max|net.ipv4.tcp_wmem|net.ipv4.tcp_rmem)'
	if ! grep '#Added for Oracle installation' /etc/sysctl.conf >/dev/null && [ ! -f /etc/sysctl.d/oracle.conf ]; then
		SHMALL=`awk '/MemTotal/{printf "%.0f\n",$2/4*0.8}' /proc/meminfo`
		[ $SHMALL -lt 2097152 ] && SHMALL=2097152
		SHMMAX=`awk '/MemTotal/{printf "%.0f\n",$2*0.8*1024}' /proc/meminfo`
		$ECHO "#Added for Oracle installation" > /tmp/sysctl.conf.tmp
		cat >> /tmp/sysctl.conf.tmp <<-EOF
fs.aio-max-nr = 4194304
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
kernel.shmmni = 4096
kernel.shmall = $SHMALL
kernel.shmmax = $SHMMAX
kernel.panic_on_oops = 1
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 2097152
net.ipv4.tcp_wmem = 262144 262144 6291456
net.ipv4.tcp_rmem = 4194304 4194304 4194304
		EOF
		[ -n "$NUM_HPAGE" ] && echo "vm.nr_hugepages = $NUM_HPAGE" >> /tmp/sysctl.conf.tmp
		[ -n "$MIN_FM" ] && echo "vm.min_free_kbytes = $MIN_FM" >> /tmp/sysctl.conf.tmp
		#Disable Address Space Layout Randomization (ASLR) (Note 1345364.1)
		sysctl kernel.randomize_va_space >/dev/null 2>&1  && echo "kernel.randomize_va_space = 0" >> /tmp/sysctl.conf.tmp
		sysctl kernel.exec-shield >/dev/null 2>&1  && echo "kernel.exec-shield = 0" >> /tmp/sysctl.conf.tmp
		if [ -d /etc/sysctl.d ]; then
			mv /tmp/sysctl.conf.tmp /etc/sysctl.d/oracle.conf
		else
			$ECHO >> /etc/sysctl.conf
			cat /tmp/sysctl.conf.tmp >> /etc/sysctl.conf
			rm /tmp/sysctl.conf.tmp
			$ECHO >> /etc/sysctl.conf
		fi
		sysctl --system > /dev/null
	fi
	;;
esac

#Check the limit values
case $OS in
Linux)
	grep '#Added for Oracle installation' /etc/security/limits.conf >/dev/null
	if [ $? -ne 0 ]; then
		$ECHO >> /etc/security/limits.conf
		$ECHO "#Added for Oracle installation" >> /etc/security/limits.conf
		for uname in `$ECHO $DBAID $GIID`; do
			cat >> /etc/security/limits.conf <<-EOF
$uname  soft    nproc    2047
$uname  hard    nproc    16384
$uname  soft    nofile   4096
$uname  hard    nofile   65536
$uname  soft    stack    10240
$uname  hard    stack    32768
$uname  soft    memlock  3145728
$uname  hard    memlock  536870912
			EOF
		done
		$ECHO >> /etc/security/limits.conf
	fi
	;;
esac

#Fix bug in RHEL7.2
[ -f /etc/systemd/logind.conf ] && ! grep '^RemoveIPC=no' /etc/systemd/logind.conf>/dev/null 2>&1 && echo "RemoveIPC=no" >> /etc/systemd/logind.conf

#Try to disable transparent hugepages
if [ -f /sys/kernel/mm/transparent_hugepage/enabled ] && ! grep '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled > /dev/null; then
	$ECHO "Will disable Transparent Hugepages(THP) to avoid some bugs"
	#Update grub config file
	[ -f /etc/default/grub ] && ! grep '^GRUB_CMDLINE_LINUX="[^"]* transparent_hugepage=never' /etc/default/grub && { \
	sed -i.orap-bak -e '/^GRUB_CMDLINE_LINUX="/s/\(^GRUB_CMDLINE_LINUX="[^"]*\)/\1 transparent_hugepage=never/' /etc/default/grub
	find /boot -name "grub.cfg" -exec cp -p {} {}.orap-bak \;
	grub2-mkconfig -o `find /boot -name "grub.cfg"`
	}
	[ -f /boot/grub/grub.conf ] && ! grep "kernel.*$(uname -r).* transparent_hugepage=never" /boot/grub/grub.conf && \
		sed -i.orap-bak -e "/kernel.*$(uname -r)/s/\(kernel.*\)/\1 transparent_hugepage=never/" /boot/grub/grub.conf

	#Update kernel tune profile
	tuned-adm active 2>&1|grep 'Current active profile' >/dev/null && { \
		TUNEPRF=`tuned-adm active 2>&1|grep 'Current active profile'|awk '{print $4}'`
		[ -d /etc/tuned ] && { \
			mkdir /etc/tuned/${TUNEPRF}-nothp
			cat >/etc/tuned/${TUNEPRF}-nothp/tuned.conf <<-EOF
[main]
include=${TUNEPRF}

[vm]
transparent_hugepages=never
			EOF
			chmod +x /etc/tuned/${TUNEPRF}-nothp/tuned.conf
			tuned-adm profile ${TUNEPRF}-nothp
		}
		[ -d /etc/tune-profiles ] && grep -l 'set_transparent_hugepages always' /etc/tune-profiles/${TUNEPRF}/* >/dev/null && { \
			cp -rp /etc/tune-profiles/${TUNEPRF} /etc/tune-profiles/${TUNEPRF}-nothp
			sed -i.orap-bak -e 's,set_transparent_hugepages always,set_transparent_hugepages never,' `grep -l 'set_transparent_hugepages always' /etc/tune-profiles/${TUNEPRF}-nothp/*`
			tuned-adm profile ${TUNEPRF}-nothp
		}
	}
fi

#Configure the shell profiles
case $OS in
Linux)
	grep '#Added for Oracle installation' /etc/profile >/dev/null
	if [ $? -ne 0 ]; then
		$ECHO >> /etc/profile
		$ECHO "#Added for Oracle installation" >> /etc/profile
		cat >> /etc/profile <<-EOF
if [ x\$USER = x"$DBAID" -o x\$USER = x"$GIID" ]; then
    echo \$SHELL|grep -E '(ksh|pdksh)' >/dev/null
    if [ \$? -eq 0 ]; then
        ulimit -p 16384
        ulimit -n 65536
        ulimit -l 536870912
        ulimit -s 32768
    else
        ulimit -u 16384 -n 65536 -l 536870912 -s 32768
    fi
    umask 022
fi
		EOF
		$ECHO >> /etc/profile
	fi
	;;
esac

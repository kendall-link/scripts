#!/bin/bash

## SYSTEM AUDIT
# This script is intended to make a single text file for each system that is easily parseable to show 
# the status of packages that are installed, held, pending purge, pending upgrade etc to compare and
# make sure the systems are in good package health

# It will write the output to /mnt/scratch/tmp/system-package-audit/results/

export DATE_SECONDS=`date +%s`
export DATE=`date +%Y%m%d`
export DATE_TIME=`date +%Y%m%d_%H%M%S`
export HOST=`hostname`
export WHOAMI=`whoami`

if [ "$WHOAMI" != "root" ]; then
        echo "$0 - you must run me as root"
        exit 1
fi

export OUTPUT_DIRECTORY="/mnt/scratch/tmp/system-package-audit/results/${DATE}"
[ ! -d "${OUTPUT_DIRECTORY}" ] && mkdir -pv $OUTPUT_DIRECTORY
[ ! -d "${OUTPUT_DIRECTORY}" ] && echo "Cannot create or access ${OUTPUT_DIRECTORY}, unable to continue"
[ ! -d "${OUTPUT_DIRECTORY}" ] && exit 1

export OUTPUT_FILE="${OUTPUT_DIRECTORY}/${HOST}_package_audit.txt"

[ -f "$OUTPUT_FILE" ] && echo "$OUTPUT_FILE exists already, attempting to delete it"
[ -f "$OUTPUT_FILE" ] && rm -f $OUTPUT_FILE
[ -f "$OUTPUT_FILE" ] && echo "$OUTPUT_FILE still exists, maybe permissions lacking or something, aborting"
[ -f "$OUTPUT_FILE" ] && exit 1

echo "Will write output to ${OUTPUT_FILE}"

# This is something I saw Alex O do years ago with MySQL backups, neat idea never seen
# it before. Redirects all commands and outputs to the file in question rather than
# redirecting each one individually
exec 6>&1
exec >> $OUTPUT_FILE

export K_VERSION=`uname -r`
export K_VERSION_SHORT=`echo $K_VERSION | sed s'/-generic//'g`
[ -f "/opt/mydir/conf/chefenv" ] && export CHEF_ENV=`cat /opt/mydir/conf/chefenv`
[ -f "/opt/mydir/conf/chefenv" ] || export CHEF_ENV="UNKNOWN"

[ -f "/opt/mydir/conf/chefrole" ] && export CHEF_ROLE=`cat /opt/mydir/conf/chefrole`
[ -f "/opt/mydir/conf/chefrole" ] || export CHEF_ROLE="UNKNOWN"

[ -f "/etc/os-release" ] && export OS_RELEASE=`grep PRETTY_NAME /etc/os-release | sed s'/.*Ubuntu //'g | sed s'/ .*//'g`
[ -f "/etc/os-release" ] || export OS_RELEASE="UNKNOWN"

echo "DATE_ONLY:${DATE}"
echo "DATE_TIME:${DATE_TIME}"
echo "HOSTNAME:${HOST}"
echo "KERNEL:${K_VERSION}"
echo "OS_RELEASE:${OS_RELEASE}"
echo "CHEF_ENV:${CHEF_ENV}"

if [ -f "/var/run/chef.lastrun" ]; then
	export CHEF_LASTRUN_SECONDS=`ls -l --time-style="+%s" /var/run/chef.lastrun | awk '{print $6}'`
	export CHEF_AGE=`echo ${DATE_SECONDS}-${CHEF_LASTRUN_SECONDS} | bc`
	echo "CHEF_LASTRUN_SECONDS_AGO:${CHEF_AGE}"
else
	echo "CHEF_LASTRUN_SECONDS_AGO:UNKNOWN"
fi

export APT_CACHE_SIZE=`du -sh /var/cache/apt/archives| awk '{print $1}'`
echo "APT_CACHE_SIZE: ${APT_CACHE_SIZE}"
export PENDING_UPGRADE_SHORT=`apt-get -s upgrade | tail -n 1`
echo "PENDING_UPGRADE_STATUS:${PENDING_UPGRADE_SHORT}"

apt-get -s upgrade | grep -v "\(^Reading\|^Building\|^Calculating\)" | while read line; do
	echo "APT_PENDING_UPGRADE_LONG_STATUS: $line";
	done

apt-get -s autoremove | grep -v "\(^Reading\|^Building\|^Calculating\)" | while read line; do
	echo "APT_AUTOREMOVE_LONG_STATUS: $line";
	done

apt-cache policy | grep http | sed s'/.*http/http/'g | sort | uniq | while read line; do
	echo "APT_CONFIGURED_REPO_SERVER:${line}";
	done

export INSTALLED_PACKAGES=`dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}:${Architecture}=${Version}\n' '*' | grep "\(^ii\|^hi\)" | wc -l`
export OTHER_INSTALLED_PACKAGES=`dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}:${Architecture}=${Version}\n' '*' | grep -v "\(^ii\|^un\|^hi\)" | wc -l`
echo "TOTAL_FULLY_INSTALLED_PACKAGES:${INSTALLED_PACKAGES}"
echo "TOTAL_PARTIALLY_INSTALLED_PACKAGES:${OTHER_INSTALLED_PACKAGES}"

# The first three columns of the output show the desired action,
#              the package status, and errors, in that order.
#
#  Desired action:       Package status:
#   u = Unknown	        n = Not-installed
#   i = Install		c = Config-files #   h = Hold		H = Half-installed
#   r = Remove		U = Unpacked
#   p = Purge		F = Half-configured
#			W = Triggers-awaiting
#			t = Triggers-pending
#			i = Installed

dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}:${Architecture}=${Version}\n' 'linux-*' | sed s'/amd64:amd64/amd64/'g | grep "^i" | grep "\(linux-image\|linux-headers\|linux-modules\)" | grep -v "\(linux-image-generic\|linux-headers-generic\)" | sed s'/^[a-z][a-z]  //'g | grep -v $K_VERSION_SHORT  |
while read line; do
	export PACKAGE=`echo $line | sed s'/\=.*//'g`;
	export VERSION=`echo $line | sed s'/.*=//'g`;
	export REPO=`apt-cache policy $PACKAGE | grep -A1 "$VERSION " | grep http | sed s'/.*http/http/'g | awk '{print $1"#"$2}' | head -n 1`;
	echo $REPO | grep -iq http 2>/dev/null || export REPO="UNKNOWN_REPO"
	echo -e "OLD_KERNEL:${PACKAGE}=${VERSION} ${REPO}";
	done

dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}:${Architecture}=${Version}\n' '*' | sed s'/amd64:amd64/amd64/'g | grep "\(^rc\|^p\)" | sed s'/^[a-z][a-z]  //'g | 
while read line; do
	export PACKAGE=`echo $line | sed s'/\=.*//'g`;
	export VERSION=`echo $line | sed s'/.*=//'g`;
	export REPO=`apt-cache policy $PACKAGE | grep -A1 "$VERSION " | grep http | sed s'/.*http/http/'g | awk '{print $1"#"$2}' | head -n 1`;
	echo $REPO | grep -iq http || export REPO="UNKNOWN_REPO"
	echo -e "PENDING_PURGE:${PACKAGE}=${VERSION} ${REPO}";
	done
	
dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}:${Architecture}=${Version}\n' '*' | sed s'/amd64:amd64/amd64/'g | grep "^h" | sed s'/^h[a-z]  //'g |
while read line; do
	export PACKAGE=`echo $line | sed s'/\=.*//'g`;
	export VERSION=`echo $line | sed s'/.*=//'g`;
	export REPO=`apt-cache policy $PACKAGE | grep -A1 "$VERSION " | grep http | sed s'/.*http/http/'g | awk '{print $1"#"$2}' |head -n 1`;
	echo $REPO | grep -iq http || export REPO="UNKNOWN_REPO"
	echo -e "HELD:${PACKAGE}=${VERSION} ${REPO}";
	done

dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}:${Architecture}=${Version}\n' '*' | sed s'/amd64:amd64/amd64/'g | grep ^ii | sed s'/^ii  //'g | 
while read line; do
	export PACKAGE=`echo $line | sed s'/\=.*//'g`;
	export VERSION=`echo $line | sed s'/.*=//'g`;
	export REPO=`apt-cache policy $PACKAGE | grep -A1 "$VERSION " | grep http | sed s'/.*http/http/'g | awk '{print $1"#"$2}' | head -n 1`;
	echo $REPO | grep -iq http || export REPO="UNKNOWN_REPO"
	echo -e "INSTALLED:${PACKAGE}=${VERSION} ${REPO}";
	done

# Oracle Java checks
export ORACLE_JAVA_INSTALLED="0"
dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}:${Architecture}=${Version}\n' 'oracle-j2*' 2>/dev/null |  grep -q ^ii && export ORACLE_JAVA_INSTALLED="1"

if [ "$ORACLE_JAVA_INSTALLED" -eq "1" ]; then
update-alternatives --query java | grep "\(^Name\|Link\|^Best\|^Value\)" | while read line; do
	echo "JAVA_ALTERNATIVES_CONFIGURATION: $line"
done
export ORACLE_JAVA_BIN=`update-alternatives --query java | grep oracle | grep bin | awk '{print $NF}'`
update-alternatives --query java | grep oracle | grep bin | awk '{print $NF}' | xargs lsof | while read line; do
	echo "ORACLE_JAVA_OPEN_FILES: $line"
done
	echo "ORACLE_JAVA_OPEN_FILES: (If you do not see any other lines that start with this then I was not able to detect any open files related to ${ORACLE_JAVA_BIN})"
fi

# close redirection
echo "FINISHED"
exec 1>&6 6>&-
echo "All tasks completed"

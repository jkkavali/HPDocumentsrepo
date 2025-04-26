#!/bin/bash

# ==============================================
# Script: checkK8SCertExpiry.sh
# Description: This script will check the Kubernetes Certificate expiry
# Platform: For both CN-A & CN-B
# Author: JFK (Please email jeffrey.h.ng@nokia.com to feedback for improvement)
# Execution point: To be run on Control Node as cloud-user / Master Node as cbis-admin
#
# Date     | Version | Author | Description
# ----------------------------------------------
# 20220103 | v1.0    | JFK    | First creation
# ==============================================
VERSION_NO=1.0
# ==============================================
EXPIRY_THRESHOLD=90

#printf colors
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
end=$'\e[0m'

printHelp()
{
	if [ "$1" != "" ]
	then
		printf "${red}"
		echo "$1"
	fi
	printf "${cyn}"
	echo "Usage:- $0 <command>"
	echo "    Version: $VERSION_NO"
	echo "Where:-"
	echo " command  = Command to run"
	echo "            check - Check for Expiry"
	printf "${end}"
	exit 0
}

# runCommand - Print and Execute commands (Not suitable if command include special characters like double-quotes)
# ==========
# 1) Command to execute
runCommand()
{
	# Print Command
	echo "${mag}- Command executed:${grn}[$1]${end}"
	# Run Command
	${1}
}

# printCommand - Print commands only.
# ==========
# 1) Command to execute
printCommand()
{
	# Print Command
	echo "${mag}- Command executed:${grn}[$1]${end}"
}

# Parameters
# ==========
# 1) Message to be printed
announceMessage()
{
	msgLen=${#1}
	printf "${blu}"
	for i in $(eval echo "{1..$msgLen}")
	do
		printf "="
	done
	echo ""
	echo "${1}"
	for i in $(eval echo "{1..$msgLen}")
	do
		printf "="
	done
	printf "${end}"
	echo ""
}

dateDiff() {
	d1=$(date -d "$1" +%s)
	d2=$(date +%s)
	expiry_days=$(( (d1 - d2) / 86400 ))
	if [ ${expiry_days} -lt $EXPIRY_THRESHOLD ]
	then
		echo "${yel}Certificate expiring in: ${red}${expiry_days} ${yel}days${end}"
	else
		echo "${yel}Certificate expiring in: ${grn}${expiry_days} ${yel}days${end}"
	fi
}

checkOpaqueSecret()
{
	TMP_CERT=/tmp/cert.tmp
	printCommand "sudo kubectl get secret --field-selector type=Opaque  -A  --no-headers -o=custom-columns='NAME:.metadata.name,NAMESPACE:.metadata.namespace,CERT:.data.tls\.crt'"
	sudo kubectl get secret --field-selector type=Opaque  -A  --no-headers -o=custom-columns='NAME:.metadata.name,NAMESPACE:.metadata.namespace,CERT:.data.tls\.crt' | grep -v "<none>" > $TMP_CERT
	echo "${cyn}- Opaque Secret list${end}"
	# Use the same entry to retrieve more info:
	while read line ; do 
		secret_name=`echo $line | awk '{print $1}'`
		namespace=`echo $line | awk '{print $2}'`
		cert=`echo $line | awk '{print $3}'`
		expiry=`echo "$cert" | base64 -d | openssl x509 -enddate -noout`
		exp_date=`echo ${expiry} | cut -d'=' -f2`
		echo "${mag}Secret Name: ${yel}${secret_name} ${grn}(${namespace})${end}"
		echo "${mag}Expiry: ${yel}${expiry}${end}"
		dateDiff "$exp_date"
	done < $TMP_CERT
	echo "${cyn}=========================================${end}"

	rm -rf $TMP_CERT
}

checkTLSSecret()
{
	TMP_CERT=/tmp/cert.tmp
	printCommand "sudo kubectl get secret --field-selector type=kubernetes.io/tls -A --no-headers -o=custom-columns='NAME:.metadata.name,NAMESPACE:.metadata.namespace,CERT:.data.tls\.crt'" 
	sudo kubectl get secret --field-selector type=kubernetes.io/tls -A --no-headers -o=custom-columns='NAME:.metadata.name,NAMESPACE:.metadata.namespace,CERT:.data.tls\.crt' > $TMP_CERT
	echo "${cyn}- TLS Secret list${end}"
	# Use the same entry to retrieve more info:
	while read line ; do 
		secret_name=`echo $line | awk '{print $1}'`
		namespace=`echo $line | awk '{print $2}'`
		cert=`echo $line | awk '{print $3}'`
		expiry=`echo "$cert" | base64 -d | openssl x509 -enddate -noout`
		exp_date=`echo ${expiry} | cut -d'=' -f2`
		echo "${mag}Secret Name: ${yel}${secret_name} ${grn}(${namespace})${end}"
		echo "${mag}Expiry: ${yel}${expiry}${end}"
		dateDiff "$exp_date"
	done < $TMP_CERT
	echo "${cyn}=========================================${end}"

	rm -rf $TMP_CERT
}

no_of_params=`expr "$#"`

if [ $no_of_params -lt 1 ]
then
	printHelp
else
	if [ "$1" == "check" ]
	then
		announceMessage "Checking for Kubernetes Certificate expiry (Version $VERSION_NO)"
		checkOpaqueSecret
		checkTLSSecret
	elif [ "$1" == "test" ]
	then
		checkOpaqueSecret
	else
		printHelp
	fi
fi

exit 0

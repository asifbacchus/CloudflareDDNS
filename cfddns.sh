#!/bin/bash


### Define functions

function scriptHelp {
echo -e "\e[1;31mInvalid parameter(s) provided\e[0m"
echo -e "\e[1;39mUsage: \e[1;36m$(basename ${0})" \
    "\e[1;35m-f path/to/account/details.file" \
    "\e[1;33m-r record.to.update\e[0m" \
    "\e[1;33m[-r another.record.to.update -r ...]" \
    "\e[0;92m[-i ipaddress]\e[0m\n"
echo -e "\e[1;39mExample: \e[1;36m$(basename ${0})" \
    "\e[1;35m-f /home/janedoe/myCloudFlareDetails.info" \
    "\e[1;33m-r server.mydomain.com\e[0m"
echo -e "\e[1;39mExample: \e[1;36m$(basename ${0})" \
    "\e[1;35m-f /home/janedoe/myCloudFlareDetails.info" \
    "\e[1;33m-r server.mydomain.com\e[0m" \
    "\e[1;33m-r server2.mydomain.com\e[0m"
echo -e "\e[1;39mExample: \e[1;36m$(basename ${0})" \
    "\e[1;35m-f /home/janedoe/myCloudFlareDetails.info" \
    "\e[1;33m-r server.mydomain.com" \
    "\e[0;92m-i 1.2.3.4\e[0m"
exit 1
}

### end of functions


### unset environment variables used in this script and initialize arrays
unset PARAMS
unset accountFile
unset ipAddress
dnsRecords=()
cfDetails=()
ip4=1
ip6=0


### Process script parameters
if [ -z $1 ]; then
    scriptHelp
fi

while getopts ':f:r:i:46' PARAMS; do
    case "$PARAMS" in
        f)
            accountFile="${OPTARG}"
            ;;
        r)
            dnsRecords+=($OPTARG)
            ;;
        i)
            ipAddress="$OPTARG"
            ;;
        4)
            ip4=1
            ip6=0
            ;;
        6)
            ip4=0
            ip6=1
            ;;
        ?)
            scriptHelp            
            ;;
    esac
done

# Check validity of parameters
if [ -z "$accountFile" ] || [[ $accountFile == -* ]]; then
    echo -e "\e[1;31mNo file containing account details was specified."
    echo -e "\e[0;31m(-f parameter empty or missing)\e[0m"
    exit 101
elif [ ! -s "$accountFile" ]; then
    echo -e "\e[1;31mAccount details file is either empty or does not" \
        "exist.\e[0m"
    exit 102
elif [ -z ${dnsRecords} ]; then
    echo -e "\e[1;31mNo DNS records were specified."
    echo -e "\e[0;31m(-r parameter(s) empty or missing)\e[0m"
    exit 103
fi


## Extract needed information from accountDetails file
mapfile -t cfDetails < "$accountFile"

## Get current IP address, if not provided in parameters
if [ -z "$ipAddress" ]; then
    echo -e "\e[0;36mNo IP address for update provided.  Detecting" \
        "this machine's IP address..."
    if [ $ip4 -eq 1 ]; then
        echo -e "\e[1;36m(set to IP4 mode)\e[0m"
        ipAddress=$(curl -s http://ipv4.icanhazip.com)
    elif [ $ip6 -eq 1 ]; then
        echo -e "\e[1;36m(set to IP6 mode)\e[0m"
        ipAddress=$(curl -s http://ipv6.icanhazip.com)
    fi
    ipLookupResult=$(echo "$?")
    if [ "$ipLookupResult" -ne 0 ]; then
        echo -e "\e[1;31mIP address for update could not be detected."
        echo -e "\e[0;31mPlease re-run script and specify an IP address" \
            "to use via the -i flag.\e[0m"
        exit 201
    else
        echo -e "\e[0;36mUsing IP address: $ipAddress"
    fi
fi

### Echo results (testing)
echo -e "\nBased on parameters provided:"
echo -e "\e[0;35mLogin details at: ${accountFile}"
echo -e "\tAuthorized email: ${cfDetails[0]}"
echo -e "\tAuthorized key: ${cfDetails[1]}"
echo -e "\tZone identifier: ${cfDetails[2]}"
echo -e "\e[0;33mUpdating records: ${dnsRecords[*]}"
if [ $ip4 -eq 1 ]; then
    echo -e "\e[0;92mUpdating A records"
elif [ $ip6 -eq 1 ]; then
    echo -e "\e[0;92mUpdating AAAA records"
fi
echo -e "\e[0;92mPointing records to IP: $ipAddress\e[0m\n"
exit 0

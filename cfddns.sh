#!/bin/bash


### Define functions

function scriptHelp {
echo -e "\e[1;39mUsage:"
echo -e "\e[1;36m$(basename ${0})" \
    "\e[1;35m-f /path/to/account/details.file"
echo -e "\t\e[1;33m-r record.to.update [-r another.record.to.update -r ...]"
echo -e "\t\e[0;92m[optional parameters]\e[0m\n"
echo -e "\e[1;39mNotes:\e[0m"
echo -e "-f and -r parameters are REQUIRED."
echo -e "Multiple A/AAAA records to update can be specified by supplying"
echo -e "\tmultiple -r parameters (see examples below)."
echo "This script can operate only in either IP4 OR IP6 mode. See below."
echo "This script will NOT verify the format or validity of supplied IP"
echo -e "\taddresses."
echo -e "\n\e[1;39mOptional parameters\e[0m"
echo -e "-i\tUse this IP address when updating DNS records"
echo -e "\tIf NOT supplied, the script will attempt to auto-detect this"
echo -e "\tmachine's IP address (depending on -4 or -6 parameters) and"
echo -e "\tuse that address for DNS updates.  The script does NOT check"
echo -e "\tthe validity of an address supplied using this parameter nor"
echo -e "\tthe protocol type (IP4 vs IP6)."
echo -e "-4\tOperate in IP4 mode and update A records (default)"
echo -e "\tThis is the default operating mode and does not need to be"
echo -e "\texplicitly specified.  Ensure you have supplied a valid IP4"
echo -e "\taddress using the -i parameter or that your machine's IP4"
echo -e "\taddress can be correctly detected externally."
echo -e "-6\tOperate in IP6 mode and update AAAA records"
echo -e "\tONLY AAAA records will be updated.  Ensure you have supplied"
echo -e "\ta valid IP6 address using the -i parameter or that your"
echo -e "\tmachine's IP6 address can be correctly detected externally."
echo -e "-h\tDisplay this help page"
echo -e "-x\tDisplay script examples"
echo -e "-l\tLocation for log file output"
echo -e "\tDefault: scriptname.log in same directory as this script"
echo -e "\n\e[1;39mExamples:"
echo -e "\e[0;39mRun \e[1;36m$(basename ${0}) \e[1;92m-x\e[0m\n"
echo -e "\n"

# exit with any error code used to call this help screen
quit none $1
}


function scriptExamples {
echo -e "\n\e[1;39m$(basename ${0}) Examples:\e[0m"
echo -e "\n\e[1;39mExample: \e[0mUse details from myCloudFlareDetails.info"
echo -e "file in /home/janedoe directory. Update server.mydomain.com A record"
echo -e "with this machine's auto-detected IP4 address."
echo -e "\t\e[1;36m$(basename ${0})" \
    "\e[1;35m-f /home/janedoe/myCloudFlareDetails.info"
echo -e "\t\e[1;33m-r server.mydomain.com\e[0m"
echo -e "\n\e[1;39mExample: \e[0mUse details from myCloudFlareDetails.info"
echo -e "file in /home/janedoe directory. Update server.mydomain.com AND"
echo -e "server2.mydomain.com A records with this machine's auto-detected IP6"
echo -e "address."
echo -e "\t\e[1;36m$(basename ${0})" \
    "\e[1;35m-f /home/janedoe/myCloudFlareDetails.info"
echo -e "\t\e[1;33m-r server.mydomain.com" \
    "-r server2.mydomain.com \e[1;92m-6\e[0m"
echo -e "\n\e[1;39mExample: \e[0mUse details from myCloudFlareDetails.info"
echo -e "file in /home/janedoe directory. Update server.mydomain.com A record"
echo -e "using IP4 address 1.2.3.4."
echo -e "\t\e[1;36m$(basename ${0})" \
    "\e[1;35m-f /home/janedoe/myCloudFlareDetails.info"
echo -e "\t\e[1;33m-r server.mydomain.com \e[1;92m-i 1.2.3.4\e[0m"
echo -e "\n\e[1;39mExample: \e[0mUse details from myCloudFlareDetails.info"
echo -e "file in /home/janedoe directory. Update server3.mydomain.com AND"
echo -e "server7.mydomain.com AAAA records using IP6 address FE80::286A:FF91."
echo -e "\t\e[1;36m$(basename ${0})" \
    "\e[1;35m-f /home/janedoe/myCloudFlareDetails.info"
echo -e "\t\e[1;33m-r server.mydomain.com" \
    "\e[1;33m-r server2.mydomain.com \e[1;92m-i FE80::286A:FF91\e[0m"

quit none
}


function quit {
    if [ -z "$1" ]; then
        # exit cleanly
        echo -e "${bold}${note}${stamp} -- Script completed --\${normal}" \
            >> "$logFile"
        exit 0
    elif [ "$1" = "none" ]; then
        if [ -z "$2" ]; then
            # exit cleanly
            exit 0
        else
            # exit with error code but don't log/display it
            exit "$2"
        fi
    elif [ "$1" = "199" ]; then
        # list DNS entries that were not updated
        for failedName in "${failedDNS[@]}"; do
            echo -e "${bold}${err}${stamp}" \
            "-- [ERROR] $failedName was NOT updated --${normal}" >> "$logFile"
        done
        exit "$1"
    else
        # notify use that error has occurred and provide exit code
        echo -e "${bold}${err}${stamp}" \
        "-- [ERROR] ${errorExplain[$1]} (code: $1) --${normal}" >> "$logFile"
        exit "$1"
    fi
}

### end of functions


### unset environment variables used in this script and initialize arrays
unset PARAMS
unset accountFile
unset ipAddress
errorExplain=()
dnsRecords=()
cfDetails=()
cfRecords=()
currentIP=()
recordID=()
failedDNS=()
ip4=1
ip6=0


### define script variables
# timestamp
stamp="${stamp}"
# formatting
normal="\e[0m"
bold="\e[1m"
default="\e[39m"
ok="\e[32m"
err="\e[31m"
info="\e[96m"
lit="\e[93m"
note="\e[35m"


## define error code explainations
errorExplain[1]="Missing or invalid parameters on script invocation."
errorExplain[2]="curl is required to access CloudFlare API.  Please install curl. (apt-get install curl on debian/ubuntu)."
errorExplain[101]="Location of file with CloudFlare account details was NOT provided (-f parameter missing)."
errorExplain[102]="CloudFlare account details file is empty or does not exist"
errorExplain[103]="No DNS records to update were specified (-r parameter(s) missing)."
errorExplain[104]="There are no DNS records specified that match those found in your CloudFlare account to update."
errorExplain[201]="Could not detect this machine's IP address. Please re-run this script with the -i option."
errorExplain[254]="Could not connect with CloudFlare API. Please re-run this script later."


## Logging parameters -- default set to scriptname.ext.log in same 
## directory as this script
scriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scriptName="$(basename ${0})"
logFile="$scriptPath/${scriptName%.*}.log"


### Process script parameters
if [ -z $1 ]; then
    scriptHelp 1
fi

while getopts ':f:r:i:46hxl:' PARAMS; do
    case "$PARAMS" in
        f)
            # path to file with CloudFlare account details
            accountFile="${OPTARG}"
            ;;
        r)
            # DNS records to update
            dnsRecords+=($OPTARG)
            ;;
        i)
            # IP address to use -- NOT parsed for correctness
            ipAddress="$OPTARG"
            ;;
        4)
            # Put script in IP4 mode (default)
            ip4=1
            ip6=0
            ;;
        6)
            # Put script in IP6 mode
            ip4=0
            ip6=1
            ;;
        h)
            # Display info on script usage
            scriptHelp
            ;;
        x)
            # Show examples of script usage
            scriptExamples
            ;;
        l)
            # Path to write log file
            logFile="${OPTARG}"
            ;;
        ?)
            scriptHelp 1
            ;;
    esac
done

# Log beginning of script
echo -e "${bold}${note}${stamp} -- Start CloudFlare" \
    "DDNS script execution --${normal}" >> "$logFile"

# Check validity of parameters
if [ -z "$accountFile" ] || [[ $accountFile == -* ]]; then
    quit 101
elif [ ! -s "$accountFile" ]; then
    quit 102
elif [ -z ${dnsRecords} ]; then
    quit 103
fi

# Check if curl is installed
command -v curl >> /dev/null
curlResult=$(echo "$?")
if [ "$curlResult" -ne 0 ]; then
    quit 2
fi

# Log operating mode
if [ $ip4 -eq 1 ]; then
    echo -e "${info}${stamp} Script running in" \
        "IP4 mode${normal}" >> "$logFile"
elif [ $ip6 -eq 1 ]; then
    echo -e "${info}${stamp} Script running in" \
        "IP6 mode${normal}" >> "$logFile"
fi


## Extract needed information from accountDetails file
mapfile -t cfDetails < "$accountFile"

## Get current IP address, if not provided in parameters
if [ -z "$ipAddress" ]; then
    echo -e "${info}${stamp} No IP address for" \
        "update provided.  Detecting this machine's IP address...${normal}" \
        >> "$logFile"
    if [ $ip4 -eq 1 ]; then
        ipAddress=$(curl -s http://ipv4.icanhazip.com)
    elif [ $ip6 -eq 1 ]; then
        ipAddress=$(curl -s http://ipv6.icanhazip.com)
    fi
    # check if curl reported any errors
    ipLookupResult=$(echo "$?")
    if [ "$ipLookupResult" -ne 0 ]; then
        quit 201
    fi
fi
echo -e "${info}${stamp} [INFO] Using IP address:" \
    "$ipAddress" >> "$logFile"


## Check if desired record(s) exist at CloudFlare
# perform checks on A or AAAA records based on invocation options
if [ $ip4 -eq 1 ]; then
    echo -e "${normal}${stamp}[INFO] Updating A: ${dnsRecords[*]}" \
        >> "$logFile"
    for cfLookup in "${dnsRecords[@]}"; do
    cfRecords+=("$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cfDetails[2]}/dns_records?name=$cfLookup&type=A" -H "X-Auth-Email: ${cfDetails[0]}" -H "X-Auth-Key: ${cfDetails[1]}" -H "Content-Type: application/json")")
    done
elif [ $ip6 -eq 1 ]; then
    echo -e "${normal}${stamp}[INFO] Updating AAAA: ${dnsRecords[*]})" \
        >> "$logFile"
    for cfLookup in "${dnsRecords[@]}"; do
    cfRecords+=("$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cfDetails[2]}/dns_records?name=$cfLookup&type=AAAA" -H "X-Auth-Email: ${cfDetails[0]}" -H "X-Auth-Key: ${cfDetails[1]}" -H "Content-Type: application/json")")
    done
fi
# check for curl errors
cfLookupResult=$(echo "$?")
if [ "$cfLookupResult" -ne 0 ]; then
    quit 254
fi
# check for any non-existant domain names and remove from array
for recordIdx in "${!cfRecords[@]}"; do
    if [[ ${cfRecords[recordIdx]} == *"\"count\":0"* ]]; then
        # inform user that domain not found in CloudFlare DNS records
        echo -e "${err}${stamp} -- [INFO]" \
            "${dnsRecords[recordIdx]} not found in your" \
            "CloudFlare DNS records --${normal}" >> "$logFile"
        # remove the entry from the dnsRecords array
        unset dnsRecords[$recordIdx]
        # remove the entry from the records array
        unset cfRecords[$recordIdx]
    fi
done
# contract the dnsRecords and cfRecords arrays to re-order them after any
# deleted records
dnsRecords=("${dnsRecords[@]}")
cfRecords=("${cfRecords[@]}")

# after trimming errant records, it's possible dnsRecords array is empty
# check for this condition and exit (nothing to do), otherwise list arrays
if [ -z ${dnsRecords} ]; then
    quit 104
else
    for recordIdx in "${!cfRecords[@]}"; do
        echo -e "${normal}${stamp} Found" \
            "${dnsRecords[recordIdx]} (Index: $recordIdx)" \
            >> "$logFile"
    done
fi


## Get existing IP address and identifier in CloudFlare's DNS records
for recordIdx in "${!cfRecords[@]}"; do
    currentIP+=($(echo "${cfRecords[recordIdx]}" | \
        grep -Po '(?<="content":")[^"]*'))
    recordID+=($(echo "${cfRecords[recordIdx]}" | \
        grep -Po '(?<="id":")[^"]*'))
    echo -e "${normal}${stamp} Index $recordIdx:" \
        "For record ${lit}${dnsRecords[recordIdx]}${normal}" \
        "with ID: ${recordID[recordIdx]}" \
        "the current IP is ${lit}${currentIP[recordIdx]}" \
        "${normal}" >> "$logFile"
done

## Check whether new IP matches old IP and update if they do not match
for recordIdx in "${!currentIP[@]}"; do
    if [ ${currentIP[recordIdx]} = $ipAddress ]; then
        echo -e "${bold}${ok}${stamp} -- [STATUS]" \
        "${dnsRecords[recordIdx]} is up-to-date.${normal}" \
            >> "$logFile"
    else
        echo -e "${lit}${stamp} -- [STATUS]" \
        "${dnsRecords[recordIdx]} needs updating...${normal}" \
            >> "$logFile"
        if [ $ip4 -eq 1 ]; then
            # update record at CloudFlare with new IP
            update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${cfDetails[2]}/dns_records/${recordID[recordIdx]}" -H "X-Auth-Email: ${cfDetails[0]}" -H "X-Auth-Key: ${cfDetails[1]}" -H "Content-Type: application/json" --data "{\"id\":\"${cfDetails[2]}\",\"type\":\"A\",\"proxied\":false,\"name\":\"${dnsRecords[recordIdx]}\",\"content\":\"$ipAddress\"}")
        elif [ $ip6 -eq 1 ]; then
            # update record at CloudFlare with new IP
            update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${cfDetails[2]}/dns_records/${recordID[recordIdx]}" -H "X-Auth-Email: ${cfDetails[0]}" -H "X-Auth-Key: ${cfDetails[1]}" -H "Content-Type: application/json" --data "{\"id\":\"${cfDetails[2]}\",\"type\":\"AAAA\",\"proxied\":false,\"name\":\"${dnsRecords[recordIdx]}\",\"content\":\"$ipAddress\"}")
        fi
        # check for success code from CloudFlare
        if [[ $update == *"\"success\":true"* ]]; then
            echo -e "${bold}${ok}${stamp} -- [SUCCESS]" \
                "${dnsRecords[recordIdx]} updated.${normal}" >> "$logFile"
        else
            failedDNS+=("${dnsRecords[recordIdx]}")
        fi        
    fi
done

# Check if failedDNS array contains entries and exit with error, else exit 0
if [ -z "${failedDNS}" ]; then
    quit
else
    quit 199
fi

# this code should never be executed
exit 99

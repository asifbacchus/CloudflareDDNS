#!/bin/sh

#
# update Cloudflare DNS records with current (dynamic) IP address
#    Script by Asif Bacchus <asif@bacchus.cloud>
#    Last modified: May 7, 2021
#

### text formatting presets using tput
if command -v tput >/dev/null; then
    bold=$(tput bold)
    cyan=$(tput setaf 6)
    err=$(tput bold)$(tput setaf 1)
    magenta=$(tput setaf 5)
    norm=$(tput sgr0)
    ok=$(tput setaf 2)
    warn=$(tput bold)$(tput setaf 3)
    yellow=$(tput setaf 3)
    width=$(tput cols)
else
    bold=""
    cyan=""
    err=""
    magenta=""
    norm=""
    ok=""
    warn=""
    yellow=""
    width=80
fi

### functions
badParam() {
    if [ "$1" = "null" ]; then
        printf "\n%sERROR: '%s' cannot have a NULL (empty) value.\n" "$err" "$2"
        printf "%sPlease use '--help' for assistance.%s\n\n" "$cyan" "$norm"
        exit 1
    elif [ "$1" = "dne" ]; then
        printf "\n%sERROR: '%s %s'\n" "$err" "$2" "$3"
        printf "file or directory does not exist or is empty.%s\n\n" "$norm"
        exit 1
    elif [ "$1" = "errMsg" ]; then
        printf "\n%sERROR: %s%s\n\n" "$err" "$2" "$norm"
        exit 1
    fi
}

exitError() {
    case "$1" in
    3)
        errMsg="Unable to connect to Cloudflare servers. This is probably a temporary networking issue. Please try again later."
        ;;
    10)
        errMsg="Unable to auto-detect IP address. Try again later or supply the IP address to be used."
        ;;
    20)
        errMsg="Cloudflare authorized email address (cfEmail) is either null or undefined. Please check your Cloudflare credentials file."
        ;;
    21)
        errMsg="Cloudflare authorized API key (cfKey) is either null or undefined. Please check your Cloudflare credentials file."
        ;;
    22)
        errMsg="Cloudflare zone id (cfZoneId) is either null or undefined. Please check your Cloudflare credentials file."
        ;;
    25)
        errMsg="Cloudflare API error. Please check the logs for 'CF-ERR-NO' and 'CF-ERR-MESSAGE' entries for details."
        ;;
    26)
        errMsg="${failedDomainCount} domain update(s) failed. Please review this log file for details."
        ;;
    *)
        printf "%s[%s] ERROR: An unspecified error occurred. Exiting.%s\n" "$err" "$(stamp)" "$norm" >>"$logFile"
        exit 99
        ;;
    esac
    printf "%s[%s] ERROR: %s (code: %s)%s\n" "$err" "$(stamp)" "$errMsg" "$1" "$norm" >>"$logFile"
    printf "%s[%s] -- Cloudflare DDNS update-script: execution completed with error(s) --%s\n" "$err" "$(stamp)" "$norm" >>"$logFile"
    exit "$1"
}

exitOK() {
    printf "%s[%s] -- Cloudflare DDNS update-script: execution complete --%s\n" "$ok" "$(stamp)" "$norm" >>"$logFile"
    exit 0
}

stamp() {
    (date +%F" "%T)
}

scriptExamples() {
    newline
    printf "Update Cloudflare DNS host A/AAAA records with current IP address.\n"
    printf "%sUsage: %s --records host.domain.tld[,host2.domain.tld,...] [parameters]%s\n\n" "$bold" "$scriptName" "$norm"
    textblock "${magenta}--- usage examples ---${norm}"
    newline
    textblockSwitches "${scriptName} -r myserver.mydomain.net"
    textblock "Update Cloudflare DNS records for myserver.mydomain.net with the auto-detected public IP4 address. Credentials will be expected in the default location and the log will be written in the default location also."
    newline
    textblockSwitches "${scriptName} -r myserver.mydomain.net -6"
    textblock "Same as above, but update AAAA host records with the auto-detected public IP6 address."
    newline
    textblockSwitches "${scriptName} -r myserver.mydomain.net,otherserver.mydomain.net -l /var/log/cfddns.log --nc"
    textblock "Update DNS entries for both listed hosts using auto-detected IP4 address. Write a non-coloured log to '/var/log/cfddns.log'."
    newline
    textblockSwitches "${scriptName} -r myserver.mydomain.net,otherserver.mydomain.net -l /var/log/cfddns.log --ip6 --ip fd21:7a62:2737:9c3a::a151"
    textblock "Update DNS AAAA entries for listed hosts using the *specified* IP address. Write a colourful log to the location specified."
    newline
    textblockSwitches "${scriptName} -r myserver.mydomain.net -c /root/cloudflare.creds -l /var/log/cfddns.log --ip 1.2.3.4"
    textblock "Update DNS A entry for listed hostname with the provided IP address. Read cloudflare credentials file from specified location, save log in specified location."
    newline
    textblockSwitches "${scriptName} -r myserver.mydomain.net -c /root/cloudflare.creds -l /var/log/cfddns.log -6 -i fd21:7a62:2737:9c3a::a151"
    textblock "Exact same as above, but change the AAAA record. This is how you run the script once for IP4 and again for IP6."
    exit 0
}

scriptHelp() {
    newline
    printf "Update Cloudflare DNS host A/AAAA records with current IP address.\n"
    printf "%sUsage: %s --records host.domain.tld[,host2.domain.tld,...] [parameters]%s\n\n" "$bold" "$scriptName" "$norm"
    textblock "The only required parameter is '--records' which is a comma-delimited list of hostnames to update. However, there are several other options which may be useful to implement."
    textblock "Parameters are listed below and followed by a description of their effect. If a default value exists, it will be listed on the following line in (parentheses)."
    newline
    textblock "${magenta}--- script related parameters ---${norm}"
    newline
    textblockSwitches "-c | --cred | --creds | --credentials | -f (deprecated, backward-compatibility)"
    textblock "Path to file containing your Cloudflare *token* credentials. Please refer to the repo README for more information on format, etc."
    textblockDefaults "(${accountFile})"
    newline
    textblockSwitches "-l | --log"
    textblock "Path where the log file should be written."
    textblockDefaults "(${logFile})"
    newline
    textblockSwitches "--nc | --no-color | --no-colour"
    textblock "Switch value. Disables ANSI colours in the log. Useful if you review the logs using a reader that does not parse ANSI colour codes."
    textblockDefaults "(disabled: print logs in colour)"
    newline
    textblockSwitches "--log-console"
    textblock "Switch value. Output log to console (stdout) instead of a log file. Can be combined with --nc if desired."
    textblockDefaults "(disabled: output to log file)"
    newline
    textblockSwitches "--no-log"
    textblock "Switch value. Do not create a log (i.e. no console, no file). You will not have *any* output from the script if you choose this option, so you will not know if updates succeeded or failed."
    textblockDefaults "(disabled: output to log file)"
    newline
    textblockSwitches "-h | --help | -?"
    textblock "Display this help screen."
    newline
    textblockSwitches "--examples"
    textblock "Show some usage examples."
    newline
    textblock "${magenta}--- DNS related parameters ---${norm}"
    newline
    textblockSwitches "-r | --record | --records"
    textblock "Comma-delimited list of hostnames for which IP addresses should be updated in Cloudflare DNS. This parameter is REQUIRED. Note that this script will only *update* records, it will not create new ones. If you supply hostnames that are not already defined in DNS, the script will log a warning and will skip those hostnames."
    newline
    textblockSwitches "-i | --ip | --ip-address | -a | --address"
    textblock "New IP address for DNS host records. If you omit this, the script will attempt to auto-detect your public IP address and use that."
    newline
    textblockSwitches "-4 | --ip4 | --ipv4"
    textblock "Switch value. Update Host 'A' records (IP4) only. Note that this script can only update either A *or* AAAA records. If you need to update both, you'll have to run the script once in IP4 mode and again in IP6 mode. If you specify both this switch and the IP6 switch, the last one specified will take effect."
    textblockDefaults "(enabled: update A records)"
    newline
    textblockSwitches "-6 | --ip6 | --ipv6"
    textblock "Switch value. Update Host 'AAAA' records (IP6) only. Note that this script can only update either A *or* AAAA records. If you need to update both, you'll have to run the script once in IP4 mode and again in IP6 mode. If you specify both this switch and the IP4 switch, the last one specified will take effect."
    textblockDefaults "(disabled: update A records)"
    newline
    textblock "Please refer to the repo README for more detailed information regarding this script and how to automate and monitor it."
    newline
    exit 0
}

stamp() {
    (date +%F" "%T)
}

newline() {
    printf "\n"
}

textblock() {
    printf "%s\n" "$1" | fold -w "$width" -s
}

textblockDefaults() {
    printf "%s%s%s\n" "$yellow" "$1" "$norm"
}

textblockSwitches() {
    printf "%s%s%s\n" "$cyan" "$1" "$norm"
}


### default variable values
scriptPath="$(CDPATH='' \cd -- "$(dirname -- "$0")" && pwd -P)"
scriptName="$(basename "$0")"
logFile="$scriptPath/${scriptName%.*}.log"
accountFile="$scriptPath/cloudflare.credentials"
colourizeLogFile=1
dnsRecords=""
dnsSeparator=","
ipAddress=""
ip4=1
ip6=0
ip4DetectionSvc="http://ipv4.icanhazip.com"
ip6DetectionSvc="http://ipv6.icanhazip.com"
invalidDomainCount=0
failedDomainCount=0

### process startup parameters
if [ -z "$1" ]; then
    scriptHelp
fi
while [ $# -gt 0 ]; do
    case "$1" in
    -h | -\? | --help)
        # display help
        scriptHelp
        ;;
    --examples)
        # display sample commands
        scriptExamples
        ;;
    -l | --log)
        # set log file location
        if [ -n "$2" ]; then
            logFile="${2%/}"
            shift
        else
            badParam null "$@"
        fi
        ;;
    --log-console)
        # log to the console instead of a file
        logFile="/dev/stdout"
        ;;
    --no-log)
        # do not log anything
        logFile="/dev/null"
        ;;
    --nc | --no-color | --no-colour)
        # do not colourize log file
        colourizeLogFile=0
        ;;
    -c | --cred* | -f)
        # path to Cloudflare credentials file
        if [ -n "$2" ]; then
            if [ -f "$2" ] && [ -s "$2" ]; then
                accountFile="${2%/}"
                shift
            else
                badParam dne "$@"
            fi
        else
            badParam null "$@"
        fi
        ;;
    -r | --record | --records)
        # DNS records to update
        if [ -n "$2" ]; then
            dnsRecords=$(printf "%s" "$2" | sed -e 's/ //g')
            shift
        else
            badParam null "$@"
        fi
        ;;
    -i | --ip | --ip-address | -a | --address)
        # IP address to use (not parsed for correctness)
        if [ -n "$2" ]; then
            ipAddress="$2"
            shift
        else
            badParam null "$@"
        fi
        ;;
    -4 | --ip4 | --ipv4)
        # operate in IP4 mode (default)
        ip4=1
        ip6=0
        ;;
    -6 | --ip6 | --ipv6)
        # operate in IP6 mode
        ip6=1
        ip4=0
        ;;
    *)
        printf "\n%sUnknown option: %s\n" "$err" "$1"
        printf "%sUse '--help' for valid options.%s\n\n" "$cyan" "$norm"
        exit 1
        ;;
    esac
    shift
done

### pre-flight checks
if ! command -v curl >/dev/null; then
    printf "\n%sThis script requires 'curl' be installed and accessible. Exiting.%s\n\n" "$err" "$norm"
    exit 2
fi
if ! command -v jq >/dev/null; then
    printf "\n%sThis script requires 'jq' be installed and accessible. Exiting.%s\n\n" "$err" "$norm"
    exit 2
fi
[ -z "$dnsRecords" ] && badParam errMsg "You must specify at least one DNS record to update. Exiting."
# verify credentials file exists and is not empty (default check)
if [ ! -f "$accountFile" ] || [ ! -s "$accountFile" ]; then
    badParam errMsg "Cannot find Cloudflare credentials file (${accountFile}). Exiting."
fi
# turn off log file colourization if parameter is set
if [ "$colourizeLogFile" -eq 0 ]; then
    bold=""
    cyan=""
    err=""
    magenta=""
    norm=""
    ok=""
    warn=""
    yellow=""
fi

### initial log entries
{
    printf "%s[%s] -- Cloudflare DDNS update-script: execution starting --%s\n" "$ok" "$(stamp)" "$norm"
    printf "Parameters:\n"
    printf "script path: %s\n" "$scriptPath/$scriptName"
    printf "credentials file: %s\n" "$accountFile"
} >>"$logFile"

if [ "$ip4" -eq 1 ]; then
    printf "mode: IP4\n" >>"$logFile"
elif [ "$ip6" -eq 1 ]; then
    printf "mode: IP6\n" >>"$logFile"
fi

# detect and report IP address
if [ -z "$ipAddress" ]; then
    # detect public ip address
    if [ "$ip4" -eq 1 ]; then
        if ! ipAddress="$(curl -s $ip4DetectionSvc)"; then
            printf "ddns ip address: %serror%s\n" "$err" "$norm" >>"$logFile"
            exitError 10
        fi
    fi
    if [ "$ip6" -eq 1 ]; then
        if ! ipAddress="$(curl -s $ip6DetectionSvc)"; then
            printf "ddns ip address: %serror%s\n" "$err" "$norm" >>"$logFile"
            exitError 10
        fi
    fi
    printf "ddns ip address (detected): %s\n" "$ipAddress" >>"$logFile"
else
    printf "ddns ip address (supplied): %s\n" "$ipAddress" >>"$logFile"
fi

# iterate DNS records to update
dnsRecordsToUpdate="$dnsRecords$dnsSeparator"
while [ "$dnsRecordsToUpdate" != "${dnsRecordsToUpdate#*${dnsSeparator}}" ] && { [ -n "${dnsRecordsToUpdate%%${dnsSeparator}*}" ] || [ -n "${dnsRecordsToUpdate#*${dnsSeparator}}" ]; }; do
    record="${dnsRecordsToUpdate%%${dnsSeparator}*}"
    dnsRecordsToUpdate="${dnsRecordsToUpdate#*${dnsSeparator}}"
    printf "updating record: %s\n" "$record" >>"$logFile"
done

printf "(end of parameter list)\n" >>"$logFile"

### read Cloudflare credentials
printf "[%s] Reading Cloudflare credentials... " "$(stamp)" >>"$logFile"
case "$accountFile" in
/*)
    # absolute path, use as-is
    # shellcheck source=./cloudflare.credentials
    . "$accountFile"
    ;;
*)
    # relative path, rewrite
    # shellcheck source=./cloudflare.credentials
    . "./$accountFile"
    ;;
esac
if [ -z "$cfKey" ]; then
    printf "%sERROR%s\n" "$err" "$norm" >>"$logFile"
    exitError 21
fi
if [ -z "$cfZoneId" ]; then
    printf "%sERROR%s\n" "$err" "$norm" >>"$logFile"
    exitError 22
fi
printf "DONE%s\n" "$norm" >>"$logFile"

### connect to Cloudflare and do what needs to be done!
dnsRecordsToUpdate="$dnsRecords$dnsSeparator"
if [ "$ip4" -eq 1 ]; then
    recordType="A"
elif [ "$ip6" -eq 1 ]; then
    recordType="AAAA"
fi

# iterate hosts to update
while [ "$dnsRecordsToUpdate" != "${dnsRecordsToUpdate#*${dnsSeparator}}" ] && { [ -n "${dnsRecordsToUpdate%%${dnsSeparator}*}" ] || [ -n "${dnsRecordsToUpdate#*${dnsSeparator}}" ]; }; do
    record="${dnsRecordsToUpdate%%${dnsSeparator}*}"
    dnsRecordsToUpdate="${dnsRecordsToUpdate#*${dnsSeparator}}"
    printf "[%s] Processing %s... " "$(stamp)" "$record" >>"$logFile"

    # exit if curl/network error
    if ! cfLookup="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cfZoneId}/dns_records?name=${record}&type=${recordType}" \
        -H "Authorization: Bearer ${cfKey}" \
        -H "Content-Type: application/json")"; then
        printf "%sERROR%s\n" "$err" "$norm" >>"$logFile"
        exitError 3
    fi

    # exit if API error
    # exit here since API errors on GET request probably indicates authentication error which would affect all remaining operations
    # no reason to continue processing other hosts and pile-up errors which might look like a DoS attempt
    cfSuccess="$(printf "%s" "$cfLookup" | jq -r '.success')"
    if [ "$cfSuccess" = "false" ]; then
        printf "%sERROR%s\n" "$err" "$norm"
        # get error code and message from CF API
        cfErrCode="$(printf "%s" "$cfLookup" | jq -r '.errors | .[] | .code')"
        cfErrMessage="$(printf "%s" "$cfLookup" | jq -r '.errors | .[] | .message')"
        printf "[%s] CF-ERR-NO: %s\n" "$(stamp)" "$cfErrCode"
        printf "[%s] CF-ERR-MSG: %s\n" "$(stamp)" "$cfErrMessage"
        exitError 25
    fi

    resultCount="$(printf "%s" "$cfLookup" | jq '.result_info.count')"

    # skip to next host if cannot find existing host record (this script *updates* only, does not create!)
    if [ "$resultCount" = "0" ]; then
        # warn if record of host not found
        printf "%sNOT FOUND%s\n" "$warn" "$norm" >>"$logFile"
        printf "%s[%s] WARNING: Cannot find existing record to update for DNS entry: %s%s\n" "$warn" "$(stamp)" "$record" "$norm" >>"$logFile"
        invalidDomainCount=$((invalidDomainCount + 1))
        continue
    fi

    objectId=$(printf "%s" "$cfLookup" | jq -r '.result | .[] | .id')
    currentIpAddr=$(printf "%s" "$cfLookup" | jq -r '.result | .[] | .content')
    printf "FOUND: IP = %s\n" "$currentIpAddr" >>"$logFile"

    # skip to next hostname if record already up-to-date
    if [ "$currentIpAddr" = "$ipAddress" ]; then
        printf "%s[%s] IP address for %s is already up-to-date%s\n" "$ok" "$(stamp)" "$record" "$norm" >>"$logFile"
        continue
    fi

    # update record
    printf "%s[%s] Updating IP address for %s... " "$cyan" "$(stamp)" "$record" >>"$logFile"
    updateJSON="$(jq -n --arg key0 content --arg value0 "${ipAddress}" '{($key0):$value0}')"

    # exit if curl/network error
    if ! cfResult="$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cfZoneId}/dns_records/${objectId}" \
        -H "Authorization: Bearer ${cfKey}" \
        -H "Content-Type: application/json" \
        --data "${updateJSON}")"; then
        printf "%sERROR%s\n" "$err" "$norm" >>"$logFile"
        exitError 3
    fi

    # note update success or failure
    cfSuccess="$(printf "%s" "$cfResult" | jq '.success')"
    if [ "$cfSuccess" = "true" ]; then
        printf "DONE%s\n" "$norm" >>"$logFile"
        printf "%s[%s] SUCCESS: IP address for %s updated%s\n" "$ok" "$(stamp)" "$record" "$norm" >>"$logFile"
    else
        printf "%sFAILED%s\n" "$err" "$norm" >>"$logFile"
        # get error code and message from CF API
        cfErrCode="$(printf "%s" "$cfResult" | jq -r '.errors | .[] | .code')"
        cfErrMessage="$(printf "%s" "$cfResult" | jq -r '.errors | .[] | .message')"
        printf "[%s] CF-ERR-NO: %s\n" "$(stamp)" "$cfErrCode"
        printf "[%s] CF-ERR-MSG: %s\n" "$(stamp)" "$cfErrMessage"
        printf "%s[%s] ERROR: Unable to update IP address for %s%s\n" "$err" "$(stamp)" "$record" "$norm" >>"$logFile"
        # do not exit with error, API error here is probably an update issue specific to this host
        # increment counter and note it after all processing finished
        failedDomainCount=$((failedDomainCount + 1))
    fi
done

# exit
if [ "$invalidDomainCount" -ne 0 ]; then
    printf "%s[%s] -- WARNING: %s invalid domain(s) were supplied for updating --%s\n" "$warn" "$(stamp)" "$invalidDomainCount" "$norm" >>"$logFile"
fi
if [ "$failedDomainCount" -ne 0 ]; then
    exitError 26
else
    exitOK
fi

### exit return codes
# 0:    normal exit, no errors
# 1:    invalid or unknown parameter
# 2:    cannot find or access required external program(s)
# 3:    curl error (probably connection)
# 10:   cannot auto-detect IP address
# 21:   accountFile has a null or missing cfKey variable
# 22:   accountFile has a null or missing cfZoneId variable
# 25:   Cloudflare API error
# 26:   one or more updates failed
# 99:   unspecified error occurred

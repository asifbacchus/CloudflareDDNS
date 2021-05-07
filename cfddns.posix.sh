#!/bin/sh

#
# update CloudFlare DNS records with current (dynamic) IP address
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

stamp() {
    (date +%F" "%T)
}

scriptHelp() {
    printf "\nEventually an in-script help will be here...\n\n"
    exit 0
}

quit() {
    if [ -z "$1" ]; then
        # exit gracefully
        printf "%s[%s] -- CloudFlare DDNS update-script: execution complete --%s\n" "$ok" "$(stamp)" "$norm" >>"$logFile"
        exit 0
    fi
}

### default variable values
scriptPath="$(CDPATH='' \cd -- "$(dirname -- "$0")" && pwd -P)"
scriptName="$(basename "$0")"
logFile="$scriptPath/${scriptName%.*}.log"
accountFile="$scriptPath/cloudflare.credentials"
colourizeLogFile=1
dnsRecords=""
dnsSeparator=","
ipAddress="$(hostname -i)"
ip4=1
ip6=0
errCount=0
warnCount=0

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
    -l | --log)
        # set log file location
        if [ -n "$2" ]; then
            logFile="${2%/}"
            shift
        else
            badParam null "$@"
        fi
        ;;
    --nc | --no-color | --no-colour)
        # do not colourize log file
        colourizeLogFile=0
        ;;
    -c | --cred* | -f)
        # path to CloudFlare credentials file
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
        ;;
    -6 | --ip6 | --ipv6)
        # operate in IP6 mode
        ip6=1
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
    printf "\n%sThis script requires curl be installed and accessible. Exiting.%s\n\n" "$err" "$norm"
    exit 2
fi
[ -z "$dnsRecords" ] && badParam errMsg "You must specify at least one DNS record to update. Exiting."
[ "$ip4" -eq 1 ] && [ "$ip6" -eq 1 ] && badParam errMsg "Cannot operate in IP4 and IP6 modes simultaneously. Exiting."
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
    printf "%s[%s] -- CloudFlare DDNS update-script: execution starting --%s\n" "$ok" "$(stamp)" "$norm"
    printf "%sParameters:\n" "$magenta"
    printf "script path: %s\n" "$scriptPath/$scriptName"
    printf "credentials file: %s\n" "$accountFile"
    if [ "$ip4" = 1 ]; then
        printf "mode: IP4\n"
    elif [ "$ip6" = 1 ]; then
        printf "mode: IP6\n"
    fi
    printf "ddns ip address: %s\n" "$ipAddress"
    # iterate DNS records to update
    dnsRecordsToUpdate="$dnsRecords$dnsSeparator"
    while [ "$dnsRecordsToUpdate" != "${dnsRecordsToUpdate#*${dnsSeparator}}" ] && { [ -n "${dnsRecordsToUpdate%%${dnsSeparator}*}" ] || [ -n "${dnsRecordsToUpdate#*${dnsSeparator}}" ]; }; do
        record="${dnsRecordsToUpdate%%${dnsSeparator}*}"
        dnsRecordsToUpdate="${dnsRecordsToUpdate#*${dnsSeparator}}"
        printf "updating record: %s\n" "$record"
    done
    printf "(end of parameter list)%s\n" "$norm"
} >>"$logFile"

exit 0

### exit return codes
# 0:    normal exit, no errors
# 1:    invalid or unknown parameter
# 2:    cannot find or access curl

# CloudflareDDNS <!-- omit in toc -->

Update your *existing* Cloudflare DNS records with your current (dynamic) IP address via systemd timers and a (POSIX) shell script.

## Contents <!-- omit in toc -->

<!-- toc -->

- [Prerequisites](#prerequisites)
- [cfddns&#46;sh](#cfddns%2346sh)
  * [Installation](#installation)
  * [Usage](#usage)
    + [Parameters](#parameters)
- [Cloudflare credentials file](#cloudflare-credentials-file)
  * [File structure](#file-structure)
  * [Bearer token](#bearer-token)
  * [Zone ID](#zone-id)
- [cfddns.service](#cfddnsservice)
  * [IP4 and/or IP6](#ip4-andor-ip6)
    + [Examples](#examples)
- [cfddns.timer](#cfddnstimer)
  * [Activation](#activation)
- [Logging](#logging)
  * [Using Logwatch to monitor this script](#using-logwatch-to-monitor-this-script)
  * [Using Logrotate to control log file size](#using-logrotate-to-control-log-file-size)
- [Final thoughts](#final-thoughts)

<!-- tocstop -->

## Prerequisites

This script requires that `curl` and `jq` are installed. `curl` is used to interact with the Cloudflare API and `jq` is used to efficiently and reliably construct/deconstruct the JSON strings and arrays which is how the Cloudflare API communicates. In most cases you can install these programs using your package manager running as root or via sudo. On Debian/Ubuntu, for example, you would run:

```bash
apt install -y curl jq
```

While the script does *not* require root privileges, you will need sudo/root access to install the *systemd* service and timer.

## cfddns&#46;sh

### Installation

I recommend putting this script in your */usr/local/bin* directory or somewhere else in your path so it's easy to run.

1. Copy the script file to your desired path and rename if you want.

   ```Bash
   sudo cp cfddns.sh /usr/local/bin/   # just copy it
   sudo cp cfddns.sh /usr/local/bin/cloudflare-update.sh   # copy and rename (choose any name)
   ```

2. Make it executable:

   ```Bash
   sudo chmod +x /usr/local/bin/cfddns.sh
   ```

> Note: You can rename *cfddns.sh* to anything you want, the script will auto-update itself. However, you **must** manually update the systemd service file (*cfddns.service*) `ExecStart` line as [explained below](#cfddns.service).

### Usage

If you run the script with no parameters, it will display the help screen.  The script accepts several parameters with only one (1) being required.  The parameters are summarized below.  You can access the help screen and example usage screens by running:

```Bash
cfddns.sh --help   # display help screen
cfddns.sh --examples   # show script usage examples
```

#### Parameters

|Parameter|Description|Default|Required?|
|---|---|---|:---:|
|-r<br>--record<br>--records|The fully qualified hostname(s) that should be updated with new IP addresses. You can supply a comma-delimited list (no spaces) or just one. Note that the script can only update *either* A *or* AAAA records during a single run so you may need to batch your hostnames, depending on your set-up.<br>N.B. This script will only update *existing* host records, it will **not** create new ones!|none|YES|
|-c<br>--cred<br>--creds<br>--credentials<br>-f|Full path to your CloudFlare credentials file. This file contains your access token and zone id. See the [relevant section](#cloudflare-credentials-file) of this readme for more information.|scriptPath/cloudflare.credentials|NO|
|-i<br>--ip<br>--ip-address<br>-a<br>--address|The IP address that should be used to update Host A/AAAA records. If you omit this value, the script will attempt to auto-detect your public IP4/IP6 address and use that as appropriate. Use this option to manually force a specific IP to be used or when auto-detection fails. Note that the script does *not* check your IP addresses for correctness or proper form!|IP4 auto-detect|NO|
|-4<br>--ip4<br>--ipv4|Update Host A records only (IP4). The script can only update *either* A *or* AAAA records in a single run. If you specify this and also use the IP6 mode switch, the most recent one will take effect.|Enabled, update A records|NO|
|-6<br>--ip6<br>--ipv6|Update Host AAAA records only (IP6). The script can only update *either* A *or* AAAA records in a single run. If you specify this and also use the IP4 mode switch, the most recent one will take effect.|Disabled, update A records|NO|
|||||
|-l<br>--log|Full path where the script should save its log. Recommend */var/log/scriptName.log*|scriptPath/scriptName.log|NO|
|--nc<br>--no-color<br>--no-colour|Do not use ANSI colour-coding when writing to the log. This is useful if you review the logs using a reader that does not support ANSI colour-coding and instead displays control symbols which makes your log difficult to read.|Disabled, do colourful logs|NO|
|--log-console|Output the log to the console instead of a log file. You may use `--nc` with this option also.|Disabled, write to log file|NO|
|--no-log|Do not write a log file or output to the console. You will not have **any** feedback from the script if you run in this mode so you will not know if updates were successful or not. I’m not really sure why you’d want this option, but it’s available.|Disabled, write to log file|NO|
|-h<br>--help<br>-?|Display built-in help screen explaining these same parameters.|||
|--examples|Display some usage examples. Sometimes it's just easier to understand by seeing rather than reading.|||

## Cloudflare credentials file

This repo includes a sample credentials file (*cloudflare.credentials* at the root of the repo) with pretty self-explanatory variable names. The script reads this file to get the credentials it needs to connect to your Cloudflare account and update DNS entries. It should be noted that the script is designed to use a *bearer token* and **not** your username/password or your Global API token! Let’s break this down in case things are a little fuzzy still...

### File structure

The file is a basic shell script variables file. Make sure you **do not** put spaces between the variable name, equal sign and the value. Also, **do not** add any executable code since it will be run! The file should contain values for the following two variables:

| Variable | Value                                                        |
| -------- | ------------------------------------------------------------ |
| cfKey    | The bearer token granting access to *edit* the DNS records of the zone (domain) in question. |
| cfZoneId | The Cloudflare Zone ID of the zone (domain) you wish to update. |

You can add comments if you’d like since the script will ignore them. In the end, your file should look something like this, but obviously with your data instead of this nonsense sample information:

```ini
#
# Cloudflare token for my.domain.tld
#

cfKey=_dLuyyRNaKN8SLG4-csmNYYfC39nnCmPVA7aYUJj
cfZoneId=83d564234134513245311b23412331dd

```

You can save the file as anything you like and anywhere you’d like as long as you inform the script of its location using the `--credentials` parameter. By default, the script will look for a file named *cloudflare.credentials* in the same path as the script.

### Bearer token

I chose to use an API bearer token instead of a username/password or Global API token for security reasons. Your username/password and Global API token provide unfettered access to your account so if anyone gets hold of them, they can do anything to your account. An API bearer token, by contrast, can only do what you authorize it to do and you can revoke it at any time. Therefore, I suggest making a bearer token that is based on the “Edit zone DNS” template and restricted to the specific domain/zone you wish to update. Cloudflare provides an [excellent article](https://support.cloudflare.com/hc/en-us/articles/200167836-Managing-API-Tokens-and-Keys) on how to generate this token.

> N.B. This is a breaking change from previous versions of this script!

### Zone ID

This is required by the Cloudflare API so it knows which zone you are editing and can check the permissions of the bearer token. This script only caters to one zone so likely only one domain per configuration file. If you need to update multiple zones, you can have multiple configuration files and call them as required on separate invocations of the script.

To get your Zone ID, log into your Cloudflare account and open the domain in question. On the overview page, scroll down a bit and look to the right. You will see your Zone ID listed there. Copy that string into your configuration file.


## cfddns.service

This file **must** be copied to your */etc/systemd/system* directory (or equivalent directory if you're not running Debian/Ubuntu). If you change the name of the cfddns&#46;sh file, you must update the filename in the `ExecStart` line as shown below:

````Ini
...
[Service]
Type=oneshot
ExecStart=/full/path/to/your/renamed.file -parameter1 -parameter2 -parameter...
...
````

Don’t forget to reload systemd after copying this file so it is recognized by the system! On most systems you can do this by running the following as root or via sudo:

```bash
systemctl daemon-reload
```

### IP4 and/or IP6

The cfddns.service file includes two *ExecStart* lines, one without a specified IP-protocol parameter (default IP4) and the other with the -6 (IP6) parameter. The service will run the cfddns&#46;sh script in default (IP4) mode with specified parameters first and then will run the script again in IP6 mode with specified parameters.

*Note: The parameters *can be different* in each case.*

#### Examples

1. **Only update A records**
    Update *mail<span>.example.com* A record with the current auto-detected public IP4 address of this machine and log results to */var/log/cfddns.log*.
  
    ```Ini
   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/cfddns.sh -c /root/cloudflare.credentials -r mail.example.com -l /var/log/cfddns.log
   ...
   ```

2. **Only update AAAA records**
    Update *git<span>.example.com* and *mail<span>.example.com* AAAA records with the current auto-detected public IP6 address of this machine. Log will be stored in the same directory as the script file (/usr/local/bin).

    ```Ini
    [Service]
    Type=oneshot
    ExecStart=/usr/local/bin/cfddns.sh -6 -c /home/johndoe/cloudflare.credentials -r git.example.com,mail.example.com
    ...
    ```

3. **Update A records then AAAA records**
   Update *mail<span>.example.com* A record with auto-detected public IP4 address of this machine and write to log file stored at */var/log/DDNS_IP4.log*.  Then, update both *mail<span>.example.com* and *git<span>.example.com* AAAA records with the specified IP6 address and write to log file at */var/log/DDNS_IP6.log*.
   
   ```Ini
   [Service]
   Type=oneshot
   # update IP4 addresses
   ExecStart=/usr/local/bin/cfddns.sh -c /dir1/account.cf -r mail.example.com -l /var/log/DDNS_IP4.log
   # update IP6 addresses
   ExecStart=/usr/local/bin/cfddns.sh -6 -c /dir2/cloudflare.details -r mail.example.com,git.example.com --ip fd3f:e6db:9817:df84::a001 -l /var/log/DDNS_IP6.log
   ...
   ```

## cfddns.timer

This is the timer file that tells your system how often to call the *cfddns.service* file which runs the *cfddns&#46;sh* script.  By default, the timer is set for 5 minutes after the system boots up (to allow for other processes to initialize even on slower systems like a RasPi) and is then run every 15 minutes thereafter.  Remember when setting your timer that Cloudflare limits API calls to 1200 every 5 minutes.

You can change the timer by modifying the relevant section of the *cfddns.timer* file:

```Ini
[Timer]
OnBootSec=5min
OnUnitActiveSec=15min
```

*OnBootSec* is how long to wait after the system boots up before executing the *cfddns.service*.  *OnUnitActiveSec* will then wait the specified time from that first (after boot) call or after the timer is explicitly started before calling *cfddns.service* again.  I recommend setting OnUnitActiveSec to a low value (like 2 minutes) for testing then setting it to a more reasonable time (like 15
minutes) after everything is working.

### Activation

You can start the timer system immediately via *systemctl*

```Bash
systemctl start cfddns.timer
```

and can enable it to start automatically on boot by typing

```Bash
systemctl enable cfddns.timer
```

You can check the status of the timer via systemctl also

```Bash
systemctl status cfddns.timer
```

It is NOT necessary to enable/start the *cfddns.service*, only the timer needs to be active.

## Logging

The script logs every major action it takes and provides details on any errors it encounters in the log file (see the [parameters section](#parameters) for details about setting log location and name).  If errors are encountered, they are colour coded red and an explanation of the error code is provided.

While the log file is as terse as I felt reasonable, you may still want to configure any log-watch programs to further filter things for you so you don't have to review this log as part of your daily routine.  To make that easier, the following conventions are observed in the log file and can be used to program your log-watch system:

- Specific update process errors: **[TIMESTAMP] ERR: message**
  - These can be counted/filtered separately if you only care about update errors and not any other errors.
- Error messages: **[TIMESTAMP] ERROR: message (code: number)**
  - Only one summary error message will be displayed for any/all update errors. This message contains a tally of failed updates. If you want to count individual update errors, filter for the above process error message format.
  - While process error messages only relate to updates, these general error messages are logged for a variety of error conditions so it’s a good idea to include them in any filters.
- Cloudflare API error messages:  **[TIMESTAMP] CF-ERR: message (code: cf-error-code)**
  - These are only logged when update process errors occur so that you can see exactly what the Cloudflare API is complaining about.
- Specific update process warnings: **[TIMESTAMP] WARN: message**
  - These can be counted/filtered separately from general warning messages. Presently, there are *no* general warning messages.
- Warning messages: **[TIMESTAMP] WARNING: message**
  - Summary of each type of warning. Contains a tally of the specific warning.
  - Currently, warnings are only issued for hostnames that are not found (i.e. update process warnings).
- Success messages: **[TIMESTAMP] SUCCESS: message**
  - Each successful update generates a success message. There is no process or tally message.
- Already up-to-date: **[TIMESTAMP] IP address for {fqdn} is already up-to-date**
  - Already up-to-date host entries generate a success message but you may still want to filter for them separately using this criteria.
- A session log always starts with **[TIMESTAMP] -- Cloudflare DDNS update-script: starting --**
- A successful session log always ends with **[TIMESTAMP] -- Cloudflare DDNS update-script: completed successfully --**
- A session ending with errors always ends with **[TIMESTAMP] -- Cloudflare DDNS update-script: completed with error(s) --**

### Using Logwatch to monitor this script

If you are using the Logwatch package to monitor your system, see the README in the */etc/logwatch* folder for details about the pre-configured service files already done for you :-)

### Using Logrotate to control log file size

Logrotate is pre-installed on standard Debian/Ubuntu distributions and is a great way to automatically rotate your log files and control how many old logs you keep on your system so they don't accumulate and eat up your disk space. I've included a sample configuration file you can copy to your */etc/logrotate.d/* folder.  This file is set up to rotate your logs once a week, keep 3 weeks worth of history (compressed) and delete all logs older than that.  The configuration file is located in this git archive at
*/etc/logrotate.d/cfddns* and is fully commented to help you customize it to suit your needs.

## Final thoughts

Hopefully this helps you with an easy and reliable way to  update your Cloudflare DNS entries with a dynamic IP address. Please feel free to comment and provide feedback and suggestions to make this script better!

Please check out my blog at [https://mytechiethoughts.com](https://mytechiethoughts.com) where I tackle problems like this all the time and find free/cheap solutions to tech problems.
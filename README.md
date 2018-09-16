# CloudflareDDNS {ignore=true}

Update your CloudFlare DNS records with your current (dynamic) IP address via
systemd timers and a bash script.

**NOTE: You can rename *cfddns.sh* to anything you want, the script will
auto-update itself.  However, you MUST update the systemd service file
*(cfddns.service)* *ExecStart* line manually as explained below.**

## Contents {ignore=true}
<!-- @import "[TOC]" {cmd="toc" depthFrom=1 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

* [cfddns&#46;sh](#cfddns46sh)
		* [Installation:](#installation)
		* [Usage:](#usage)
* [cfddns.service](#cfddnsservice)
		* [IP4 and/or IP6](#ip4-andor-ip6)
		* [Examples](#examples)
* [cfddns.timer](#cfddnstimer)
		* [Activation](#activation)
* [The log file](#the-log-file)
* [Final thoughts](#final-thoughts)

<!-- /code_chunk_output -->

## cfddns&#46;sh

#### Installation:

I recommend putting this script in your */usr/local/bin* directory or somewhere
else in your path so it's easy to run.

1. Copy the script file to your desired path and rename if you want.

   ```Bash
   sudo cp cfddns.sh /usr/local/bin/   # just copy it
   sudo cp cfddns.sh /usr/local/bin/myscript.sh   # copy and rename
   ```

2. Make it executable:

   ```Bash
   sudo chmod +x /usr/local/bin/cfddns.sh
   ```

#### Usage:
If you run the script with no parameters, it will display the help screen.  The
script accepts several parameters with 2 being required.  The parameters are
summarized here.  You can access the help screen and example usage screens by 
running:

```Bash
cfddns.sh -h   # display help screen
cfddns.sh -x   # show script usage examples
```

**-f: full path and filename containing account details (REQUIRED)**
This is the full path to a plain-text file containing your CloudFlare account 
details.  This file must contain 3 lines in the following order:

* authorized email address
   This is an email address that is permitted to login to your CloudFlare account.
* global api-key
   You can get your Global API-key by going to your CloudFlare dashboard,
   clicking on your profile picture in the upper-right and opening your profile.
   Scroll down to to the API Keys section.  Click on the 'View' button next to
   Global API Key.
* zone identifier
   You should be able to find this on the Overview page of your CloudFlare dashboard.
  
Your completed file should look like (these are not real credentials):
> johndoe<span>@example.com
> e7882db52804aca6fab22780e055b97056466
> 492af8aa69f8c44baf043342c74319fd

Your global API-key is equivalent to your account password, so you should
secure this file by changing the owner of the file to root

```Bash
chown root:root path/to/filename
```

and then restricting access to only the root user

```Bash
chmod 600 path/to/filename
```

**-r: target DNS entry to update (REQUIRED)**
At least one entry here is *required*.  This is the A or AAAA record you want to
update the IP address for in your DNS zone file.  If you have multiple A or AAAA
records you want to update, simply specifiy multiple -r parameters.

*Note: You can only specify *either* A records *or* AAAA records.  You have to
update IP4 and IP6 records separately by running this script multiple times
(once for A records, once for AAAA records even if the hostname is the same).*

**-4 or -6: type of record to update**
The default option is -4 and it does not need to be specified.  This will update
*A records* specified by the -r parameter(s).  If you specify -6, then *AAAA
records* will updated as specified by the -r parameter(s).

**-i: use the specified IP address**
The script will auto-detect the IP address of the machine it's being run on by
accessing an external service and asking for that service to echo the machine's
IP address.  If running with -4, then the IP4 will be requested for echo.  If
running with -6, then the IP6 address will be requested for echo.

This parameter let's you bypass auto-detection and specify a particular address
to be used instead.  This parameter is most useful if running the script
manually to update a particular DNS record.  In most cases, you'd want your
current IP address auto-detected (i.e. omit this parameter).

*NOTE: The address you supply is NOT checked for correctness.  Ensure you're
supplying a valid address of the correct type based on your choice of -4 or -6
parameter!*

**-l (lower-case L): specify where the log file should be written**
The script will default to writing it's log file in the same directory as the
script is located.  It will use it's own name and append a *.log* extension.
So, the default name for the log file is *cfddns.log*.  If you rename the script
*something&#46;sh* then the generated log file name will be *something.log*.

This can be messy if you store the script in /usr/local/bin/ as recommended.
Therefore, it's recommended you choose a different location for
the log file (*/var/log/cfddns.log* is recommended).

```Ini
[Service]
...
ExecStart=/usr/local/bin/cfddns.sh -l /var/log/cfddns.log ...
```

**-h: display help**
Displays the help screen, which is an abbreviated version of this section you
are currently reading.

**-x: display examples**
This is the best way to learn how this script works.  Several examples are
provided

## cfddns.service
This file **must** be copied to your */etc/systemd/system* directory (or
equivalent directory if you're not running debian/ubuntu).  If you change the 
name of the cfddns&#46;sh file, you must update the filename in the *ExecStart*
line as shown below:

````Ini
...
[Service]
Type=oneshot
ExecStart=/full/path/to/your/renamed.file -parameter1 -parameter2 -parameter...
...
````

#### IP4 and/or IP6
The cfddns.service file includes two *ExecStart* lines, one without a specified
IP-protocol parameter (default IP4) and the other with the -6 (IP6) parameter.
The service will run the cfddns&#46;sh script in default (IP4) mode with specified
parameters first and then will run the script again in IP6 mode with specified
parameters.

*Note: The parameters *can be different* in each case.*

#### Examples
1. **Only update A records**
  Update *mail<span>.example.com* A record with the current IP of this machine and log
  results to */var/log/cfddns.log*.

   ```Ini
   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/cfddns.sh -f /root/accountDetails.cloudflare
   -r mail.example.com -l /var/log/cfddns.log
   ...
   ```

2. **Only update AAAA records**
  Update *git<span>.example.com* and *mail<span>.example.com* AAAA records with the current
  IP6 address of this machine. Log will be stored in the same directory as the
  script file (/usr/local/bin).

   ```Ini
   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/cfddns.sh -6 -f /home/johndoe/account.details
   -r git.example.com -r mail.example.com
   ...
   ```

3. **Update A records then AAAA records**
   Update *mail<span>.example.com* A record with current IP address of this machine and
   write to log file stored at */var/log/DDNS_IP4.log*.  Then, update both
   *mail<span>.example.com* and *git<span>.example.com* AAAA records with current IP address
   of this machine and write to log file at */var/log/DDNS_IP6.log*.

   ```Ini
   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/cfddns.sh -f /dir1/account.cf -r mail.example.com
   -l /var/log/DDNS_IP4.log
   ExecStart=/usr/local/bin/cfddns.sh -6 -f /dir2/cloudflare.details
   -r mail.example.com -r git.example.com -l /var/log/DDNS_IP6.log
   ...
   ```

## cfddns.timer
This is the timer file that tells your system how often to call the
cfddns.service file which runs the cfddns&#46;sh script.  By default, the timer is
set for 5 minutes after the system boots up (to allow for other processes to
initialize even on slower systems like a RasPi) and is then run every 15
minutes thereafter.  Remember when setting your timer that CloudFlare limits
API calls to 1200 every 5 minutes.

You can change the timer by modifying the relevant section of the cfddns.timer
file:

```Ini
[Timer]
OnBootSec=5min
OnUnitActiveSec=15min
```

*OnBootSec* is how long to wait after the system boots up before executing
the cfddns.service.  *OnUnitActiveSec* will then wait the specified time from that
first (after boot) call or after the timer is explicitly started before calling
cfddns.service again.  I recommend setting OnUnitActiveSec to a low value (like
2 minutes) for testing then setting it to a more reasonable time (like 15
minutes) after everything is working.

#### Activation
You can start the timer system immediately via systemctl

```Bash
systemctl start cfddns.timer
```

and can enable it to start automatically on system start up by typing

```Bash
systemctl enable cfddns.timer
```

You can check the status of the timer via systemctl also

```Bash
systemctl status cfddns.timer
```

It is NOT necessary to enable/start the *cfddns.service*, only the timer needs
to be active.

## The log file
The script logs every major action it takes and provides details on any errors
it encounters in the log file (see the above section for details on log file
location and name).  If errors are encountered, they are colour coded red and
an explanation of the error code is provided.

While the log file is as terse as I felt reasonable, you may still want to
configure any log-watch programs to further filter things for you so you don't
have to review this log as part of your daily routine.  To make that easier, the
following conventions are observed in the log file and can be used to program
your log-watch system:

* Errors always appear as **-- [ERROR] text and error code here --**
* Errors are followed by an explanation of the specific error code on a new line
* A clean exit appears as **-- [SUCCESS] some text here --**
* The script always starts a new set of log entries with **-- Start CloudFlare
  DDNS script execution --**
* All log file entries start with a time-stamp in **[square brackets]**

## Final thoughts
I'm by no means an expert in BASH scripting and I only program/script as a hobby
when I find stuff that irritates me and no other good solutions seem easily 
available.  So, by all means, please comment, provide feedback and suggestions
to make this script better!  Thanks, I hope this helps someone else out!

Please check out my blog at [https://mytechiethoughts.com](https://mytechiethoughts.com) where I tackle
problems like this all the time and find free/cheap solutions to tech problems.
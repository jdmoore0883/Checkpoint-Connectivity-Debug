# Checkpoint-Connectivity-Debug
A script to quickly grab connection details and package it all together, so you can go a restart/reboot as needed, and provide the package to Checkpoint TAC for further analysis

=======================
Installation
=======================
Note: Please be sure to install this script PRIOR to any issues manifesting themselves

There are 3 ways we can "install" this script for use by admins, and it all boils down to the "install" directory (in order of preference):

1. We can set this up for use by ALL admins, use directory:	/bin

2. We can set this up for use by SPECIFIC admins, use directory:	~/bin

3. You can put it in any directory, so long as it is remembered when you want to run it.

Install process:

1. Download the script to your device:
  - curl -Lk https://<i></i>github.com/jdmoore0883/Checkpoint-Connectivity-Debug/raw/master/connCheck.sh -o /bin/connCheck.sh
	or
  - curl -Lk http://<i></i>bit.ly/2bYXiJo -o /bin/connCheck.sh
2. Make it executable:
  - chmod +x /bin/connCheck.sh
3. Run the script:
  - connCheck.sh

=======================
Usage
=======================
This script is meant to help troubleshoot connectivity problems. Please run this while the issue is occurring, otherwise, if the problem is not occurring, we will not see the problem.

1. While the problem is occurring, you will need CLI access to the device.
  - SSH or Direct Console are both fine
2. Run the script:
  - [Expert@Host:0]# connCheck.sh

	Note: The output file will be placed into the present working directory.
	
	Ensure you run it from a folder with ample free space.

3. At this time, you can do whatever you need to do to restore services if needed. This can include a reboot or any other kinds fo restarts as needed.

4. Provide the compressed output package to Checkpoint

=======================
Warnings and Details
=======================
This script is provided for debugging purposes only with no warranty, implied or otherwise.

This script is for a Check Point Gaia Gateway ONLY.
  - It has not been tested on anything else.

SecureXL will not be turned off by default. This can be changed by changing 'FWACCEL=false' to 'FWACCEL=true'
  - This script will turn it off and back on again

This script will not gather a CPInfo by default, but will do so at a lower priority if you change 'CPINFO=false' to 'CPINFO=true'
  - This will use all availble CPU, but at a low priority
  - This may cause 100% CPU Usage warnings, but should not affect traffic

Details gathered includes (but not limited to) the following:
  - tcpdump
  - fw monitor
  - fw ctl zdebug drop
  - top
  - free -k
  - cphaprob
  - cpwd_admin list
  - /var/log/messages* files
  - /var/log/routed_messages* files
  - complete connections table dump


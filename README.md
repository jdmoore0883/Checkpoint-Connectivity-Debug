# Checkpoint-Connectivity-Debug
A script to quickly grab connection details and package it all together, so you can go a restart/reboot as needed, and provide the package to Checkpoint TAC

=======================
Installation
=======================
Note: Please be sure to install this script prior to any issues manifesting themselves

1. Download the script to your device:
curl -Lk https://github.com/jdmoore0883/Checkpoint-Connectivity-Debug/raw/master/con_deb.sh -o con_deb.sh
2. Make it executable:
chmod +x con_deb.sh
3. Run the script:
./con_deb.sh

=======================
Usage
=======================
This script is meant to help troubleshoot connectivity problems. Please run 
this while the issue is occurring, otherwise, if the problem is not occurring,
we will not see the problem.

1. While the problem is occurring, you will need CLI access to the device.
	SSH or Direct Console are both fine
2. CD to the folder with the script.
3. Run the script:
[Expert@Host:0]# ./connCheck.sh

Note: The output file will be placed into the present working directory.
	Ensure you run it from a folder with ample free space.

4. Provide the compressed output package to Checkpoint

=======================
Warnings and Details
=======================
This script is provided for debugging purposes only with no warranty, implied or otherwise.

This script is for a Check Point Gaia Gateway ONLY.
	It has not been tested on anything else.

SecureXL will need to be turned off.
	This script will turn it off and back on again

This script will gather a CPInfo at a low priority.
	This will use all availble CPU, but at a low priority
	This may cause 100% CPU Usage warnings, but should not affect traffic

Details gathered includes (but not limited to) the following:
	CPInfo
	tcpdump
	fw monitor
	fw ctl zdebug drop
	top
	free -k
	cphaprob
	cpwd_admin list
 	/var/log/messages* files
	complete connections table dump
	all *.elg debug files

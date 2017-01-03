#! /bin/bash

# Written by: Jon Moore - jdmoore0883@gmail.com
#			- http://jonmoore.duckdns.org
#
# This script is provided for debugging purposes only with no warranty, implied or otherwise.
#
# version 8 - Jan. 3, 2017	- changed 'route' command to 'netstat -nr'
#				- created a function for the detail gathering
#				- changed the detail output format
#				- added a SecureXL re-activation check in the 'Ctrl+c' check
#				- removed the output redirect from the cleanup 'tar' command to allow for errors to the user
#				- added a "debug" output file
# 				- updated some of the true/false logic checks
#				- moved the SecureXL reactiviation to it's own function
#				- added 'fwaccel stats' to the detail gathering
#				- added 'routed_messages*' files to the logs gathered
#				- cleaned up commented code
#				- added a time calculation to see the total time the script took
#				- changed the 'arp' command to 'arp -en'
#				- added 'hostname' to the details gathered
#				- explicitly set the TCPDump snaplength to '68' bytes
#				- set the TCPDump to any interface
#					- added a filter, not net 127.0.0.0/8 (loopback)
#				- set TCPDump to run a a nice level of 5
#				- set TCPDump to rotate the output file at 100MB
#				- list the interfaces tcpdump will gather on
#				- added 'ifconfig' to the details gathered
# version 7 - Nov. 29, 2016	- removed the 'disown' commands
#				- added default action for running a CPInfo and turning off SecureXL
#				- created a "cleanup" function to compress and delete files
#				- created a "kill_caps" function to take care of killing the backgrounded processes
# 				- created a trap to catch a user's Ctrl+c
#				- changed the CPInfo's nice level to 5; 15 and 10 are too low, CPInfo takes too long
#				- added CPInfo progress indicator
#				- changed the working directory to /var/log/tmp/connCheck
#				- changed the compressed file output directory to the user's preset directory
# version 6 - Feb. 24, 2016	- set the CPInfo to run a a nice level of 15 (lower priority)
#				- changed the warning text
#				- changed the zdebug drop to an actual debug with timestamps
#				- changed the netstat to include timestamps
#				- added date/time stamps to command output files
# version 5 - Jan. 11, 2016	- added kernel debugs
# version 4 - May 1, 2015	- added extra screen outputs to remind user to attempt the problem traffic
# version 3 - April 28, 2015	- added usage instructions at the end as comments
# version 2 - March 19, 2015 	- bugfix on the fw monitor syntax
# version 1 - February 13, 2015	- initial release

#DEFAULTS
CPINFO=false	# Do we run a cpinfo?
FWACCEL=false	# Do we turn off SecureXL?

# Set some variables
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
PRESENT_DIRECTORY=$(pwd)
MAIN_DIRECTORY=/var/log/tmp/connCheck
WORKING_DIRECTORY=$MAIN_DIRECTORY/$TIMESTAMP

OUTPUT_ARCHIVE=$PRESENT_DIRECTORY/connCheck_$TIMESTAMP.tgz

CPINFO_OUTPUT=$WORKING_DIRECTORY/cpinfo.out
DEBUG_OUTPUT=$WORKING_DIRECTORY/dbg.txt
SCRIPT_START=$(date +%s.%N)
DATE=$(date)

TCPDUMP_PID=$WORKING_DIRECTORY/dump.pid
MONITOR_PID=$WORKING_DIRECTORY/monitor.pid
CPINFO_PID=$WORKING_DIRECTORY/cpinfo.pid
DROPS_PID=$WORKING_DIRECTORY/drops.pid
NETSTATS_PID=$WORKING_DIRECTORY/netstats.pid

###################
# Cleanup function
###################
function cleanup {
	# Compress the outputs to 1 file
	echo "Compressing all files..."
	cd $WORKING_DIRECTORY
	tar -C $WORKING_DIRECTORY -czf $OUTPUT_ARCHIVE *

	echo "Compression complete!"

	rm -r $WORKING_DIRECTORY
	rm ~/.toprc
	if [ -e ~/.toprc_ORIGINAL ]
	then
		mv ~/.toprc_ORIGINAL ~/.toprc
	fi

	echo ""
	echo ""
	echo "Diags are now complete!"
	echo ""
	echo "Please upload the file:" $OUTPUT_ARCHIVE "to the case."
	echo "Please also update the case with specific details on what addresses and services/ports are affected."
	echo "	Note: More specific details are best. Specific IP Addresses are ideal, though subnets can be just as effective."
	echo ""
}
###################
# Cleanup done
###################

function kill_caps {
	kill `cat $CPINFO_PID` > $DEBUG_OUTPUT
	kill `cat $TCPDUMP_PID` > $DEBUG_OUTPUT
	kill `cat $MONITOR_PID` > $DEBUG_OUTPUT
	kill `cat $DROPS_PID` > $DEBUG_OUTPUT
	kill `cat $NETSTATS_PID` > $DEBUG_OUTPUT 2>&1
	fw ctl debug 0
} > $DEBUG_OUTPUT 2>&1


function SecureXL {
	echo "Checking SecureXL status..."

	if $FWACCEL_REACTIVATE
	then
		echo "SecureXL was deactivated. Turning it back on."
		fwaccel on
		FWACCEL_REACTIVATE=false
	else
		echo "SecureXL was not on to begin with, doing nothing"
	fi
}

function trap_ctrlc {
	# Catch Ctrl+C being pressed
	echo "Ctrl-C caught...ending background process and performing clean up"

	# STOP THE BACKGROUNDED PCAPS
	kill_caps
	# Clean Up
	cleanup
	# SecureXL re-activation check
	SecureXL
	# exit shell script, if omitted, shell script will continue execution
	exit
}

function Details () {
	# funtion to gather details

	if [ -z "$1" ]
	then
		OUT_DIR=$WORKING_DIRECTORY/Details-$(date +"%H-%M-%S")
	else
		OUT_DIR=$WORKING_DIRECTORY/Details-$1
	fi
	
	mkdir -p $OUT_DIR

	echo "Gathering command outputs '"$1"'..."

	echo "*****************************************" >> $OUT_DIR/timestamp-01.txt
	echo "	DATE/TIME STAMP before gathering details" >> $OUT_DIR/timestamp-01.txt
	echo "*****************************************" >> $OUT_DIR/timestamp-01.txt
	date +"%a %b %d %T.%4N %Y" >> $OUT_DIR/timestamp-01.txt

	echo "*****************************************" >> $OUT_DIR/top.txt
	echo "	top -b -n 1" >> $OUT_DIR/top.txt
	echo "*****************************************" >> $OUT_DIR/top.txt
	top -b -n 1 >> $OUT_DIR/top.txt

	echo "*****************************************" >> $OUT_DIR/free_mem.txt
	echo "	free -tk" >> $OUT_DIR/free_mem.txt
	echo "*****************************************" >> $OUT_DIR/free_mem.txt
	free -tk >> $OUT_DIR/free_mem.txt

	echo "*****************************************" >> $OUT_DIR/pstat.txt
	echo "	fw ctl pstat" >> $OUT_DIR/pstat.txt
	echo "*****************************************" >> $OUT_DIR/pstat.txt
	fw ctl pstat >> $OUT_DIR/pstat.txt

	echo "*****************************************" >> $OUT_DIR/routes.txt
	echo "	netstat -nr" >> $OUT_DIR/routes.txt
	echo "*****************************************" >> $OUT_DIR/routes.txt
	netstat -nr >> $OUT_DIR/routes.txt

	echo "*****************************************" >> $OUT_DIR/arp.txt
	echo "	arp -en" >> $OUT_DIR/arp.txt
	echo "*****************************************" >> $OUT_DIR/arp.txt
	arp -en >> $OUT_DIR/arp.txt

	echo "*****************************************" >> $OUT_DIR/cphaprob_stat.txt
	echo "	cphaprob stat" >> $OUT_DIR/cphaprob_stat.txt
	echo "*****************************************" >> $OUT_DIR/cphaprob_stat.txt
	cphaprob stat >> $OUT_DIR/cphaprob_stat.txt

	echo "*****************************************" >> $OUT_DIR/cphaprob_list.txt
	echo "	cphaprob -ia list" >> $OUT_DIR/cphaprob_list.txt
	echo "*****************************************" >> $OUT_DIR/cphaprob_list.txt
	cphaprob -ia list >> $OUT_DIR/cphaprob_list.txt

	echo "*****************************************" >> $OUT_DIR/cphaprob_if.txt
	echo "	cphaprob -a if" >> $OUT_DIR/cphaprob_if.txt
	echo "*****************************************" >> $OUT_DIR/cphaprob_if.txt
	cphaprob -a if >> $OUT_DIR/cphaprob_if.txt

	echo "*****************************************" >> $OUT_DIR/cpwd_admin.txt
	echo "	cpwd_admin list" >> $OUT_DIR/cpwd_admin.txt
	echo "*****************************************" >> $OUT_DIR/cpwd_admin.txt
	cpwd_admin list >> $OUT_DIR/cpwd_admin.txt

	echo "*****************************************" >> $OUT_DIR/fwaccel_stat.txt
	echo "	fwaccel stat" >> $OUT_DIR/fwaccel_stat.txt
	echo "*****************************************" >> $OUT_DIR/fwaccel_stat.txt
	fwaccel stat >> $OUT_DIR/fwaccel_stat.txt

	echo "*****************************************" >> $OUT_DIR/fwaccel_stats.txt
	echo "	fwaccel stats" >> $OUT_DIR/fwaccel_stats.txt
	echo "*****************************************" >> $OUT_DIR/fwaccel_stats.txt
	fwaccel stats >> $OUT_DIR/fwaccel_stats.txt

	echo "*****************************************" >> $OUT_DIR/fwaccel_stats-s.txt
	echo "	fwaccel stats -s" >> $OUT_DIR/fwaccel_stats-s.txt
	echo "*****************************************" >> $OUT_DIR/fwaccel_stats-s.txt
	fwaccel stats -s >> $OUT_DIR/fwaccel_stats-s.txt

	echo "*****************************************" >> $OUT_DIR/ifconfig.txt
	echo "	ifconfig" >> $OUT_DIR/ifconfig.txt
	echo "*****************************************" >> $OUT_DIR/ifconfig.txt
	ifconfig >> $OUT_DIR/ifconfig.txt

#	TEMPLATE for additional details
#	echo "*****************************************" >> $OUT_DIR/file.txt
#	echo "	" >> $OUT_DIR/file.txt
#	echo "*****************************************" >> $OUT_DIR/file.txt
#	>> $OUT_DIR/file.txt

	fw tab -t connections -u > $OUT_DIR/connTable.txt

	echo "*****************************************" >> $OUT_DIR/timestamp-02.txt
	echo "	DATE/TIME STAMP after gathering details" >> $OUT_DIR/timestamp-02.txt
	echo "*****************************************" >> $OUT_DIR/timestamp-02.txt
	date +"%a %b %d %T.%4N %Y" >> $OUT_DIR/timestamp-02.txt

	echo "Outputs gathered!"

}

###################
# MAIN START
###################
trap "trap_ctrlc" 2
# Check for Admin/root privilges
if [ "`id -u`" != "0" ]
then
	echo "You need Admin/Root privileges!"
	exit
fi

clear

# Advise what the script will gather
#	and that it is for Gaia only
echo ""
echo "This diagnostic script will gather several outputs and files."
echo "This script is meant to help troubleshoot connectivity problems,"
echo "	and is provided for debugging purposes only with no warranty, implied or otherwise."
echo "Please run this while the issue is occurring."
echo "	Otherwise, if the problem is not occurring, we will not see the problem."
echo "Details gathered includes (but not limited to) the following:"
if $CPINFO
then
	echo "	CPInfo"
fi
echo "	tcpdump"
echo "	ifconfig"
echo "	fw monitor"
echo "	fw ctl zdebug drop"
echo "	top"
echo "	free -k"
echo "	cphaprob"
echo "	cpwd_admin list"
echo "	/var/log/messages* files"
echo "	complete connections table dump"
#echo "	all *.elg debug files"
echo "For complete details, please take a look at the compressed archive afterwards."
echo ""
echo "*********** WARNING ***********"
echo "*********** WARNING ***********"
echo ""
echo "This script is for a Check Point Gaia Gateway ONLY."
echo "It has not been tested on anything else."
echo ""

# Do we turn SecureXL on and off again?
if $FWACCEL
then
	echo "SecureXL will need to be turned off."
	echo "	(This script will turn it off and back on again)"
	echo ""
fi

# Do we run a CPInfo?
if $CPINFO
then
	echo "This script will gather a CPInfo at a low priority."
	echo "	(This will use all availble CPU, but at a low priority)"
	echo "	(This may cause 100% CPU Usage warnings)"
	echo "	(But should not affect traffic)"
	echo ""
fi

echo "*********** WARNING ***********"
echo "*********** WARNING ***********"
echo ""

# Offer the option to exit the script
read -p "Do you wish to proceed? " -n 1 -r
echo ""	# (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
   exit 1
fi

# Ensure the test directory exists
if [ ! -e $WORKING_DIRECTORY ]
then	
	mkdir -p $WORKING_DIRECTORY
fi

echo $DATE > $WORKING_DIRECTORY/TimeStamp.txt
hostname > $WORKING_DIRECTORY/hostname.txt

# create a .toprc for top outputs
# if one exists already, back it up
if [ -e ~/.toprc ]
then
	cp ~/.toprc ~/.toprc_ORIGINAL
fi
echo "RCfile for "top with windows"
Id:a, Mode_altscr=0, Mode_irixps=1, Delay_time=3.000, Curwin=0
Def	fieldscur=AEHIOQTWKNMbcdfgjplrsuvyzX
	winflags=30009, sortindx=10, maxtasks=0
	summclr=1, msgsclr=1, headclr=3, taskclr=1
Job	fieldscur=ABcefgjlrstuvyzMKNHIWOPQDX
	winflags=62777, sortindx=0, maxtasks=0
	summclr=6, msgsclr=6, headclr=7, taskclr=6
Mem	fieldscur=ANOPQRSTUVbcdefgjlmyzWHIKX
	winflags=62777, sortindx=13, maxtasks=0
	summclr=5, msgsclr=5, headclr=4, taskclr=5
Usr	fieldscur=ABDECGfhijlopqrstuvyzMKNWX
	winflags=62777, sortindx=4, maxtasks=0
	summclr=3, msgsclr=3, headclr=2, taskclr=3
" > ~/.toprc

###################
# Gather FIRST_SET
###################

Details 01

###################
# FIRST_SET Gathered
###################


###################
# Check SecureXL
#	Do we need to turn it off?
###################
if $FWACCEL
then
	echo "Check SecureXL Status..."

	FWACCEL_STATUS=$(fwaccel stat | head -n 1)

	FWACCEL_ON="Accelerator Status : on"
	FWACCEL_OFF="Accelerator Status : off"

	FWACCEL_REACTIVATE=false

	if [ "$FWACCEL_STATUS" == "$FWACCEL_ON" ]
	then
	# SecureXL is on
		echo "SecureXL is turned on. Turning it off for packet captures."
		echo "	SecureXL will be turned back on when script is completed."
		fwaccel off
		FWACCEL_REACTIVATE=true
	else
	# SecureXL is off
		echo "SecureXL is not turned on."
	fi
fi
###################
# SecureXL Check complete
###################


###################
# Start the packet captures
###################
echo "Starting Packet Captures..."

# List the interfaces tcpdump will gather on
tcpdump -D > $WORKING_DIRECTORY/dump_interfaces.txt
# Start a TCPDump
nice -n 5 tcpdump -enni any not net 127.0.0.0/8 -s 68 -Z $USER -C 100 -w $WORKING_DIRECTORY/dump.cap > $DEBUG_OUTPUT 2>&1 &
PID=$!
echo $PID > $TCPDUMP_PID

# Start an FWMonitor
fw monitor -i -o $WORKING_DIRECTORY/monitor.cap > $DEBUG_OUTPUT 2>&1 &
PID=$!
echo $PID > $MONITOR_PID

# start a zdebug drop
#fw ctl zdebug drop > $WORKING_DIRECTORY/drops.txt &
fw ctl debug 0
fw ctl debug -buf 32000
fw ctl debug + drop
fw ctl kdebug –T -f > $WORKING_DIRECTORY/drops.txt &
PID=$!
echo $PID > $DROPS_PID

# start netstats
touch $WORKING_DIRECTORY/netstats.txt
while true; do date +"%D-%T.%4N" >> $WORKING_DIRECTORY/netstats.txt; netstat -i >> $WORKING_DIRECTORY/netstats.txt; echo "" >> $WORKING_DIRECTORY/netstats.txt; sleep 1; done &
PID=$!
echo $PID > $NETSTATS_PID

###################
# Start a CPInfo
###################
if $CPINFO
then
	echo "Starting CPInfo..."
	echo "*********** WARNING ***********"
	echo "*********** WARNING ***********"
	echo "Ensure the relevant problem traffic is being attempted at this time!"
	echo "*********** WARNING ***********"
	echo "*********** WARNING ***********"
	yes no | nice -n 5 cpinfo -z -o $WORKING_DIRECTORY/cpinfo > $CPINFO_OUTPUT 2>&1 &
	#dd if=/dev/urandom of=$WORKING_DIRECTORY/cpinfo count=1 bs=64M > $CPINFO_OUTPUT 2>&1 &	#testing command to create a test CPInfo file a bit more quickly
	PID=$!
	echo $PID > $CPINFO_PID
fi

###################
# Gather additional files
###################
echo "Gathering Log Files..."

# messages files
mkdir $WORKING_DIRECTORY/messages
cp /var/log/messages* $WORKING_DIRECTORY/messages > $DEBUG_OUTPUT 2>&1

# routed_messages
mkdir $WORKING_DIRECTORY/routed_messages
cp /var/log/routed_messages* $WORKING_DIRECTORY/routed_messages > $DEBUG_OUTPUT 2>&1

# ALL *.elg* files
#mkdir $WORKING_DIRECTORY/elg_files
#find / ! -path "/home/*" ! -path $WORKING_DIRECTORY/ -name *.elg* -exec cp '{}' $WORKING_DIRECTORY/elg_files/ \; > $DEBUG_OUTPUT 2>&1

echo "Log files gathered!"


###################
# Watch the CPINFO process until completed
###################
# $WORKING_DIRECTORY

# Gather top outputs during the CPInfo

echo "******************************************************************************************************" > $WORKING_DIRECTORY/top_during.txt
date >> $WORKING_DIRECTORY/top_during.txt
echo "******************************************************************************************************" >> $WORKING_DIRECTORY/top_during.txt
top -b -n 1 >> $WORKING_DIRECTORY/top_during.txt

# If we run a CPInfo, watch the process until complete
if $CPINFO
then
	ACTIVE=true

	while $ACTIVE
	do
		sleep 5
	
		if ps `cat $CPINFO_PID` > /dev/null
		then
			# This means the CPInfo is still running
			echo "CPInfo still running..."
			echo "*********** WARNING ***********"
			echo "*********** WARNING ***********"
			echo "Ensure the relevant problem traffic is being attempted at this time!"
			echo "*********** WARNING ***********"
			echo "*********** WARNING ***********"
			# gather another top output
			echo "******************************************************************************************************" >> $WORKING_DIRECTORY/top_during.txt
			date >> $WORKING_DIRECTORY/top_during.txt
			echo "******************************************************************************************************" >> $WORKING_DIRECTORY/top_during.txt
			echo "CPInfo status:"
			tail -n 1 $CPINFO_OUTPUT
			echo ""
			top -b -n 1 >> $WORKING_DIRECTORY/top_during.txt

		else
			# CPInfo has Stopped
			echo "CPInfo complete!"
			ACTIVE=false
			#rm $CPINFO_PID
		fi
	
	done
# CPInfo done
# If NO CPInfo, then we wait for user input
else
	while true
	do
		read -t 5 -n 1
		if [ $? = 0 ]
		then
			break
		else
			#echo "Packet Captures running, waiting for Ctrl+c to end..."
			echo "*********** WARNING ***********"
			echo "*********** WARNING ***********"
			echo "Ensure the relevant problem traffic is being attempted at this time!"
			echo "*********** WARNING ***********"
			echo "*********** WARNING ***********"
			# gather another top output
			echo "******************************************************************************************************" >> $WORKING_DIRECTORY/top_during.txt
			date >> $WORKING_DIRECTORY/top_during.txt
			echo "******************************************************************************************************" >> $WORKING_DIRECTORY/top_during.txt
			top -b -n 1 >> $WORKING_DIRECTORY/top_during.txt

			echo "Press any key to stop the packet captures"
		fi
	done
fi



# Kill all captures
kill_caps

echo "Packet captures done!"

###################
# SecureXL Check
###################

SecureXL

###################
# SecureXL Check complete
###################

###################
# Gather AFTER_SET
###################

Details 02

###################
# AFTER_SET Gathered
###################

SCRIPT_END=$(date +%s.%N)
DIFF=$(echo "$SCRIPT_END - $SCRIPT_START" | bc)
echo "Total time taken for script (in seconds):
$DIFF" > $WORKING_DIRECTORY/script_time.txt

###################
# Cleanup
###################
cleanup
###################
# Cleanup done
###################

echo "Total time taken for script (in seconds):
	Before compression:	$DIFF"

SCRIPT_END=$(date +%s.%N)
DIFF=$(echo "$SCRIPT_END - $SCRIPT_START" | bc)
echo "	After compression:	$DIFF"

#############################
# connCheck.sh USAGE DETAILS
#############################
# 1. Get the script to the appliance.
# 2. Ensure it is Linux formatted and executable:
#	dos2unix connCheck.sh;chmod +x connCheck.sh
# 3. Run the script:
# 	connCheck.sh
#############################

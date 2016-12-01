#! /bin/bash

# Written by: Jon Moore - jdmoore0883@gmail.com
#
# This script is provided for debugging purposes only with no warranty, implied or otherwise.
#
# version 7 - Nov. 29, 2016	- removed the 'disown' commands
#				- added default action for running a CPInfo and turning off SecureXL
#				- created a "cleanup" function to compress and delete files
#				- created a "kill_caps" function to take care of killing the backgrounded processes
# 				- created a trap to catch a user's Ctrl+c
#				- changed the CPInfo's nice level to 5; 15 and 10 are too low, CPInfo takes too long
#				- added CPInfo progress indicator
#				- changed the working directory to /var/log/tmp/connCheck
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
TCPDUMP_PID=$WORKING_DIRECTORY/dump.pid
MONITOR_PID=$WORKING_DIRECTORY/monitor.pid
CPINFO_PID=$WORKING_DIRECTORY/cpinfo.pid
DROPS_PID=$WORKING_DIRECTORY/drops.pid
NETSTATS_PID=$WORKING_DIRECTORY/netstats.pid

OUTPUT_ARCHIVE=$PRESENT_DIRECTORY/connCheck_$TIMESTAMP.tgz

FIRST_SET=$WORKING_DIRECTORY/before.txt
AFTER_SET=$WORKING_DIRECTORY/after.txt
CPINFO_OUTPUT=$WORKING_DIRECTORY/cpinfo.out

###################
# Cleanup function
###################
function cleanup {
	# Compress the outputs to 1 file
	echo "Compressing all files..."
	cd $WORKING_DIRECTORY
	tar -C $WORKING_DIRECTORY -czf $OUTPUT_ARCHIVE * > /dev/null 2>&1
	# Wait for the compression to complete
	#wait
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
	echo "Checking SecureXL status..."
	
	if [ "$FWACCEL_REACTIVATE" == "true" ]
	then
		echo "SecureXL was deactivated. Turning it back on."
		fwaccel on
		FWACCEL_REACTIVATE="false"
	else
		echo "SecureXL was not on to begin with, doing nothing"
	fi

	kill `cat $CPINFO_PID` > /dev/null
	kill `cat $TCPDUMP_PID` > /dev/null
	kill `cat $MONITOR_PID` > /dev/null
	kill `cat $DROPS_PID` > /dev/null
	kill `cat $NETSTATS_PID` > /dev/null 2>&1
	#wait $NETSTATS_PID > /dev/null 2>&1
	#rm $WORKING_DIRECTORY/*.pid
	fw ctl debug 0

} > /dev/null 2>&1

function trap_ctrlc {
	# Catch Ctrl+C being pressed
	echo "Ctrl-C caught...ending background process and performing clean up"

	### STOP THE BACKGROUNDED PCAPS
	kill_caps

	cleanup
	# exit shell script
	# if omitted, shell script will continue execution
	exit
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
echo "	fw monitor"
echo "	fw ctl zdebug drop"
echo "	top"
echo "	free -k"
echo "	cphaprob"
echo "	cpwd_admin list"
echo "	/var/log/messages* files"
echo "	complete connections table dump"
echo "	all *.elg debug files"
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

echo $TIMESTAMP > $WORKING_DIRECTORY/TimeStamp.txt

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
#	$FIRST_SET

echo "Gathering command outputs..."

echo "Command outputs prior to anything." > $FIRST_SET
echo "" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
echo "	DATE/TIME STAMP" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
date +"%a %b %d %T.%4N %Y" >> $FIRST_SET
echo "" >> $FIRST_SET

echo "" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
echo "	top -b -n 1" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
top -b -n 1 >> $FIRST_SET
echo "" >> $FIRST_SET

echo "*****************************************" >> $FIRST_SET
echo "	free -tk" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
free -tk >> $FIRST_SET
echo "" >> $FIRST_SET

echo "*****************************************" >> $FIRST_SET
echo "	fw ctl pstat" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
fw ctl pstat >> $FIRST_SET
echo "" >> $FIRST_SET

echo "*****************************************" >> $FIRST_SET
echo "	route" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
route >> $FIRST_SET
echo "" >> $FIRST_SET

echo "*****************************************" >> $FIRST_SET
echo "	arp" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
arp >> $FIRST_SET
echo "" >> $FIRST_SET

echo "*****************************************" >> $FIRST_SET
echo "	cphaprob stat" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
cphaprob stat >> $FIRST_SET
echo "" >> $FIRST_SET

echo "*****************************************" >> $FIRST_SET
echo "	cphaprob -ia list" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
cphaprob -ia list >> $FIRST_SET
echo "" >> $FIRST_SET

echo "*****************************************" >> $FIRST_SET
echo "	cphaprob -a if" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
cphaprob -a if >> $FIRST_SET
echo "" >> $FIRST_SET

echo "*****************************************" >> $FIRST_SET
echo "	cpwd_admin list" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
cpwd_admin list >> $FIRST_SET
echo "" >> $FIRST_SET

echo "*****************************************" >> $FIRST_SET
echo "	fwaccel stat" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
fwaccel stat >> $FIRST_SET
echo "" >> $FIRST_SET

echo "*****************************************" >> $FIRST_SET
echo "	" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
echo "" >> $FIRST_SET

echo "" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
echo "	DATE/TIME STAMP" >> $FIRST_SET
echo "*****************************************" >> $FIRST_SET
date +"%a %b %d %T.%4N %Y" >> $FIRST_SET
echo "" >> $FIRST_SET

fw tab -t connections -u > $WORKING_DIRECTORY/connTable_before.txt

echo "Outputs gathered!"

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

	FWACCEL_REACTIVATE="false"

	if [ "$FWACCEL_STATUS" == "$FWACCEL_ON" ]
	then
	# SecureXL is on
		echo "SecureXL is turned on. Turning it off for packet captures."
		echo "	SecureXL will be turned back on when script is completed."
		fwaccel off
		FWACCEL_REACTIVATE="true"
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

# Start a TCPDump
tcpdump -enn -w $WORKING_DIRECTORY/dump.cap > /dev/null 2>&1 &
PID=$!
echo $PID > $TCPDUMP_PID

# Start an FWMonitor
fw monitor -i -o $WORKING_DIRECTORY/monitor.cap > /dev/null 2>&1 &
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
#netstat -in 1 > $WORKING_DIRECTORY/netstats.txt &
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
	PID=$!
	echo $PID > $CPINFO_PID
fi

###################
# Gather additional files
###################
echo "Gathering Log Files..."

# messages files
mkdir $WORKING_DIRECTORY/messages
cp /var/log/messages* $WORKING_DIRECTORY/messages > /dev/null 2>&1

# ALL *.elg* files
#mkdir $WORKING_DIRECTORY/elg_files
#find / ! -path "/home/*" ! -path $WORKING_DIRECTORY/ -name *.elg* -exec cp '{}' $WORKING_DIRECTORY/elg_files/ \; > /dev/null 2>&1 &

# wait for the commands to complete
#wait
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
	ACTIVE="true"

	while [ $ACTIVE == "true" ]
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
			ACTIVE="false"
			#rm $CPINFO_PID
		fi
	
	done
# CPInfo done
# If NO CPInfo, then we wait for user input
else
	while true
	do
#		echo "*********** WARNING ***********"
#		echo "*********** WARNING ***********"
#		echo "Ensure the relevant problem traffic is being attempted at this time!"
#		echo "*********** WARNING ***********"
#		echo "*********** WARNING ***********"
#		# gather another top output
#		echo "******************************************************************************************************" >> $WORKING_DIRECTORY/top_during.txt
#		date >> $WORKING_DIRECTORY/top_during.txt
#		echo "******************************************************************************************************" >> $WORKING_DIRECTORY/top_during.txt
#		top -b -n 1 >> $WORKING_DIRECTORY/top_during.txt

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

echo "Checking SecureXL status..."
	
if [ "$FWACCEL_REACTIVATE" == "true" ]
then
	echo "SecureXL was deactivated. Turning it back on."
	fwaccel on
	FWACCEL_REACTIVATE="false"
else
	echo "SecureXL was not on to begin with, doing nothing"
fi

###################
# SecureXL Check complete
###################

# make sure all above is complete before proceeding
#wait

###################
# Gather AFTER_SET
###################
#	$AFTER_SET

echo "Gathering command outputs..."

echo "Command outputs after all is done." > $AFTER_SET
echo "" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
echo "	DATE/TIME STAMP" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
date +"%a %b %d %T.%4N %Y" >> $AFTER_SET
echo "" >> $AFTER_SET

echo "" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
echo "	top -b -n 1" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
top -b -n 1 >> $AFTER_SET
echo "" >> $AFTER_SET

echo "*****************************************" >> $AFTER_SET
echo "	free -tk" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
free -tk >> $AFTER_SET
echo "" >> $AFTER_SET

echo "*****************************************" >> $AFTER_SET
echo "	fw ctl pstat" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
fw ctl pstat >> $AFTER_SET
echo "" >> $AFTER_SET

echo "*****************************************" >> $AFTER_SET
echo "	route" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
route >> $AFTER_SET
echo "" >> $AFTER_SET

echo "*****************************************" >> $AFTER_SET
echo "	arp" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
arp >> $AFTER_SET
echo "" >> $AFTER_SET

echo "*****************************************" >> $AFTER_SET
echo "	cphaprob stat" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
cphaprob stat >> $AFTER_SET
echo "" >> $AFTER_SET

echo "*****************************************" >> $AFTER_SET
echo "	cphaprob -ia list" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
cphaprob -ia list >> $AFTER_SET
echo "" >> $AFTER_SET

echo "*****************************************" >> $AFTER_SET
echo "	cphaprob -a if" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
cphaprob -a if >> $AFTER_SET
echo "" >> $AFTER_SET

echo "*****************************************" >> $AFTER_SET
echo "	cpwd_admin list" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
cpwd_admin list >> $AFTER_SET
echo "" >> $AFTER_SET

echo "*****************************************" >> $AFTER_SET
echo "	fwaccel stat" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
fwaccel stat >> $AFTER_SET
echo "" >> $AFTER_SET

echo "*****************************************" >> $AFTER_SET
echo "	" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
echo "" >> $AFTER_SET

echo "" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
echo "	DATE/TIME STAMP" >> $AFTER_SET
echo "*****************************************" >> $AFTER_SET
date +"%a %b %d %T.%4N %Y" >> $AFTER_SET
echo "" >> $AFTER_SET

fw tab -t connections -u > $WORKING_DIRECTORY/connTable_after.txt

echo "Outputs gathered!"

###################
# AFTER_SET Gathered
###################


###################
# Cleanup
###################
cleanup
###################
# Cleanup done
###################

#############################
# connCheck.sh USAGE DETAILS
#############################
# 1. Get the script to the appliance.
# 2. Ensure it is Linux formatted and executable:
#	dos2unix connCheck.sh;chmod +x connCheck.sh
# 3. Run the script:
# 	./connCheck.sh
# 4. Follow on-screen prompts.
#############################

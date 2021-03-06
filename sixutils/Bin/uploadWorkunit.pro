#!/bin/sh
#
# Author: Jakob Pedersen (jakob@stonefire.dk)
#
# This script will queue a sixtrack workunit for 
# submission to BOINC.
# The script expects to find the fort.2, fort.3, fort.8
# and fort.16 files in the 'fileDir'.
# If this is not the case it will complain.
# The script contains quite a bit of variables that should
# be set to appropriate values before executing the script.

# Directory on AFS where input files are copied and picked up
# by a script running on the BOINC server.
# See later once we have checked the parameters for afsDir

# An estimate of the number of floating point operations required 
# to complete the workunit. Used by the scheduling server to estimate
# the time required by the client to process the workunit.
# This is now passed as Arg 6 from dot_boinc

# An upper bound on the number of floating point operations required
# to complete the workunit. If exceeded the workunit will be aborted.
# Now computed from the fpopsEstimate

# An upper bound on the amount of memory required to process the workunit. 
# The workunit will only be sent to clients with at least this much available
# RAM. If exceeded the workunit will be aborted. Measured in bytes.
memBound=100000000

# An upper bound on the amount of disk space required to process the workunit. 
# The workunit will only be sent to clients with at least this much available
# disk space. If exceeded the workunit will be aborted. Measured in bytes.
# diskBound=200,000,000  ~200MB
diskBound=200000000

# An upper bound on the time (in seconds) between sending a result to a client 
# and receiving a reply. If the client doesn't respond within this interval, 
# the server 'gives up' on the result and generates a new result, to be 
# assigned to another client. Don't set this too low. 
# 20 times the "normal" execution time will probably be a good value.
delayBound=2400000
#about 30 days

# The number of redundant calculations. Set to two or more to achieve redudancy.
redundancy=2

# The number of copies of the workunit to issue to clients. Must be at least the
# number of redundant calculations or higher if a loss of results is expected
# or if the result should to be obtained fast.
copies=2

# The number of errors from clients before the workunit is declared to have
# an error.
errors=5

# The total number of clients to issue the workunit to before it is declared
# to have an error.
numIssues=5

# The total number of returned results without a concensus is found before the
# workunit is declared to have an error.
resultsWithoutConcensus=3
# Following statement is redundant!
#afsDir=/afs/cern.ch/project/lhcnap/napscratch2/mcintosh/boinc
# Did we get all the arguments?
if test $# -ne 7
then
  echo "Usage: $0 TASKNAME TASKGROUP PROGRAMID FILEDIR WUNUMBER FPOPSESTIMATE SIXDESKBOINCDIR"
  exit 1
fi
afsDir=$7/work
echo "uploadWorkunit using $afsDir"
# The four arguments TASKNAME, TASKGROUP, PROGRAMID and WUNUMBER
# must not contain more than 251 characters alltogether or they will
# not fit in the assigned field in the boinc database.

fileDir=$4

workunitName=$1\_$2\_$3\_$5

# Getting the fpops estimate and multiplying it with 10 to get the bound.
# Multiply by 4 for the moment but watch for complaints!
# Try six for pentium 4
fourtimes=$6
fourtimes=`expr $fourtimes \* 6`
#fpopsEstimate=$6
fpopsEstimate=$fourtimes
fpopsBound=`expr $fpopsEstimate \* 10`

workingDir=`pwd`


if [ ! -d "$fileDir" ]
  then
    echo "$fileDir is NOT a directory!"
    echo "Exiting..."
    exit 2
fi

if [ ! -s "$fileDir/fort.2" ]
  then
    echo "The file $fileDir/fort.2 does not exist or it is empty!"
    echo "Exiting.."
    exit 3
fi

if [ ! -s "$fileDir/fort.3" ]
  then
    echo "The file $fileDir/fort.3 does not exist or it is empty!"
    echo "Exiting.."
    exit 3
fi

if [ ! -f "$fileDir/fort.8" ]
  then
    echo "The file $fileDir/fort.8 does not exist!"
    echo "Exiting.."
    exit 3
fi

if [ ! -f "$fileDir/fort.16" ]
  then
    echo "The file $fileDir/fort.16 does not exist!"
    echo "Exiting.."
    exit 3
fi


# Zipping files

cd $fileDir

if [ $? -ne 0 ]
  then
    echo "Couldn't cd to $fileDir!"
    echo "Make sure you have access rights!"
    echo "Exiting.."
    exit 4
fi

zip $workunitName.zip fort.2 fort.3 fort.8 fort.16 >/dev/null 2>&1

if [ $? -ne 0 ]
  then
    echo "Zipping the input files failed!"
    echo "Make sure you have rights to write a file in $fileDir!" 
    rm -rf $workunitName.zip >/dev/null 2>&1
    cd $workingDir
    echo "Exiting.."
    exit 4
fi

cd $workingDir


# Moving file to AFS

mv -f $fileDir/$workunitName.zip $afsDir/. >/dev/null 2>&1

if [ $? -ne 0 ]
  then
    echo "AFS copying failed!"
    echo "Make sure you have the right AFS directory, and actual access rights!"
    echo "Exiting.."
    rm -rf $fileDir/$workunitName.zip >/dev/null 2>&1
    exit 4
fi

# Creating the workunit description file
echo "$workunitName
$fpopsEstimate 
$fpopsBound
$memBound
$diskBound
$delayBound
$redundancy
$copies
$errors
$numIssues
$resultsWithoutConcensus" > $afsDir/$LOGNAME"_"$$.temp

if [ $? -ne 0 ]
  then
    echo "Creation of description file failed!"
    echo "Make sure you have the right AFS directory, and actual access rights!"
    echo "You might have orphan files in your AFS directory, that needs manual deletion."
    echo "Exiting.."
    exit 5
fi


# To avoid using locks this little trick is used.

mv $afsDir/$LOGNAME"_"$$.temp $afsDir/$workunitName.desc 

if [ $? -ne 0 ]
  then
    echo "Renaming of description files failed!"
    echo "Make sure you have the right AFS directory, and actual access rights!"
    echo "You might have orphan files in your AFS directory, that needs manual deletion."
    echo "Exiting.."
    exit 6
fi

echo "Workunit \"$workunitName\" has been succesfully queued for submission."
exit 0

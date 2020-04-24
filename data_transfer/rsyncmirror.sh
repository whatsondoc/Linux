#!/bin/bash

#############################################################################################
#                                                                                           #
# A DATA MIGRATION SCRIPT USING RSYNC FOR LINUX                                             #
# Author: Ben H. Watson                                                                     #
# Twitter: @WhatsOnStorage                                                                  #
# Blog: http://whatsonstorage.azurewebsites.net                                             #
# Date crafted: June 2014                                                                  #
#                                                                                           #
# Please feel free to use, share, edit etc. this script, all feedback and callouts are      #
# appreciated!                                                                              #
#                                                                                           #
#############################################################################################


## Let's set some variables:

/bin/echo "

The purpose of this script is to make the process of Rsync-ing data between two directories a little easier. As Rsync has got a whole bunch of parameters, please feel free to edit the script as you see fit prior to running.

So, first things first, let's set a few basic variables."

read -p "

Please specify the full path for our LOG FILE: " ourlog

/bin/echo "

#########################################################################
#                                                                       #
#             A DATA MIGRATION SCRIPT USING RSYNC FOR LINUX             #
#                     `/bin/date`             #
#                                                                       #
#                Author: Ben H. Watson (@WhatsOnStorage)                #
#           Blog Site: http://whatsonstorage.azurewebsites.net          #
#########################################################################


Beginning of the RsyncMirror script, which we are invoking at `date +%d-%m-%y---//---%H-%M-%S`" >> $ourlog

## Our operational variables:



# Directories for Rsync to work with:

/bin/echo "

We'll now set the source & target directories. Consider whether you need/want trailing slashes on the path names.
"

read -p "
Which directory has the source data that we want to migrate? Please provide the full path name: " sourcedir

read -p "
Which directory would you like to migrate the data to? Again, please provide the full path name: " targetdir
# Do you need/want a trailing slash?

# Parameters we will pass to Rsync:

/bin/echo "Now let's look at passing some of the more popular parameters to the script to use for the migration process. Please respond to the following prompts with either 'Yes' or 'No'.
"

read -p "Archive Mode: " ArchiveMode
case $ArchiveMode in
	YES|YEs|Yes|YeS|yES|yeS|YE|Y|Ye|yE|y|yEs|ye) ArchiveMode="yes" ;;
	NO|N|No|n|nO) ArchiveMode="no" ;;
esac
read -p "Preserve Executability of migrated files: " PreserveExecutability
case $PreserveExecutability in
	YES|YEs|Yes|YeS|yES|yeS|YE|Y|Ye|yE|y|yEs|ye) PreserveExecutability="yes" ;;
	NO|N|No|n|nO) PreserveExecutability="no" ;;
esac
read -p "Handle Sparse Files (well): " HandleSparseFiles
case $HandleSparseFiles in
	YES|YEs|Yes|YeS|yES|yeS|YE|Y|Ye|yE|y|yEs|ye) HandleSparseFiles="yes" ;;
	NO|N|No|n|nO) HandleSparseFiles="no" ;;
esac
read -p "True mirror mode; deletes on the source are sync'd to the target: " IncludeSourceDeletes
case $IncludeSourceDeletes in
	YES|YEs|Yes|YeS|yES|yeS|YE|Y|Ye|yE|y|yEs|ye) IncludeSourceDeletes="yes" ;;
	NO|N|No|n|nO) IncludeSourceDeletes="no" ;;
esac
read -p "Shall we skip transfer of files based on checksum? " SkipOnChecksum
case $SkipOnChecksum in
	YES|YEs|Yes|YeS|yES|yeS|YE|Y|Ye|yE|y|yEs|ye) SkipOnChecksum="yes" ;;
	NO|N|No|n|nO) SkipOnChecksum="no" ;;
esac

# Recommended...
/bin/echo "

Lastly, some recommended parameters. Again, please enter 'Yes' or 'No' to specify.
"
read -p "Progress updates for the Rsync migration: " Progress
case $Progress in
	YES|YEs|Yes|YeS|yES|yeS|YE|Y|Ye|yE|y|yEs|ye) Progress="yes" ;;
	NO|N|No|n|nO) Progress="no" ;;
esac
read -p "Verbose output from Rysnc: " VeryVerbose
case $VeryVerbose in
	YES|YEs|Yes|YeS|yES|yeS|YE|Y|Ye|yE|y|yEs|ye) VeryVerbose="yes" ;;
	NO|N|No|n|nO) VeryVerbose="no" ;;
esac
read -p "Human Readable format: " HumanReadable
case $HumanReadable in
	YES|YEs|Yes|YeS|yES|yeS|YE|Y|Ye|yE|y|yEs|ye) HumanReadable="yes" ;;
	NO|N|No|n|nO) HumanReadable="no" ;;
esac


# Writing the variables we set into our log file;
/bin/echo "
Log file: $ourlog

Source directory: $sourcedir
Target directory: $targetdir

VeryVerbose: $VeryVerbose
ArchiveMode: $ArchiveMode
HumanReadable: $HumanReadable
PreserveExecutability: $PreserveExecutability
HandleSparseFiles: $HandleSparseFiles
IncludeSourceDeletes: $IncludeSourceDeletes
SkipOnChecksum: $SkipOnChecksum
" >> $ourlog

## Now onto the heavylifting! Firstly though, let's check whether we have Rsync:

packs="rsync"

if rpm -qa | grep $packs >> $ourlog
then 
	/binecho "We have Rsync installed already - this is a good start."
	/bin/echo "We have Rsync installed already - this is a good start." >> $ourlog
else 
	/bin/echo "We will install Rsync via our friend Yellowdog." >> $ourlog
	yum install $packs -y >> $ourlog
fi

## Good - job done. Now, let's adjust the variables based on our user input:
 	
if	[[ $VeryVerbose = "yes" ]] ; then VeryVerbose="-vv"
elif	[[ $VeryVerbose = "no" ]] ; then VeryVerbose="" ; fi
if	[[ $ArchiveMode = "yes" ]] ; then ArchiveMode="-a"
elif	[[ $ArchiveMode = "no" ]] ; then ArchiveMode="" ; fi			
if	[[ $HumanReadable = "yes" ]] ; then HumanReadable="-h"
elif 	[[ $HumanReadable = "no" ]] ; then HumanReadable="" ; fi
if	[[ $PreserveExecutability = "yes" ]] ; then PreserveExecutability="-E"
elif 	[[ $PreserveExecutability = "no" ]] ; then PreserveExecutability="" ; fi
if	[[ $HandleSparseFiles = "yes" ]] ; then HandleSparseFiles="-S"
elif 	[[ $HandleSparseFiles = "no" ]] ; then HandleSparseFiles="" ; fi
if	[[ $IncludeSourceDeletes = "yes" ]] ; then IncludeSourceDeletes="--delete"
elif	[[ $IncludeSourceDeletes = "no" ]] ; then IncludeSourceDeletes="" ; fi
if	[[ $SkipOnChecksum = "yes" ]] ; then SkipOnChecksum="-c"
elif	[[ $SkipOnChecksum = "no" ]] ; then SkipOnChecksum="" ; fi
if	[[ $Progress = "yes" ]] ; then Progress="--progress"
elif	[[ $Progress = "no" ]] ; then Progress="" ; fi

/bin/echo "Post variable resetting, for actual Rsync values:

VeryVerbose: $VeryVerbose
ArchiveMode: $ArchiveMode
HumandReadable: $HumanReadable
PreserveExecutability: $PreserveExecutability
HandleSparseFiles: $HandleSparseFiles
IncludeSourceDeletes: $IncludeSourceDeletes
SkipOnChecksum: $SkipOnChecksum
Progress: $Progress
" >> $ourlog

/bin/echo "
You may wish to parse the log file (if you have opted for one) for progress detail
"

## And Rsync execution given our specified parameters:

/bin/echo "The command we are executing is:" >> $ourlog
/bin/echo "rsync $VeryVerbose $ArchiveMode $HumanReadable $PreserveExecutability $HandleSparseFiles $IncludeSourceDeletes $SkipOnChecksum $Progress $sourcedir $targetdir >> $ourlog
" >> $ourlog

/usr/bin/rsync $VeryVerbose $ArchiveMode $HumanReadable $PreserveExecutability $HandleSparseFiles $IncludeSourceDeletes $SkipOnChecksum --progress $sourcedir $targetdir >> $ourlog

## For the benefit of the log, we're listing the contents of the directories:

/bin/echo "" >> $ourlog
/bin/echo "Source Directory file list: `echo $sourcedir`" >> $ourlog
ls -l $sourcedir >> $ourlog
/bin/echo "" >> $ourlog
/bin/echo "Destination Directory file list: `echo $targetdir`" >> $ourlog
/bin/ls -l $targetdir >> $ourlog
/bin/echo "" >> $ourlog

## And that's it, we're done!

/bin/echo ""
/bin/echo -e "Rsync operation(s) complete - please see `/bin/echo $ourlog` for logged output."
/bin/echo ""
/bin/echo "
We are closing the log at: `/bin/date +%d-%m-%y---//---%H-%M-%S`

#########################################################################
#                                                                       #
#                               END                                     #
#                  `/bin/date`                     #
#                                                                       #
#                                                                       #
#########################################################################

" >> $ourlog

#!/bin/sh
# This is a modified version of awcli.sh that comes bundled with PresSTORE
# The differences are:
# - returning the Job ID
# - support for servers running on other hosts
# - store the "asset id" as the description
# - separating configuration data into an external file
# 
# See the file "license.txt" for information on usage and
# redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.

#
# Override locale settings
#

source /Library/Application\ Support/TV\ Tools/FinalStore/config.py

if [[ -z $AWUSER ]]; then
  echo "Configuration incomplete, please check config.py"
  exit 1
fi

LC_ALL="C"; export LC_ALL

usage() {
    echo "usage: $0 [archive | restore] plan_name file1 file2 ... fileN"
    exit 1
}
clierr() {
    echo "`$nc -c geterror`"
    exit 1
}

nc="${NC} -s awsock:/${AWUSER}:${AWPASSWORD}@${AWHOST}:${AWPORT}"

#
# Check the operation.
#

task="$1"
if test "$task" != "archive" -a "$task" != "restore"; then
    usage
fi

#
# Check the name of the Archive plan to use
# Bail-out if the plan is missing
#

shift
aplan="$1"
dummy=`$nc -c ArchivePlan $aplan describe`
if test $? -ne 0; then
    echo "$0: archive plan $aplan not found"
    exit 1
fi

#
# Refuse to work when no files given
#

shift
if test "$#" -eq 0; then
    echo "$0 no files to $task"
    exit 1
fi

#
# Now do the archive or restore task
#

case $task in
    archive)
        # Create archive selection object
        as=`$nc -c ArchiveSelection create localhost $aplan`
        if test $? -ne 0; then
            clierr
        fi
        # Create restore selection for checking if asset's been already archived
        rs=`$nc -c RestoreSelection create localhost`
        if test $? -ne 0; then
            clierr
        fi
        # Add files to it
        adfile=0
        for file do
            if [[ ! -z $FSLOG ]]; then
              echo "$(date) $task $file" >> $FSLOG
            fi
            if test ! -r "$file"; then
                echo "$0: $file: no such file"
            elif test ! -f "$file"; then
                echo "$0: $file: not a plain file"
            else
                aid=$(echo -n "$file" | md5)
                # Check if asset has already been archived
                dummy=`$nc -c RestoreSelection $rs findentry $aplan {description == $aid}`
                if [[ -z "$dummy" ]]; then
                  clierr
                fi
                if [[ "$dummy" -lt 1 ]]; then
                  aentry=`$nc -c ArchiveSelection $as addentry "{$file}" description $aid`
                  if test $? -ne 0; then
                      clierr
                    fi
                  adfile=`expr $adfile + 1`
                else
                  # Asset already in archive, just delete from FCSvr archive device
                  rm "$file"
                fi
            fi
        done
        # Submit archive job
        if test $adfile -eq 0; then
            # Nothing to archive - either no valid files, or all already archived
            echo "-1"
            exit 0
        else
            jobid=`$nc -c ArchiveSelection $as submit 1`
            echo $jobid
            if test $? -ne 0; then
                clierr
            fi
        fi
    ;;

    restore)
        # Get the database for the given plan
        dbase=`$nc -c ArchivePlan $aplan database`
        if test $? -ne 0; then
            clierr
        fi
        # Create restore selection object
        rs=`$nc -c RestoreSelection create localhost`
        if test $? -ne 0; then
            clierr
        fi
        # Add files to it
        for file do
            if [[ ! -z $FSLOG ]]; then
              echo "$(date) $task $file" >> $FSLOG
            fi
            aentry=`$nc -c ArchiveEntry handle localhost "{$file}" $dbase`
            if test $? -ne 0; then
                clierr
            fi
            apath=`$nc -c RestoreSelection $rs addentry $aentry`
            if test $? -ne 0; then
                clierr
            fi
        done
        # Submit the restore job
        jobid=`$nc -c RestoreSelection $rs submit 1`
        echo $jobid
        if test $? -ne 0; then
            clierr
        fi
    ;;
esac

exit 0

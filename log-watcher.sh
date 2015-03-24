#!/bin/sh

CMD=`basename $0`
if [ $# -lt 2 ]; then
    echo "Usage: $CMD filepath keyword [keyword_ignore]"
    exit 255
fi

LOG=$1
KEYWORD=$2
KEYWORD_IGNORE=$3
WORK_DIR=`dirname $0`

echo "watch $LOG start"

log_md5sum=`md5sum $LOG | awk '{print $1}'`
prev_count_file="$WORK_DIR/$log_md5sum.txt" 

# Check existance of target log file
if [ ! -e $LOG ]; then
    echo "Target log file is not found: $LOG"
    exit 255
fi

# Get previous count
if [ -e $prev_count_file ]; then
    prev_count=`cat $prev_count_file | awk '{ split($0,arr," ");print arr[1] }'`
    prev_timestamp=`cat $prev_count_file | awk '{ split($0,arr," ");print arr[2] " " arr[3] }'`
else
    prev_count=0
fi
echo "Previous log status [timestamp: $prev_timestamp, count: $prev_count]"

# Count current log
count=`wc -l $LOG | cut -d " " -f 1`
if [ $? -ne 0 ]; then
    echo "Failed to count current log"
    exit 255
fi
current_timestamp=`stat -c '%y' $LOG | cut -d " " -f 1,2`
echo "Current log status  [timestamp: $current_timestamp, count: $count]"

# Check difference
if [ "$current_timestamp" = "$prev_timestamp" ]; then
    # There are no differences
    echo "There are no differences"
    echo "watch $LOG successfully finished"
    exit 0
fi

# Calculate count difference
diff=`expr $count - $prev_count`
expr_rc=$?
if [ $expr_rc -gt 1 ]; then
    echo "Failed to calculate count difference"
    exit 255
fi
if [ $diff -lt 1 ]; then
    # A case of next day
    prev_count=0
    diff=$count
fi

# Inspect and evaluate
if [ "$KEYWORD_IGNORE" = "" ]; then
    tail $LOG -n +`expr $prev_count + 1` | head -n $diff | egrep "$KEYWORD" > /dev/null 2>&1
else
    tail $LOG -n +`expr $prev_count + 1` | head -n $diff | egrep -v "$KEYWORD_IGNORE" | egrep "$KEYWORD" > /dev/null 2>&1
fi
grep_rc=$?

if [ $grep_rc -eq 1 ]; then
    rc=0
elif [ $grep_rc -eq 0 ]; then
    echo "Keyword \"$KEYWORD\" found"
    rc=1
else
    echo "Filed to exec diff"
    exit 255
fi

# Update prev_count
echo "$count $current_timestamp" > $prev_count_file

echo "watch $LOG successfully finished"

exit $rc


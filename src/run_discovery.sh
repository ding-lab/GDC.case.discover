#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Obtain Catalog file with GDC sequence and methylation data for all cases

Usage:
  run_discovery.sh [options] CASES 

Options:
-h: Print this help message
-d: Dry run.  Print commands but do not execute queries
-v: Verbose.  May be repeated to get verbose output from called scripts
-J N: Evaluate N cases in parallel.  If 0, disable parallel mode. Default 0
-1: stop after processing one case
-L LOGBASE: base directory of runtime output.  Default ./dat
-t GDC_TOKEN: GDC token file

CASES is a TSV file with case name and disease in first and second columns

This calls process_case.sh once for each case, possibly using GNU parallel to process multiple cases at once
Require GDC_TOKEN environment variable to be defined with path to gdc-user-token.*.txt file

EOF


#N="-J 10"
#VERBOSE="-vvv"
DESTD="./results"
LOGBASE="./logs"

# Make sure that src/bashids/bashids exists.  This should be tested for in the code but for now make it easy
# May need to do `git submodule init; git submodule update`
BID="src/bashids/bashids"
if [ ! -x $BID ]; then
    >&2 echo ERROR: $BID does not exist or is not executable
fi

NJOBS=0
XARGS=""

# Using rungo as a template for parallel: https://github.com/ding-lab/TinDaisy/blob/master/src/rungo
# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hdvJ:1L:t:" opt; do
  case $opt in
    h)
      echo "$USAGE"
      exit 0
      ;;
    d)  # example of binary argument
      DRYRUN="d"
      ;;
    v)  
      VERBOSE="${VERBOSE}v"
      ;;
    J) # example of value argument
      NJOBS=$OPTARG
      ;;
    1)  
      JUSTONE=1
      ;;
    L)
      LOGBASE="$OPTARG"
      ;;
    t)
      GDC_TOKEN="$OPTARG"
      ;;
    \?)
      >&2 echo "Invalid option: -$OPTARG"
      echo "$USAGE"
      exit 1
      ;;
    :)
      >&2 echo "Option -$OPTARG requires an argument."
      echo "$USAGE"
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

if [ -z $GDC_TOKEN ]; then
    >&2 echo GDC_TOKEN not defined.  Quitting.
    exit 1
fi

function test_exit_status {
    # Evaluate return value for chain of pipes; see https://stackoverflow.com/questions/90418/exit-shell-script-based-on-process-exit-code
    rcs=${PIPESTATUS[*]};
    for rc in ${rcs}; do
        if [[ $rc != 0 ]]; then
            >&2 echo $SCRIPT Fatal ERROR.  Exiting.
            exit $rc;
        fi;
    done
}

# Evaluate given command CMD either as dry run or for real
function run_cmd {
    CMD=$1
    DRYRUN=$2
    QUIET=$3

    if [ -z $QUIET ]; then
        QUIET=0
    fi

    if [ "$DRYRUN" == "d" ]; then
        if [ "$QUIET" == 0 ]; then
            >&2 echo Dryrun: $CMD
        fi
    else
        if [ "$QUIET" == 0 ]; then
            >&2 echo Running: $CMD
        fi
        eval $CMD
        test_exit_status
    fi
}

if [ "$#" -ne 1 ]; then
    >&2 echo Error: Wrong number of arguments
    echo "$USAGE"
    exit 1
fi

CASES=$1
if [ ! -s $CASES ]; then
    >&2 echo ERROR: $CASES does not exist or is empty
    exit 1
fi
>&2 echo Iterating over $CASES

# If verbose flag repeated multiple times (e.g., VERBOSE="vvv"), pass the value of VERBOSE with one flag popped off (i.e., VERBOSE_ARG="vv")
if [ $VERBOSE ]; then
    VERBOSE_ARG=${VERBOSE%?}
    VERBOSE_ARG="-$VERBOSE_ARG"
fi

# Used for `parallel` job groups 
NOW=$(date)
MYID=$(date +%Y%m%d%H%M%S)

if [ $NJOBS == 0 ] ; then
    >&2 echo Running single case at a time \(single mode\)
else
    >&2 echo Job submission with $NJOBS cases in parallel
fi


function process_cases {
    # Case file has two tab separated columns, case name and disease
    while read L; do

        [[ $L = \#* ]] && continue  # Skip commented out entries

        CASE=$(echo "$L" | cut -f 1 )
        DIS=$(echo "$L" | cut -f 2 )

        LOGD="$LOGBASE/outputs/$CASE"
        mkdir -p $LOGD
        STDOUT_FN="$LOGD/log.${CASE}.out"
        STDERR_FN="$LOGD/log.${CASE}.err"

        CMD="bash src/process_case.sh $XARGS -t $GDC_TOKEN -O $LOGD $DEM $VERBOSE_ARG $CASE > $STDOUT_FN 2> $STDERR_FN"

        if [ $NJOBS != 0 ]; then
            JOBLOG="$LOGD/$CASE.log"
            CMD=$(echo "$CMD" | sed 's/"/\\"/g' )   # This will escape the quotes in $CMD 
            CMD="parallel --semaphore -j$NJOBS --id $MYID --joblog $JOBLOG --tmpdir $LOGD \"$CMD\" "
        fi

        run_cmd "$CMD" $DRYRUN
        >&2 echo Written to $STDOUT_FN

        if [ $JUSTONE ]; then
            break
        fi

    done < $CASES

    if [ $NJOBS != 0 ]; then
        # this will wait until all jobs completed
        CMD="parallel --semaphore --wait --id $MYID"
        run_cmd "$CMD" $DRYRUN
    fi
}

mkdir -p $DESTD
mkdir -p $LOGBASE

START=$(date)
>&2 echo [ $START ] Starting discovery


# real work takes place here
process_cases
rc=$?
if [[ $rc != 0 ]]; then
    >&2 echo ERROR $rc: $!
    exit $rc;
fi

END=$(date)
>&2 echo [ $END ] Discovery complete

OUTD="$LOGBASE/outputs" # must match value in src/process_multi_cases.sh
NERR=$(grep -il error $OUTD/*/*log* | wc -l)
if grep -q -i error $OUTD/*/*log* ; then
    >&2 echo The following $NERR files had errors \(top 10 shown\):
    grep -il error $OUTD/*/*log* | head
else
    >&2 echo No errors found
fi
NWRN=$(grep -il warning $OUTD/*/*log* | wc -l)
if grep -q -i warning $OUTD/*/*log* ; then
    >&2 echo The following $NWRN files had warnings \(top 10 shown\):
    grep -il warning $OUTD/*/*log* | head
else
    >&2 echo No warnings found
fi

>&2 echo Timing summary: 
>&2 echo Discovery start: [ $START ]  End: [ $END ]


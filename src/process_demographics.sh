#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Obtain demographics information for all cases

Usage:
  process_demographics.sh [options] PROJECT CASES 

Options:
-h: Print this help message
-d: Dry run.  Print commands but do not execute queries
-v: Verbose.  May be repeated to get verbose output from called scripts
-L LOGBASE: base directory of runtime output.  Default ./logs

CASES is a TSV file with case name and disease in first and second columns

PROJECT (e.g., CPTAC3) is passed directly to catalog3 column

Will write results/PROJECT.Demographics.tsv
EOF

BIND="src"
XARGS=""
LOGBASE="./logs"
DESTD="./results"

# Using rungo as a template for parallel: https://github.com/ding-lab/TinDaisy/blob/master/src/rungo
# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hdvD:L:" opt; do
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
    C)  
      XARGS="$XARGS -C"
      ;;
    L)
      LOGBASE="$OPTARG"
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

if [ "$#" -ne 2 ]; then
    >&2 echo Error: Wrong number of arguments
    echo "$USAGE"
    exit 1
fi

PROJECT=$1
CASES=$2
if [ ! -s $CASES ]; then
    >&2 echo ERROR: $CASES does not exist or is empty
    exit 1
fi
>&2 echo Project $PROJECT, iterating over $CASES

# If verbose flag repeated multiple times (e.g., VERBOSE="vvv"), pass the value of VERBOSE with one flag popped off (i.e., VERBOSE_ARG="vv")
if [ $VERBOSE ]; then
    VERBOSE_ARG=${VERBOSE%?}
    VERBOSE_ARG="-$VERBOSE_ARG"
fi

function collect_demographics {
    WRITE_HEADER=1
    DEMS_OUT="$DESTD/${PROJECT}.Demographics.tsv"
    >&2 echo Collecting all Demographics, writing to $DEMS_OUT

    # Now collect all Catalog and demographics files and write out to stdout or OUTFN
    while read L; do
        [[ $L = \#* ]] && continue  # Skip commented out entries

        CASE=$(echo "$L" | cut -f 1 )
        # Demographics info, if evaluated, is always written to file DEMS_OUT
        DEM="$LOGBASE/outputs/$CASE/demographics.dat"

        if [ ! -f $DEM ]; then
            if [ "$DRYRUN" != "d" ]; then
                >&2 echo WARNING: Demographics file $DEM for case $CASE does not exist
            fi
            continue
        fi

        # header goes only in first loop
        if [ $WRITE_HEADER == 1 ]; then
            DEM_HEADER=$(head -n1 $DEM)
            echo "$DEM_HEADER" > $DEMS_OUT
            WRITE_HEADER=0
        fi
            
        if [ ! -z $DEMS_OUT ] && [ -f $DEM ]; then
            #grep -v "^case" $DEM | sed '/^[[:space:]]*$/d' >> $DEMS_OUT
            tail -n +2 $DEM | sed '/^[[:space:]]*$/d' >> $DEMS_OUT
        fi

        if [ $JUSTONE ]; then
            break
        fi

    done < $CASES
}

collect_demographics


#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Describe what script does in one sentence

Usage:
  process_case.sh [options] CASE DISEASE

Options:
-h: Print this help message
-R OLDRUN: path to base directory of previous run to use for caching.  Note that this may miss some deprecated data

Query GDC to obtain submitted reads from GDC.  Writes the following files:
    * dat/$CASE/sample_from_case.$CASE.dat
    * dat/$CASE/read_group_from_case.$CASE.dat
    * dat/cases/$CASE/SR_from_read_group.$CASE.dat.tmp
    * dat/cases/$CASE/SR_from_read_group.$CASE.dat
where the last one is of primary interest for further processing
EOF

# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hdf:" opt; do
  case $opt in
    h)
      echo "$USAGE"
      exit 0
      ;;
    R) 
      OLDRUN=$OPTARG
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


if [ "$#" -ne 2 ]; then
    >&2 echo Error: Wrong number of arguments
    echo "$USAGE"
    exit 1
fi

CASE=$1
DIS=$2

# Called after running scripts to catch fatal (exit 1) errors
# works with piped calls ( S1 | S2 | S3 > OUT )
# Usage:
#   bash script.sh DATA | python script.py > $OUT
#   test_exit_status # Calls exit V if exit value of V of either call not 0
function test_exit_status {
    # Evaluate return value for chain of pipes; see https://stackoverflow.com/questions/90418/exit-shell-script-based-on-process-exit-code
    # exit code 137 is fatal error signal 9: http://tldp.org/LDP/abs/html/exitcodes.html

    rcs=${PIPESTATUS[*]};
    for rc in ${rcs}; do
        if [[ $rc != 0 ]]; then
            >&2 echo Fatal error.  Exiting
            exit $rc;
        fi;
    done
}

>&2 echo Processing $CASE \($DIS\)

bash CPTAC3.case.discover/get_sample.sh $CASE 
# Writes dat/$CASE/sample_from_case.$CASE.dat
test_exit_status

OUT="dat/cases/$CASE/sample_from_case.$CASE.dat"
if [ ! -s $OUT ]; then
    >&2 echo $OUT is empty.  Skipping case
    return
fi

bash CPTAC3.case.discover/get_read_groups.sh $CASE 
# Writes dat/$CASE/read_group_from_case.$CASE.dat
test_exit_status

# Evaluate old vs. new to see if can short-circuit the get_submitted_reads.sh evaluation
NEW_RESULT="dat/cases/$CASE/read_group_from_case.${CASE}.dat"

SHORT_CIRCUIT=0
if [ ! -z $OLDRUN ]; then
    OLD_RESULT="$OLDRUN/dat/cases/$CASE/read_group_from_case.${CASE}.dat"
    if [ -e $OLD_RESULT ]; then
        OLDMD5=$(md5sum $OLD_RESULT | cut -f 1 -d ' ')
        NEWMD5=$(md5sum $NEW_RESULT | cut -f 1 -d ' ')
        printf "Comparing $OLD_RESULT and $NEW_RESULT  \n  " 1>&2

        if [ "$OLDMD5" == "$NEWMD5" ]; then  # matching results.  Copy old to new 
            SHORT_CIRCUIT=1
            printf " OLDRUN Match, will copy old results\n" 1>&2
        else
            printf " OLDRUN Mismatch, re-evaluating results \n" 1>&2
        fi
    fi  
else
    printf " OLDRUN not defined, evaluating results \n" 1>&2
fi

if [ "$SHORT_CIRCUIT" == 1 ]; then
    OLD_RESULT="$OLDRUN/dat/cases/$CASE/SR_from_read_group.$CASE.dat"
    NEW_RESULT="dat/cases/$CASE/SR_from_read_group.$CASE.dat"
    >&2 echo Copying $OLD_RESULT to $NEW_RESULT
    cp $OLD_RESULT $NEW_RESULT
else
    bash CPTAC3.case.discover/get_submitted_reads.sh $CASE 
    # Writes dat/cases/$CASE/SR_from_read_group.$CASE.dat.tmp
    # and dat/cases/$CASE/SR_from_read_group.$CASE.dat
fi
test_exit_status


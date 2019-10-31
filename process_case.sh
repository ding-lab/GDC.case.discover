#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Query GDC with series of GraphQL calls to obtain information about submitted reads and methylation data for a given case

Usage:
  process_case.sh [options] CASE DISEASE

Writes the following intermediate files
* aliquots.dat
* read_groups.dat
* aligned_reads.sh
* methylation_array.dat

Options:
-h: Print this help message
-v: Verbose.  May be repeated to get verbose output from called scripts

Query GDC to obtain submitted reads from GDC.  Writes the following files to dat/cases/CASE:

EOF

# An optimization which can be performed is to reuse results from past runs
# However, this approach misses datasets associated with deprecated / replaced datasets
# so is no longer implemented

# Where scripts live
BIND="CPTAC3.case.discover"

# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hdf:" opt; do
  case $opt in
    h)
      echo "$USAGE"
      exit 0
      ;;
    v)  
      VERBOSE="${VERBOSE}v"
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

# If verbose flag repeated multiple times (e.g., VERBOSE="vvv"), pass the value of VERBOSE with one flag popped off (i.e., VERBOSE_ARG="vv")
if [ $VERBOSE ]; then
    VERBOSE_ARG=${VERBOSE%?}
fi

# Called after running scripts to catch fatal (exit 1) errors
# works with piped calls ( S1 | S2 | S3 > OUT )
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

OUTD="dat/cases/$CASE"
mkdir -p $OUTD
test_exit_status

if [ $VERBOSE ]; then
    >&2 echo xxx
fi

A_OUT="$OUTD/aliquots.dat"
bash $BIND/get_aliquots.sh -o $A_OUT $VERBOSE_ARG $CASE 
test_exit_status

if [ ! -s $A_OUT ]; then
    >&2 echo $A_OUT is empty.  Skipping case
    return
fi

RG_OUT="$OUTD/read_groups.dat"
bash $BIND/get_read_groups.sh -o $RG_OUT $VERBOSE_ARG $A_OUT
test_exit_status

SR_OUT="$OUTD/submitted_reads.sh"
bash $BIND/get_submitted_reads.sh -o $SR_OUT $VERBOSE_ARG $RG_OUT
test_exit_status

HR_OUT="$OUTD/harmonized_reads.sh"
bash $BIND/get_harmonized_reads.sh -o $HR_OUT $VERBOSE_ARG $SR_OUT
test_exit_status

MA_OUT="$OUTD/methylation_array.dat"
bash $BIND/get_methylation_array.sh -o $MA_OUT $VERBOSE_ARG $A_OUT
test_exit_status



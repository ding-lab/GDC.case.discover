#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Query GDC with series of GraphQL calls to obtain information about submitted reads and methylation data for a given case
Writes out file dat/cases/CASE/AR.dat with summary of such data

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
-d: dry run
-O OUTD: intermediate file output directory.  Default: ./dat
-o OUTFN: write final results to output file instead of STDOUT.  Will be overwritten if exists
-s SUFFIX_LIST: data file for appending suffix to sample names
-D DEM_OUT: write demograhics data to given file

Require GDC_TOKEN environment variable to be defined with path to gdc-user-token.*.txt file

SUFFIX_LIST is a TSV file listing a UUID or Aliquot ID in first column,
second column is suffix to be added to sample_name.  This allows specific samples to have modified names
EOF

# An optimization which can be performed is to reuse results from past runs
# However, this approach misses datasets associated with deprecated / replaced datasets
# so is no longer implemented

# Where scripts live
BIND="src"
OUTD="./dat"
# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hdf:O:o:s:vD:" opt; do
  case $opt in
    h)
      echo "$USAGE"
      exit 0
      ;;
    v)  
      VERBOSE="${VERBOSE}v"
      ;;
    d)
      DRYRUN="d"
      ;;
    O)
      OUTD="$OPTARG"
      ;;
    o)  
      OUTFN="$OPTARG"
      if [ -f $OUTFN ]; then
          >&2 echo WARNING: $OUTFN exists.  Deleting
          rm -f $OUTFN
      fi
      ;;
    s)
      SUFFIX_ARG="-s $OPTARG"
      ;;
    D)
      DEM_OUT="$OPTARG"
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
DISEASE=$2

mkdir -p $OUTD

function run_cmd {
    CMD=$1

    NOW=$(date)
    if [ "$DRYRUN" == "d" ]; then
        >&2 echo [ $NOW ] Dryrun: $CMD
    else
        >&2 echo [ $NOW ] Running: $CMD
        eval $CMD
        test_exit_status
    fi
}


# If verbose flag repeated multiple times (e.g., VERBOSE="vvv"), pass the value of VERBOSE with one flag popped off (i.e., VERBOSE_ARG="vv")
if [ $VERBOSE ]; then
    VERBOSE_ARG=${VERBOSE%?}
    VERBOSE_ARG="-$VERBOSE_ARG"
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

>&2 echo Processing $CASE \($DISEASE\)

OUTD="dat/cases/$CASE"
mkdir -p $OUTD
test_exit_status

A_OUT="$OUTD/aliquots.dat"
CMD="bash $BIND/get_aliquots.sh -o $A_OUT $VERBOSE_ARG $CASE "
run_cmd "$CMD"

if [ ! -s $A_OUT ]; then
    >&2 echo NOTE: $A_OUT is empty.  Skipping case
    if [ ! -z $OUTFN ]; then
        touch $OUTFN
    fi
else
    RG_OUT="$OUTD/read_groups.dat"
    CMD="bash $BIND/get_read_groups.sh -o $RG_OUT $VERBOSE_ARG $A_OUT"
    run_cmd "$CMD"

    SR_OUT="$OUTD/submitted_reads.dat"
    CMD="bash $BIND/get_submitted_reads.sh -o $SR_OUT $VERBOSE_ARG $RG_OUT"
    run_cmd "$CMD"

    HR_OUT="$OUTD/harmonized_reads.dat"
    CMD="bash $BIND/get_harmonized_reads.sh -o $HR_OUT $VERBOSE_ARG $SR_OUT"
    run_cmd "$CMD"

    MA_OUT="$OUTD/methylation_array.dat"
    CMD="bash $BIND/get_methylation_array.sh -o $MA_OUT $VERBOSE_ARG $A_OUT"
    run_cmd "$CMD"

    if [ ! -z $OUTFN ]; then
        AR_OUT="-o $OUTFN"
    fi
    CMD="bash $BIND/make_AR.sh -Q $A_OUT -R $SR_OUT -H $HR_OUT -M $MA_OUT $SUFFIX_ARG $AR_OUT $VERBOSE_ARG $CASE $DISEASE"
    run_cmd "$CMD"
fi

if [ ! -z $DEM_OUT ]; then
    CMD="bash $BIND/get_demographics.sh -o $DEM_OUT $VERBOSE_ARG $CASE $DISEASE"
    run_cmd "$CMD"
fi

#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Query GDC with series of GraphQL calls to obtain information about submitted reads and methylation data for a given case
Aliquot discovery performed for both TCGA and CPTAC data models

Usage:
  process_case.sh [options] CASE 

Writes the following intermediate files in the directory OUTD
* aliquots.dat
* [is_empty.flag] - only if aliquots are empty
* read_groups.dat
* methylation_array.dat
* demographics.dat

Options:
-h: Print this help message
-v: Verbose.  May be repeated to get verbose output from called scripts
-d: dry run
-O OUTD: intermediate file output directory.  Default: ./dat
-t GDC_TOKEN: path to gdc-user-token.*.txt file
-D DISEASE

SUFFIX_LIST is a TSV file listing a UUID or Aliquot ID in first column, second
column is suffix to be added to sample_name.  This allows specific samples to
have modified names.  This is implemented only for catalog2

EOF

# An optimization which can be performed is to reuse results from past runs
# However, this approach misses datasets associated with deprecated / replaced datasets
# so is no longer implemented

# Where scripts live
OUTD="./dat"
DISEASE="unknown"   # this is not strictly needed, but used in demographics.  Catalog gets case disease info at catalog creation time
# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hdf:O:vt:D:" opt; do
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
    s)
      SUFFIX_ARG="-s $OPTARG"
      ;;
    t)
      GDC_TOKEN="$OPTARG"
      ;;
    D)
      DISEASE="$OPTARG"
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

if [ "$#" -ne 1 ]; then
    >&2 echo Error: Wrong number of arguments
    echo "$USAGE"
    exit 1
fi

CASE=$1
export GDC_TOKEN

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
    if [ "$VERBOSE_ARG" != "" ]; then
        VERBOSE_ARG="-$VERBOSE_ARG"
    fi
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

function confirm {
    FN=$1
    if [ ! -s $FN ]; then
        >&2 echo ERROR: $FN does not exist or is empty
        exit 1
    fi
}

>&2 echo Processing $CASE 

A_OUT="$OUTD/aliquots.dat"
RG_OUT="$OUTD/read_groups.dat"
SR_OUT="$OUTD/submitted_reads.dat"
HR_OUT="$OUTD/harmonized_reads.dat"
MA_OUT="$OUTD/methylation_array.dat"
DEM_OUT="$OUTD/demographics.dat"


mkdir -p $OUTD
test_exit_status

# Run both TCGA and CPTAC data models 
A1_OUT="$OUTD/aliquots-CPTAC.dat"
A2_OUT="$OUTD/aliquots-TCGA.dat"
CMD="bash src/get_aliquots.sh -m CPTAC $ALIQUOT_ARGS -o $A1_OUT $VERBOSE_ARG $CASE "
run_cmd "$CMD"
CMD="bash src/get_aliquots.sh -m TCGA $ALIQUOT_ARGS -o $A2_OUT $VERBOSE_ARG $CASE "
run_cmd "$CMD"

# Merge the CPTAC and TCGA discovery aliquots, respecting the header line
head -n1 $A1_OUT > $A_OUT
sort -u <(tail -n +2 $A1_OUT) <(tail -n +2 $A2_OUT) >> $A_OUT

# see if any aliquots results were found
if [ $(wc -l $A_OUT | cut -f 1 -d ' ' ) == "1" ]; then
    >&2 echo NOTE: $A_OUT is empty.  Skipping case
    CMD="touch $OUTD/is_empty.flag"
    run_cmd "$CMD"
else
    CMD="bash src/get_read_groups.sh -o $RG_OUT $VERBOSE_ARG $A_OUT"
    run_cmd "$CMD"

    CMD="bash src/get_submitted_reads.sh -o $SR_OUT $VERBOSE_ARG $RG_OUT"
    run_cmd "$CMD"

    CMD="bash src/get_harmonized_reads.sh -o $HR_OUT $VERBOSE_ARG $SR_OUT"
    run_cmd "$CMD"

    CMD="bash src/get_methylation_array.sh -o $MA_OUT $VERBOSE_ARG $A_OUT"
    run_cmd "$CMD"
fi

CMD="bash src/get_demographics.sh -o $DEM_OUT $VERBOSE_ARG $CASE $DISEASE"
run_cmd "$CMD"


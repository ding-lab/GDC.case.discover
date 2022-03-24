#!/bin/bash

# TODO: allow make_catalog to be run with aliquots and read_groups already existing
# This can be with a flag or by moving catalog file creation to a separate process

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Query GDC with series of GraphQL calls to obtain information about submitted reads and methylation data for a given case
Writes out file dat/outputs/CASE/Catalog.dat with summary of such data (Catalog3 format)

Usage:
  process_case.sh [options] CASE DISEASE PROJECT

Writes the following intermediate files in the directory OUTD
* aliquots.dat
* [is_empty.flag] - only if aliquots are empty
* read_groups.dat
* methylation_array.dat
* submitted_reads.catalog3.dat
* harmonized_reads.catalog3.dat
* Also writes demographics 

Options:
-h: Print this help message
-v: Verbose.  May be repeated to get verbose output from called scripts
-d: dry run
-O OUTD_BASE: intermediate file output directory.  Default: ./dat
-D DEM_OUT: write demographics data to given file
-C: create catalog only.  Assume that all the above files exist in $OUTD except for the catalog3
-m DATA_MODEL: determines how case associated with aliquot.  Allowed values TCGA or CPTAC

Require GDC_TOKEN environment variable to be defined with path to gdc-user-token.*.txt file

Both DISEASE (e.g., BRCA) and PROJECT (e.g., CPTAC3) are passed as-is to appropriate Catalog columns
EOF

# An optimization which can be performed is to reuse results from past runs
# However, this approach misses datasets associated with deprecated / replaced datasets
# so is no longer implemented

# Where scripts live
BIND="src"
OUTD_BASE="./dat"
# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hdf:O:vD:Cm:" opt; do
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
      OUTD_BASE="$OPTARG"
      ;;
    D)
      DEM_OUT="$OPTARG"
      ;;
    C)
      CATALOG_ONLY=1
      ;;
    m)
      ALIQUOT_ARGS="-m $OPTARG"
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

if [ "$#" -ne 3 ]; then
    >&2 echo Error: Wrong number of arguments
    echo "$USAGE"
    exit 1
fi

CASE=$1
DISEASE=$2
PROJECT=$3

mkdir -p $OUTD_BASE

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

>&2 echo Processing $CASE \($DISEASE\)

OUTD="$OUTD_BASE/outputs/$CASE"
RG_OUT="$OUTD/read_groups.dat"
SR_OUT="$OUTD/submitted_reads.dat"
HR_OUT="$OUTD/harmonized_reads.dat"
MA_OUT="$OUTD/methylation_array.dat"

if [ -z $CATALOG_ONLY ]; then
    mkdir -p $OUTD
    test_exit_status

    A_OUT="$OUTD/aliquots.dat"
    CMD="bash $BIND/get_aliquots.sh $ALIQUOT_ARGS -o $A_OUT $VERBOSE_ARG $CASE "
    run_cmd "$CMD"

    # aliquots.dat has a header line
    if [ $(wc -l $A_OUT | cut -f 1 -d ' ' ) == "1" ]; then
        >&2 echo NOTE: $A_OUT is empty.  Skipping case
        CMD="touch $OUTD/is_empty.flag"
        run_cmd "$CMD"
    else
        CMD="bash $BIND/get_read_groups.sh -o $RG_OUT $VERBOSE_ARG $A_OUT"
        run_cmd "$CMD"

        CMD="bash $BIND/get_submitted_reads.sh -o $SR_OUT $VERBOSE_ARG $RG_OUT"
        run_cmd "$CMD"

        CMD="bash $BIND/get_harmonized_reads.sh -o $HR_OUT $VERBOSE_ARG $SR_OUT"
        run_cmd "$CMD"

        CMD="bash $BIND/get_methylation_array.sh -o $MA_OUT $VERBOSE_ARG $A_OUT"
        run_cmd "$CMD"
    fi
else
    confirm $RG_OUT
    confirm $SR_OUT
    confirm $HR_OUT
    confirm $MA_OUT    # methylation array currently not implemented in make_catalog3
fi

# TODO: Allow make_catalog3.sh to be called directly without having to do discovery
# Note   
# CMD="bash $BIND/make_catalog.sh -Q $A_OUT -R $SR_OUT -H $HR_OUT -M $MA_OUT $SUFFIX_ARG $CATALOG_OUT $VERBOSE_ARG $CASE $DISEASE"
# make_catalog3.sh does not have VERBOSE_ARG implemented, nor is its DEBUG flag passed here
# Do not pass CASE explicitly, since that information is obtained from submitted / harmonized reads
if [ ! -e $OUTD/is_empty.flag ]; then
    CMD="bash $BIND/make_catalog3.sh -o $OUTD -D $DISEASE -P $PROJECT $OUTD"
    run_cmd "$CMD"
fi

if [ ! -z $DEM_OUT ]; then
    CMD="bash $BIND/get_demographics.sh -o $DEM_OUT $VERBOSE_ARG $CASE $DISEASE"
    run_cmd "$CMD"
fi

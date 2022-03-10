#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

# Create catalog3 for a given output directory
# Assumes names of output files
# Processes both submitted reads and harmonized reads
# Does not deal with Methylation at this time

#DATD="/Users/mwyczalk/Projects/CPTAC3/Discovery/dev.TCGA2/CPTAC3.case.discover/data/TCGA-A6-6780"
#DATD="/Users/mwyczalk/Projects/CPTAC3/Discovery/dev.TCGA2/CPTAC3.case.discover/data/TCGA-44-6146"
# C3L-00016 has multiple samples per dataset
# DATD="/Users/mwyczalk/Projects/CPTAC3/Discovery/dev.TCGA2/CPTAC3.case.discover/data/C3L-00016"
# TCGA-A6-5665 has multiple annotations for some datasets
# DATD="/Users/mwyczalk/Projects/CPTAC3/Discovery/dev.TCGA2/CPTAC3.case.discover/data/TCGA-A6-5665"


read -r -d '' USAGE <<'EOF'
Create catalog3 files for both submitted and harmonized reads

Usage:
  make_catalog3.sh [options] DATD

Options:
-h: Print this help message
-d: Dry run.  Will not write any data
-o: Output directery OUTD.  Will create if does not exist.  Default: '.'
-D DISEASE: Disease code associated with case, e.g., BRCA.  Used only `disease` column in catalog output
-P PROJECT: Project code associated with case, e.g., CPTAC3.  Used only `project` column in catalog output

Input data: Read the following files $DATD:
* aliquots.dat
* submitted_reads.dat
* harmonized_reads.dat
All three files must exist.

Files we write:
* OUTD/submitted_reads.catalog3.dat
* OUTD/harmonized_reads.catalog3.dat

EOF

OUTD="."
DP_ARGS=""  # Will hold optional flags for DISEASE and PROJECT
# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hdo:D:P:" opt; do
  case $opt in
    h)
      echo "$USAGE"
      exit 0
      ;;
    d)  
      DRYRUN="d"
      ;;
    o) 
      OUTD=$OPTARG
      ;;
    D) 
      DP_ARGS="$DP_ARGS -D $OPTARG"
      ;;
    P) 
      DP_ARGS="$DP_ARGS -P $OPTARG"
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
    rcs=${PIPESTATUS[*]};
    for rc in ${rcs}; do
        if [[ $rc != 0 ]]; then
            >&2 echo Fatal error.  Exiting
            exit $rc;
        fi;
    done
}

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

if [ "$#" -ne 1 ]; then
    >&2 echo Error: Wrong number of arguments
    echo "$USAGE"
    exit 1
fi

mkdir -p $OUTD
test_exit_status 
OUT_SR="$OUTD/submitted_reads.catalog3.dat"
OUT_HR="$OUTD/harmonized_reads.catalog3.dat"
OUT_ME="$OUTD/methylation_array.catalog3.dat"

PYTHON="/diskmnt/Projects/Users/mwyczalk/miniconda3/bin/python"
#PYTHON="/Users/mwyczalk/miniconda3/bin/python"

# Usage: make_catalog3.sh -o OUTD DATD 
DATD=$1

if [ ! -d $DATD ]; then >&2 echo ERROR: $DATD does not exist; exit 1; fi

AQ_FN="$DATD/aliquots.dat"
SR_FN="$DATD/submitted_reads.dat"
HR_FN="$DATD/harmonized_reads.dat"
ME_FN="$DATD/methylation_array.dat"

# Deal gracefully with situation where reads do not exist.
if [ ! -e $AQ_FN ]; then >&2 echo ERROR: $AQ_FN does not exist; exit 1; fi

if [ ! -e $SR_FN ]; then 
    >&2 echo NOTE: $SR_FN does not exist.  Continuing
else
    echo Processing $SR_FN, writing to $OUT_SR
    CMD="$PYTHON src/make_catalog3.py $DP_ARGS -Q $AQ_FN -o $OUT_SR $SR_FN"
    run_cmd "$CMD"
fi

if [ ! -e $HR_FN ]; then 
    >&2 echo NOTE: $HR_FN does not exist.  Continuing
else
    echo Processing $HR_FN, writing to $OUT_HR
    CMD="$PYTHON src/make_catalog3.py $DP_ARGS -Q $AQ_FN -o $OUT_HR $HR_FN"
    run_cmd "$CMD"
fi

if [ ! -e $ME_FN ]; then 
    >&2 echo NOTE: $ME_FN does not exist.  Continuing
else
    echo Processing $ME_FN, writing to $OUT_ME
    CMD="$PYTHON src/make_catalog3.py $DP_ARGS -M -Q $AQ_FN -o $OUT_ME $ME_FN"
    run_cmd "$CMD"
fi

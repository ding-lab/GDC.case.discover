#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Obtain Catalog file with GDC sequence and methylation data for all cases

Usage:
  process_catalog.sh [options] PROJECT CASES

Options:
-h: Print this help message
-d: Dry run.  Print commands but do not execute queries
-v: Verbose.  May be repeated to get verbose output from called scripts
-1: stop after processing one case
-L LOGBASE: base directory of runtime output.  Default ./logs
-c: create v2 catalog 
-s SUFFIX_LIST: data file for appending suffix to sample names (catalog 2 only)

CASES is a TSV file with case name and disease in first and second columns

PROJECT (e.g., CPTAC3) is passed directly to catalog3 column and used for catalog filename
EOF

NJOBS=0
# Where scripts live
XARGS=""
LOGBASE="./logs"

DESTD="./results"
#CATALOG="$DESTD/${PROJECT}.Catalog3.tsv"
#DEMOGRAPHICS="$DESTD/${PROJECT}.Demographics.tsv"


# Using rungo as a template for parallel: https://github.com/ding-lab/TinDaisy/blob/master/src/rungo
# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hdv1L:cs:" opt; do
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
    1)  
      JUSTONE=1
      ;;
    L)
      LOGBASE="$OPTARG"
      ;;
    c)
      DO_CATALOG2=1
      ;;
    s)  
      XARGS="$XARGS -s $OPTARG"
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

function confirm {
    FN=$1
    if [ ! -s $FN ]; then
        >&2 echo ERROR: $FN does not exist or is empty
        exit 1
    fi
}


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

function process_case {
    OUTD=$1     # -O LOGD
    DISEASE=$2  

    A_OUT="$OUTD/aliquots.dat"
    RG_OUT="$OUTD/read_groups.dat"
    SR_OUT="$OUTD/submitted_reads.dat"
    HR_OUT="$OUTD/harmonized_reads.dat"
    MA_OUT="$OUTD/methylation_array.dat"

    if [ -e "$OUTD/is_empty.flag" ]; then
        >&2 echo $OUTD/is_empty.flag exists.  Skipping case
    else
        confirm $RG_OUT
        confirm $SR_OUT
        confirm $HR_OUT

        # make_catalog3.sh is the standard one
        if [ -z $DO_CATALOG2 ]; then
            >&2 echo Running Catalog3
            CMD="bash src/make_catalog3.sh -o $OUTD -D $DISEASE -P $PROJECT $OUTD"
        else
            >&2 echo Running Catalog2
            CATALOG_OUT="-o $OUTD/${PROJECT}.Catalog.dat"  
            CMD="bash src/make_catalog2.sh -Q $A_OUT -R $SR_OUT -H $HR_OUT -M $MA_OUT $SUFFIX_ARG $CATALOG_OUT -v $CASE $DISEASE"
        fi
        run_cmd "$CMD"
    fi
}


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

        CMD="process_case $LOGD $DIS"

        run_cmd "$CMD" $DRYRUN

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

function collect_catalog3 {

    WRITE_HEADER=1
    CATALOG3="$DESTD/${PROJECT}.Catalog3.tsv"

    >&2 echo Collecting all Catalog files, writing to $CATALOG3

    if [ ! -e $CATALOG3 ]; then
        touch $CATALOG3
    fi

    # Now collect all catalog3 and demographics files and write out to stdout or CATALOG3
    while read L; do
        [[ $L = \#* ]] && continue  # Skip commented out entries

        CASE=$(echo "$L" | cut -f 1 )
        DATAD="$LOGBASE/outputs/$CASE"
        # Will merge harmonized and submitted reads
        # If is_empty.flag file exists then just go on
        # Note that we're not making assumptions about the existence of these even if is_empty.flag exists
        # since submitted reads may not exist even if aliquots do, and 
        # harmonized reads may not exist even if submitted reads do

        # Use the existence of the `is_empty.flag` file to identify empty cases
        if [ -e "$DATAD/is_empty.flag" ]; then
            continue
        fi

        SR_CAT="$DATAD/submitted_reads.catalog3.dat"
        HR_CAT="$DATAD/harmonized_reads.catalog3.dat"
        ME_CAT="$DATAD/methylation_array.catalog3.dat"

        unset CAT
        if [ -e $SR_CAT ]; then 
            CAT="$SR_CAT"
        fi
        if [ -e $HR_CAT ]; then 
            CAT="$CAT $HR_CAT"
        fi
        if [ -e $ME_CAT ]; then 
            CAT="$CAT $ME_CAT"
        fi

        if [ -z "$CAT" ]; then
            continue
        fi
        # header taken from submitted reads, goes only in first loop
        # For catalog3 do not put a "#" in header line
        if [ $WRITE_HEADER == 1 ]; then
            HEADER=$(grep "dataset_name" $SR_CAT | head -n1 )
            echo "$HEADER" > $CATALOG3
            test_exit_status
            WRITE_HEADER=0
        fi
        cat $CAT | grep -v '^dataset_name' | sed '/^[[:space:]]*$/d' | sort -u >> $CATALOG3
        test_exit_status

        if [ $JUSTONE ]; then
            break
        fi

    done < $CASES
}

function collect_catalog2 {
    WRITE_HEADER=1
    CATALOG2="$DESTD/${PROJECT}.Catalog.dat"

    # Now collect all Catalog and demographics files and write out to stdout or OUTFN
    while read L; do
        [[ $L = \#* ]] && continue  # Skip commented out entries

        CASE=$(echo "$L" | cut -f 1 )
        CATALOG="$LOGBASE/outputs/$CASE/${PROJECT}.Catalog.dat"
        EMPTY_FLAG="$LOGBASE/outputs/$CASE/is_empty.flag"

        if [ ! -f $CATALOG ] ; then
            if [ "$DRYRUN" != "d" ] && [ ! -f $EMPTY_FLAG ]; then
                >&2 echo WARNING: Catalog file $CATALOG for case $CASE does not exist
            fi
            continue
        fi

        # header goes only in first loop
        if [ $WRITE_HEADER == 1 ]; then
            HEADER=$(grep "^#" $CATALOG | head -n1)
            echo "$HEADER" > $CATALOG2
            WRITE_HEADER=0
        fi

        sort -u $CATALOG | grep -v "^#" >> $CATALOG2

        if [ $JUSTONE ]; then
            break
        fi

    done < $CASES
    >&2 echo Collected Catalog2 details into $CATALOG2
}

# main loop
process_cases

if [ ! $JUSTONE ] ; then
    if [ ! $DO_CATALOG2 ]; then
        collect_catalog3
    else
        collect_catalog2
    fi
fi




#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Obtain Catalog file with GDC sequence and methylation data for all cases

Usage:
  process_multi_cases.sh [options] CASES PROJECT

Options:
-h: Print this help message
-d: Dry run.  Print commands but do not execute queries
-v: Verbose.  May be repeated to get verbose output from called scripts
-J N: Evaluate N cases in parallel.  If 0, disable parallel mode. Default 0
-o OUTFN: write result Catalog file.  Required, must not exist
-1: stop after processing one case
-D DEMS_OUT: write demographics information from all cases to given file
-C: create catalog only.  Assume that all discovery files exist from previous run 
-m DATA_MODEL: data model.  TCGA or CPTAC3

CASES is a TSV file with case name and disease in first and second columns

PROJECT (e.g., CPTAC3) is passed directly to catalog3 column

This calls process_case.sh once for each case, possibly using GNU parallel to process multiple cases at once
Require GDC_TOKEN environment variable to be defined with path to gdc-user-token.*.txt file

EOF

NJOBS=0
# Where scripts live
BIND="src"
XARGS=""

# Using rungo as a template for parallel: https://github.com/ding-lab/TinDaisy/blob/master/src/rungo
# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hdvJ:1o:D:Cm:" opt; do
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
    o)  
      OUTFN="$OPTARG"
      if [ -f $OUTFN ]; then
          #>&2 echo ERROR: $OUTFN exists.  Exiting
          >&2 echo WARNING: $OUTFN exists.  Continuing...
          #exit 1
      fi
      ;;
    D)
      DEMS_OUT="$OPTARG"
      ;;
    C)  
      XARGS="$XARGS -C"
      ;;
    m)
      XARGS="$XARGS -m $OPTARG"
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
    >&2 echo GDC_TOKEN environment variable not defined.  Quitting.
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

if [ "$#" -ne 2 ]; then
    >&2 echo Error: Wrong number of arguments
    echo "$USAGE"
    exit 1
fi

CASES=$1
PROJECT=$2
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

# Used for `parallel` job groups 
NOW=$(date)
MYID=$(date +%Y%m%d%H%M%S)

if [ $NJOBS == 0 ] ; then
    >&2 echo Running single case at a time \(single mode\)
else
    >&2 echo Job submission with $NJOBS cases in parallel
fi

# logs will go in same directory as output
LOGBASE="./dat"

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
        if [ ! -z $DEMS_OUT ]; then  # get demographics only if requested
            DEM="-D $LOGD/Demographics.dat"
        fi

        CMD="bash $BIND/process_case.sh $XARGS -O $LOGD $DEM $VERBOSE_ARG $CASE $DIS $PROJECT > $STDOUT_FN 2> $STDERR_FN"

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

function collect_catalog {
    WRITE_HEADER=1

    if [ ! -e $OUTFN ]; then
        touch $OUTFN
    fi

    # Now collect all catalog3 and demographics files and write out to stdout or OUTFN
    while read L; do
        [[ $L = \#* ]] && continue  # Skip commented out entries

        CASE=$(echo "$L" | cut -f 1 )
        DATAD="$LOGBASE/outputs/$CASE"
        # Will merge harmonized and submitted reads
        # If is_empty.flag file exists then just go on
        # Note that we're not making assumptions about the existence of these even if is_empty.flag exists
        # since harmonized reads may not exist even if submitted reads do

        # Use the existence of the `is_empty.flag` file to identify empty cases
        if [ -e "$DATAD/is_empty.flag" ]; then
            continue
        fi

        SR_CAT="$DATAD/submitted_reads.catalog3.dat"
        HR_CAT="$DATAD/harmonized_reads.catalog3.dat"
        # Possibly add Methylation?

        if [ -e $SR_CAT ]; then 
            CAT="$SR_CAT"
        fi
        if [ -e $HR_CAT ]; then 
            CAT="$CAT $HR_CAT"
        fi

        # header taken from submitted reads, goes only in first loop
        # We no longer put a "#" in header line
        if [ $WRITE_HEADER == 1 ]; then
            HEADER=$(grep "dataset_name" $SR_CAT | head -n1 )
            echo "$HEADER" > $OUTFN
            test_exit_status
            WRITE_HEADER=0
        fi
            
        cat $CAT | grep -v "^dataset_name" | sed '/^[[:space:]]*$/d' | sort -u >> $OUTFN
        test_exit_status

        if [ $JUSTONE ]; then
            break
        fi

    done < $CASES
}

function collect_demographics {
    WRITE_HEADER=1

    # Now collect all Catalog and demographics files and write out to stdout or OUTFN
    while read L; do
        [[ $L = \#* ]] && continue  # Skip commented out entries

        CASE=$(echo "$L" | cut -f 1 )
        # Demographics info, if evaluated, is always written to file DEMS_OUT
        DEM="$LOGBASE/outputs/$CASE/Demographics.dat"

        if [ ! -f $DEM ]; then
            if [ "$DRYRUN" != "d" ]; then
                >&2 echo WARNING: Demographics file $DEM for case $CASE does not exist
            fi
            continue
        fi

        # header goes only in first loop
        if [ $WRITE_HEADER == 1 ]; then
            DEM_HEADER=$(grep "^#" $DEM | head -n1)
            echo "$DEM_HEADER" > $DEMS_OUT
            WRITE_HEADER=0
        fi
            
        if [ ! -z $DEMS_OUT ] && [ -f $DEM ]; then
            grep -v "^#" $DEM | sed '/^[[:space:]]*$/d' >> $DEMS_OUT
        fi

        if [ $JUSTONE ]; then
            break
        fi

    done < $CASES
}


# main loop
process_cases

>&2 echo Collecting all Catalog files, writing to $OUTFN
collect_catalog

if [ ! -z $DEMS_OUT ]; then
    >&2 echo Collecting all Demographics, writing to $DEMS_OUT
    collect_demographics
fi



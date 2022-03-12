#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Query GDC to obtain methylation array data associated with aliquots

Usage:
  get_demographics.sh [options] CASE DISEASE

Writes the following columns for each case
    * case
    * disease
    * ethnicity
    * gender
    * race
    * days to birth

Options:
-h: Print this help message
-v: Verbose.  May be repeated to get verbose output from queryGDC.sh
-o OUTFN: write results to output file instead of STDOUT.  Will be overwritten if exists

Require GDC_TOKEN environment variable to be defined with path to gdc-user-token.*.txt file
EOF

QUERYGDC="src/queryGDC.sh"
# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hvo:" opt; do
  case $opt in
    h)
      echo "$USAGE"
      exit 0
      ;;
    v)  
      VERBOSE="${VERBOSE}v"
      ;;
    o)  
      OUTFN="$OPTARG"
      if [ -f $OUTFN ]; then
          >&2 echo WARNING: $OUTFN exists.  Deleting
          rm -f $OUTFN
      fi
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

if [ -z $GDC_TOKEN ]; then
    >&2 echo GDC_TOKEN environment variable not defined.  Quitting.
    exit 1
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

# Writes one line per CASE to stdout
function demo_from_case_query {
CASE=$1 # E.g C3L-00004
cat <<EOF
{
    demographic(with_path_to: {type: "case", submitter_id:"$CASE"})
    {
        ethnicity
        gender
        race
        days_to_birth
    }
}
EOF
}

# print header.  No hash mark in header
OUTLINE=$(printf "case\tdisease\tethnicity\tgender\trace\tdays_to_birth\n")
if [ ! -z $OUTFN ]; then
    echo "$OUTLINE" >> $OUTFN
else
    echo "$OUTLINE"
fi

Q=$(demo_from_case_query $CASE)
if [ $VERBOSE ]; then
    >&2 echo QUERY: $Q
    if [ "$VERBOSE" == "vv" ] ; then
        GDC_VERBOSE="-v"
    fi
fi

R=$(echo $Q | $QUERYGDC -r $GDC_VERBOSE -)
test_exit_status
if [ $VERBOSE ]; then
    >&2 echo RESULT: $R
fi

OUTLINE=$(echo $R | jq -r '.data.demographic[] | "\(.ethnicity)\t\(.gender)\t\(.race)\t\(.days_to_birth)"' | sed "s/^/$CASE\t$DISEASE\t/" )

if [ ! -z $OUTFN ]; then
    echo "$OUTLINE" >> $OUTFN
else
    echo "$OUTLINE"
fi

if [ ! -z $OUTFN ]; then
    >&2 echo Written to $OUTFN
fi


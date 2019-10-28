#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Query GDC to obtain aliquot details associated with a given case

Usage:
  get_aliquot.sh [options] CASE

Options:
-h: Print this help message
-v: Verbose
-o OUTFN: write results to output file instead of STDOUT.  Will be overwritten if exists

Writes the following columns for each aliquot:
    * case
    * submitter_id
    * id
    * analyte_type

Require GDC_TOKEN environment variable to be defined containing GDC token content
EOF

QUERYGDC="CPTAC3.case.discover/queryGDC"
# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hdvo:" opt; do
  case $opt in
    h)
      echo "$USAGE"
      exit 0
      ;;
    d)  # example of binary argument
      >&2 echo "Dry run"
      CMD="echo"
      ;;
    v)  
      VERBOSE="-v"
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

if [ "$#" -ne 1 ]; then
    >&2 echo Error: Wrong number of arguments
    echo "$USAGE"
    exit 1
fi
CASE=$1

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

function aliquot_from_case {
    SAMPLE=$1 # E.g C3L-00004-31
    cat <<EOF
    {
        aliquot(with_path_to: {type: "case", submitter_id:"$CASE"}, first:10000)
        {
            submitter_id
            id
            analyte_type
        }
    }
EOF
}
 
# OUTD="dat/cases/$CASE"
# mkdir -p $OUTD
# OUT="$OUTD/aliquot_from_case.$CASE.dat"

Q=$(aliquot_from_case $CASE)
>&2 echo QUERY: $Q

# The actual call to queryGDC script
R=$(echo $Q | $QUERYGDC -r $VERBOSE -)
test_exit_status

OUTLINE=$(echo $R | jq -r '.data.aliquot[] | "\(.submitter_id)\t\(.id)\t\(.analyte_type)"' | sed "s/^/$CASE\t/")
test_exit_status

if [ ! -z $OUTFN ]; then
    echo "$OUTLINE" >> $OUTFN
    >&2 echo Written to $OUTFN
else
    echo "$OUTLINE"
fi


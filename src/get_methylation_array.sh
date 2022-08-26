#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Query GDC to obtain methylation array data associated with aliquots

Usage:
  get_methylation_array.sh [options] aliquots.dat

aliquots.dat is a file with aliquot information as generated by get_aliquots.sh
Writes the following columns for each methylation array
    * case
    * aliquot submitter id
    * assumed reference = NA 
    * submitter id
    * id
    * channel
    * file name
    * file size
    * data_format
    * experimental strategy
    * md5sum
    * state

Options:
-h: Print this help message
-v: Verbose.  May be repeated to get verbose output from queryGDC.sh
-o OUTFN: write results to output file instead of STDOUT.  Will be overwritten if exists

Require GDC_TOKEN environment variable to be defined with path to gdc-user-token.*.txt file
EOF

# Assumed reference
REF="NA"

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

if [ "$#" -ne 1 ]; then
    >&2 echo Error: Wrong number of arguments
    echo "$USAGE"
    exit 1
fi
DAT=$1

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

function methylation_array_from_aliquot {
    ALIQUOT=$1 # CPT0206560009
    cat <<EOF
    {
        raw_methylation_array(with_path_to: {type: "aliquot", submitter_id:"$ALIQUOT"}, first:10000)
        {
            submitter_id
            id
            channel
            file_name
            file_size
            data_format
            experimental_strategy
            md5sum
            state
        }
    }
EOF
}

if [ $VERBOSE ]; then
    >&2 echo Processing $DAT
fi

while read L; do
# Columns of input data
#    * case
#    * sample submitter id
#    * sample id
#    * sample type
#    * aliquot submitter id
#    * aliquot id
#    * analyte_type

    CASE=$(echo "$L" | cut -f 1)
    ASID=$(echo "$L" | cut -f 5)
    AT=$(echo "$L" | cut -f 7)

    # process only DNA aliquots
    if [ "$AT" != "DNA" ]; then
#        >&2 echo Skipping $AT
        continue
    fi

    Q=$(methylation_array_from_aliquot $ASID)
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

    OUTLINE=$(echo $R | jq -r '.data.raw_methylation_array[] | "\(.submitter_id)\t\(.id)\t\(.channel)\t\(.file_name)\t\(.file_size)\t\(.data_format)\t\(.experimental_strategy)\t\(.md5sum)\t\(.state)"' | sed "s/^/$CASE\t$ASID\t$REF\t/")
    test_exit_status

    if [ "$OUTLINE" ]; then
        if [ ! -z $OUTFN ]; then
            echo "$OUTLINE" >> $OUTFN
        else
            echo "$OUTLINE"
        fi
    fi

done < $DAT

if [ ! -z $OUTFN ]; then
    >&2 echo Written to $OUTFN
fi

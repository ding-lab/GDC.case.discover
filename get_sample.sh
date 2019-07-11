# Return details on all samples for a given case
# writes "sample_from_case" file

# Environment variable QUERYGDC_HOME points queryGDC installation dir
# default is ./queryGDC

# TODO: introduce arguments here
# GDC_TOKEN logic should be similar to that in queryGDC - can be set with -t or environment variable
# currently, token is not passed but read from GDC_TOKEN


if [ "$#" -ne 1 ]; then
    >&2 echo Error: Wrong number of arguments
    >&2 echo Usage: get_sample.sh CASE 
    exit 1
fi

CASE=$1

if [ -z $GDC_TOKEN ]; then
    >&2 GDC_TOKEN environment variable not defined.  Quitting.
    exit 1
fi

# Called after running scripts to catch fatal (exit 1) errors
# works with piped calls ( S1 | S2 | S3 > OUT )
# Usage:
#   bash script.sh DATA | python script.py > $OUT
#   test_exit_status # Calls exit V if exit value of V of either call not 0
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
 
function sample_from_case_query {
CASE=$1 # E.g C3L-00004
cat <<EOF
{
    sample(with_path_to: {type: "case", submitter_id:"$CASE"}, first:100)
    {
        submitter_id
        id
        sample_type
    }
}
EOF
}

if [ -z $QUERYGDC_HOME ]; then
    QUERYGDC_HOME="./queryGDC"
    >&2 echo QUERYGDC_HOME not set, using default ./queryGDC
fi
QUERYGDC="$QUERYGDC_HOME/queryGDC"


OUTD="dat/cases/$CASE"
mkdir -p $OUTD
OUT="$OUTD/sample_from_case.$CASE.dat"

Q=$(sample_from_case_query $CASE)

>&2 echo QUERY: $Q

# The actual call to queryGDC script
R=$(echo $Q | $QUERYGDC -r -v -)
test_exit_status


echo $R | jq -r '.data.sample[] | "\(.submitter_id)\t\(.id)\t\(.sample_type)"' > $OUT
test_exit_status

echo Written to $OUT
printf "\n"

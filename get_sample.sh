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
    exit 0
fi

CASE=$1

if [ -z $GDC_TOKEN ]; then
    >&2 GDC_TOKEN environment variable not defined.  Quitting.
    exit 1
fi
 

function sample_from_case_query {
CASE=$1 # E.g C3L-00004
cat <<EOF
{
    sample(with_path_to: {type: "case", submitter_id:"$CASE"})
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


OUTD="dat/$CASE"
mkdir -p $OUTD
OUT="$OUTD/sample_from_case.$CASE.dat"

Q=$(sample_from_case_query $CASE)

>&2 echo QUERY: $Q

#R=$(echo $Q | queryGDC -r -v -t $TOKEN -)
R=$(echo $Q | $QUERYGDC -r -v -)

echo $R | jq -r '.data.sample[] | "\(.submitter_id)\t\(.id)\t\(.sample_type)"' > $OUT

echo Written to $OUT
printf "\n"

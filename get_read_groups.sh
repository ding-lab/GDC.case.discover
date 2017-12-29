# Given a case, process all entries in samples_from_case data file, and obtain all read groups associated
# with each entry

if [ "$#" -ne 1 ]; then
    echo Error: Wrong number of arguments
    echo Usage: get_read_groups.sh CASE 
    exit
fi

CASE=$1
if [ -z $GDC_TOKEN ]; then
    >&2 GDC_TOKEN environment variable not defined.  Quitting.
    exit 1
fi

function read_group_from_sample_query {
    SAMPLE=$1 # E.g C3L-00004-31
    cat <<EOF
    {
        read_group(with_path_to: {type: "sample", submitter_id:"$SAMPLE"}, first:1000)
        {
            submitter_id
            library_strategy
            experiment_name
            target_capture_kit_target_region
        }
    }
EOF
}

if [ -z $QUERYGDC_HOME ]; then
    QUERYGDC_HOME="./queryGDC"
    >&2 echo QUERYGDC_HOME not set, using default ./queryGDC
fi
QUERYGDC="$QUERYGDC_HOME/queryGDC"


DAT="dat/$CASE/sample_from_case.$CASE.dat"
OUTD="dat/$CASE"
mkdir -p $OUTD
OUT="$OUTD/read_group_from_case.$CASE.dat"
rm -f $OUT

>&2 echo Reading $DAT

while read L; do
# sample line
# C3L-00561-31	a19a4c9e-9421-4473-a1d1-78b066504679	Blood Derived Normal

    SAMPLE=$(echo "$L" | cut -f 1)

    Q=$(read_group_from_sample_query $SAMPLE)

    >&2 echo QUERY: $Q

    R=$(echo $Q | $QUERYGDC -r -v -)

    echo $R | jq -r '.data.read_group[] | "\(.submitter_id)\t\(.library_strategy)\t\(.experiment_name)\t\(.target_capture_kit_target_region)"' | sed "s/^/$SAMPLE\t/" >> $OUT

    printf "\n"

done < $DAT

echo Written to $OUT
printf "\n"

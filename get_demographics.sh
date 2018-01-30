# Get demographics information about all cases in given cases file
# Writes one line per CASE to stdout

if [ "$#" -ne 1 ]; then
    echo Error: Wrong number of arguments
    echo Usage: get_demographics.sh CASE_FILE 
    exit
fi

CASES=$1
if [ -z $GDC_TOKEN ]; then
    >&2 GDC_TOKEN environment variable not defined.  Quitting.
    exit 1
fi

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

if [ -z $QUERYGDC_HOME ]; then
    QUERYGDC_HOME="./queryGDC"
    >&2 echo QUERYGDC_HOME not set, using default ./queryGDC
fi
QUERYGDC="$QUERYGDC_HOME/queryGDC"

# print header
printf "# case\tdisease\tethnicity\tgender\trace\tdays_to_birth\n"

# Loop over all case names in file $CASES
while read L; do

    [[ $L = \#* ]] && continue  # Skip commented out entries

    CASE=$(echo "$L" | cut -f 1 )
    DIS=$(echo "$L" | cut -f 2 )

    Q=$(demo_from_case_query $CASE)
    R=$(echo $Q | $QUERYGDC -r -)
    LINE=$(echo $R | jq -r '.data.demographic[] | "\(.ethnicity)\t\(.gender)\t\(.race)\t\(.days_to_birth)"')

    printf "$CASE\t$DIS\t$LINE\n" 

done < $CASES


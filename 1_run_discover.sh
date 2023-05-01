PY="src/GDC_Catalog.py"

DIR=`readlink -f .`

# Using file
CASES_FN="/home/mwyczalk_test/Projects/Catalog3/GDAN.catalog/Catalog3/HCMI.Cases.tsv"
CASES=$(cut -f 1 $CASES_FN | tr '\n' ' ')
#ARGS="$ARGS -i $CASES_FN"

#CASES="26OV013"

OUTD="dat"
mkdir -p $OUTD
OUTABS="$DIR/$OUTD/HCMI.Catalog-REST.tsv"

#OUTABS=$(readlink -f $OUT)

#    parser.add_argument("-t", "--token", help="Read token from file and pass as argument in query")
#    parser.add_argument("-e", "--url", default="https://api.gdc.cancer.gov/", help="Define query endpoint url")

# for AWG access
# files_endpt = "https://api.awg.gdc.cancer.gov/files"
# Using AWG token (not regular GDC token)

#TOKEN="/diskmnt/Projects/cptac_scratch/CPTAC3.workflow/discover/token/gdc-user-token.2023-03-29T18_56_03.485Z-AWG-mod.txt"
# Put token in config
TOKEN="$PWD/config/gdc-user-token.2023-05-01T19_43_50.254Z-AWG.txt"
# Note, the URL must end with /
AWG_ARGS="--url https://api.awg.gdc.cancer.gov/ --token $TOKEN"


ARGS="$ARGS -o $OUTABS -s 100000 -C full $AWG_ARGS"

# Debug flag
ARGS="$ARGS"

CMD="bash python3_gdc $PY $@ $ARGS $CASES"
>&2 echo Running: $CMD
eval $CMD


if [ $? -eq 0 ]; then
    >&2 echo Success.  
fi



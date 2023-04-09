PY="src/GDC_Catalog.py"

PWD=`readlink -f .`

# Using file
CASES_FN="/home/mwyczalk_test/Projects/Catalog3/GDAN.catalog/Catalog3/DLBCL.Cases.tsv"
CASES=$(cut -f 1 $CASES_FN | tr '\n' ' ')
#ARGS="$ARGS -i $CASES_FN"

#CASES="26OV013"

OUTD="dat"
mkdir -p $OUTD
OUTABS="$PWD/$OUTD/DLBCL.GDC_REST.20230329-AWG.tsv"

#OUTABS=$(readlink -f $OUT)

#    parser.add_argument("-t", "--token", help="Read token from file and pass as argument in query")
#    parser.add_argument("-e", "--url", default="https://api.gdc.cancer.gov/", help="Define query endpoint url")

# for AWG access
# files_endpt = "https://api.awg.gdc.cancer.gov/files"
# Using AWG token (not regular GDC token)

#TOKEN="/diskmnt/Projects/cptac_scratch/CPTAC3.workflow/discover/token/gdc-user-token.2023-03-29T18_56_03.485Z-AWG-mod.txt"
TOKEN="/home/mwyczalk_test/Projects/Catalog3/discovery/26.DLBCL-REST.20230328/dat/gdc-user-token.2023-03-29T19_23_28.783Z-AWG.txt"
# Note, the URL must end with /
AWG_ARGS="--url https://api.awg.gdc.cancer.gov/ --token $TOKEN"


ARGS="$ARGS -o $OUTABS -s 100000 -C full $AWG_ARGS"

# Debug flag
ARGS="$ARGS"

bash python3_gdc $PY $@ $ARGS $CASES

if [ $? -eq 0 ]; then
    >&2 echo Success.  
fi



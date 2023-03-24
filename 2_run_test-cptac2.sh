PY="src/GDC_Catalog.py"

PWD=`readlink -f .`

# Using file
CASES_FN="$PWD/dat/CPTAC2.Cases.dat"
ARGS="$ARGS -i $CASES_FN"

#CASES=" 26OV013"

OUTD="dat"
mkdir -p $OUTD
OUTABS="$PWD/$OUTD/CPTAC2.Catalog-GDCAPI-import.tsv"

#OUTABS=$(readlink -f $OUT)

ARGS="$ARGS -o $OUTABS -s 100000 -C import"

# Debug flag
ARGS="$ARGS"

bash python3_gdc $PY $@ $ARGS $CASES

if [ $? -eq 0 ]; then
    >&2 echo Success.  
fi



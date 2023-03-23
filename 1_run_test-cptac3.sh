PY="src/GDC_Catalog.py"

PWD=`readlink -f .`

# Using file
CASES_FN="$PWD/dat/CPTAC2.Cases.dat"
ARGS="$ARGS -i $CASES_FN"

OUTD="dat-test"
mkdir -p $OUTD
OUTABS="$PWD/$OUTD/CPTAC-4cases.testB.tsv"

#OUTABS=$(readlink -f $OUT)

ARGS="$ARGS -o $OUTABS"

# Debug flag
ARGS="$ARGS"

bash python3_gdc $@ $PY $ARGS 

if [ $? -eq 0 ]; then
    >&2 echo Success.  
fi



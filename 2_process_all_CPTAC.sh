# Perform discovery for all cases in CASES file

# This needs to be exported, to be visible to GDC Query scripts
export GDC_TOKEN="../token/gdc-user-token.2022-03-03T16_20_37.493Z.txt"
PROJECT="DLBCL"  # Administrative project associated with these cases
CASES="/home/mwyczalk_test/Projects/Catalog3/GDAN.catalog/Catalog3/DLBCL.cases.tsv"

# Data model.  See src/get_aliquots.py for details
# * CPTAC for CPTAC projects
# * TCGA for various GDAN projects
DATA_MODEL="CPTAC"
#DATA_MODEL="TCGA"

# With vvv each step outputs query details, fewer limits output
VERBOSE="-vvv"

# N determines how many discovery processes run at once
N="-J 5"

# Make sure that src/bashids/bashids exists.  This should be tested for in the code but for now make it easy
# May need to do `git submodule init; git submodule update`
BID="src/bashids/bashids"
if [ ! -x $BID ]; then
    >&2 echo ERROR: $BID does not exist or is not executable
fi

##############################
# Output directories.  Traditionally, all output went in ./dat,
# including the runtime output directories and the final catalog and demographics
# files.  For TCGA and CPTAC data model runs,
# Keep the runtime files separate, but put the final results in the same
# directory (./dat)

DESTD="./results"
CATALOG="$DESTD/${PROJECT}.Catalog3_${DATA_MODEL}.tsv"
DEMOGRAPHICS="$DESTD/${PROJECT}.Demographics.tsv"
LOGBASE="./logs_${DATA_MODEL}"

mkdir -p $DESTD
mkdir -p $LOGBASE

START=$(date)
>&2 echo [ $START ] Starting discovery
CMD="bash src/process_multi_cases.sh -L $LOGBASE $N -m $DATA_MODEL -o $CATALOG -D $DEMOGRAPHICS $VERBOSE $@ $CASES $PROJECT"
echo Running: $CMD
eval "$CMD"
rc=$?
if [[ $rc != 0 ]]; then
    >&2 echo ERROR $rc: $!
    exit $rc;
fi


END=$(date)
>&2 echo [ $END ] Discovery complete

OUTD="$LOGBASE/outputs" # must match value in src/process_multi_cases.sh
NERR=$(grep -il error $OUTD/*/*log* | wc -l)
if grep -q -i error $OUTD/*/*log* ; then
    >&2 echo The following $NERR files had errors \(top 10 shown\):
    grep -il error $OUTD/*/*log* | head
fi
NWRN=$(grep -il warning $OUTD/*/*log* | wc -l)
if grep -q -i warning $OUTD/*/*log* ; then
    >&2 echo The following $NWRN files had warnings \(top 10 shown\):
    grep -il warning $OUTD/*/*log* | head
fi

>&2 echo Timing summary: 
>&2 echo Discovery start: [ $START ]  End: [ $END ]


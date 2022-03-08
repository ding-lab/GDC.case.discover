# Perform discovery for all cases in CASES file

# This needs to be exported, to be visible to GDC Query scripts
export GDC_TOKEN="../token/gdc-user-token.2022-03-03T16_20_37.493Z.txt"
PROJECT="TCGA_DLBCL"  # Administrative project associated with these cases
#CASES="/home/mwyczalk_test/Projects/CPTAC3/CPTAC3.catalog/CPTAC3.cases.dat"
#CASES="dat/cases-1-TCGA.dat"
CASES="dat/cases-1.dat"

# Data model.  See src/get_aliquots.py for details
# * CPTAC3 for CPTAC3 projects
# * TCGA for various GDAN projects
#DATA_MODEL="CPTAC3"
DATA_MODEL="TCGA"

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
CATALOG="dat/Catalog.dat"
DEMOGRAPHICS="dat/Demographics.dat"

mkdir -p dat

START=$(date)
>&2 echo [ $START ] Starting discovery
#bash src/process_multi_cases.sh -s $SUFFIX_LIST $N -o $CATALOG -D $DEMOGRAPHICS $VERBOSE $@ $CASES
CMD="bash src/process_multi_cases.sh $N -m $DATA_MODEL -o $CATALOG -D $DEMOGRAPHICS $VERBOSE $@ $CASES $PROJECT"
echo Running: $CMD
eval "$CMD"
rc=$?
if [[ $rc != 0 ]]; then
    >&2 echo ERROR $rc: $!
    exit $rc;
fi


END=$(date)
>&2 echo [ $END ] Discovery complete

# Not doing summary.  Maybe later.  Too many CPTAC3 assumptions
#SUMMARY_OUT="dat/Catalog.Summary.txt"
#rm -f $SUMMARY_OUT
#bash src/summarize_cases.sh $@ -o $SUMMARY_OUT $CATALOG $CASES
#END2=$(date)
#>&2 echo [ $END2 ] Summary complete

OUTD="./dat/outputs" # must match value in src/process_multi_cases.sh
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


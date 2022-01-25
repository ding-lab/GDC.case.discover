# Perform discovery for all cases in CASES file

# This needs to be exported, to be visible to GDC Query scripts
export GDC_TOKEN="/diskmnt/Projects/cptac_scratch/CPTAC3.workflow/discover/token/gdc-user-token.2022-01-05T22_45_39.319Z.txt"
PROJECT="TCGA_GDC"  # Administrative project associated with these cases

#CASES="/home/mwyczalk_test/Projects/CPTAC3/CPTAC3.catalog/CPTAC3.cases.dat"
CASES="dat/cases_disease.dat"
#CASES="dat/cases_disease-1.dat"


# add suffix to sample names based on aliquot
#SUFFIX_LIST="/home/mwyczalk_test/Projects/CPTAC3/CPTAC3.catalog/SampleRename.dat"

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
CMD="bash src/process_multi_cases.sh $N -o $CATALOG -D $DEMOGRAPHICS $VERBOSE $@ $CASES $PROJECT"
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


NERR=$(grep -il error dat/cases/*/*log* | wc -l)
if grep -q -i error dat/cases/*/*log* ; then
    >&2 echo The following $NERR files had errors \(top 10 shown\):
    grep -il error dat/cases/*/*log* | head
fi
NWRN=$(grep -il warning dat/cases/*/*log* | wc -l)
if grep -q -i warning dat/cases/*/*log* ; then
    >&2 echo The following $NWRN files had warnings \(top 10 shown\):
    grep -il warning dat/cases/*/*log* | head
fi

>&2 echo Timing summary: 
>&2 echo Discovery start: [ $START ]  End: [ $END ]


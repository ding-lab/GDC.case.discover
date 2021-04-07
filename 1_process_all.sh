# Perform discovery for all cases in CASES file

# This needs to be exported, to be visible to GDC Query scripts
export GDC_TOKEN="/home/mwyczalk_test/Projects/CPTAC3/discovery/token/gdc-user-token.2021-04-05T14_41_30.055Z.txt"

PROJECT="discover.20210407"
CASES="/home/mwyczalk_test/Projects/CPTAC3/CPTAC3.catalog/CPTAC3.cases.dat"
#CASES="dat/cases-test.dat"

# add suffix to sample names based on aliquot
SUFFIX_LIST="/home/mwyczalk_test/Projects/CPTAC3/CPTAC3.catalog/SampleRename.dat"

# With vvv each step outputs query details, fewer limits output
VERBOSE="-vvv"

# N determines how many discovery processes run at once
N="-J 20"

# Make sure that src/bashids/bashids exists.  This should be tested for in the code but for now make it easy
# May need to do `git submodule init; git submodule update`
BID="src/bashids/bashids"
if [ ! -x $BID ]; then
    >&2 echo ERROR: $BID does not exist or is not executable
fi

##############################
CATALOG="dat/${PROJECT}.Catalog.dat"
DEMOGRAPHICS="dat/${PROJECT}.Demographics.dat"

mkdir -p dat

START=$(date)
>&2 echo [ $START ] Starting discovery
bash src/process_multi_cases.sh -s $SUFFIX_LIST $N -o $CATALOG -D $DEMOGRAPHICS $VERBOSE $@ $CASES

END=$(date)
>&2 echo [ $END ] Discovery complete, starting summary

SUMMARY_OUT="dat/${PROJECT}.Catalog.Summary.txt"
rm -f $SUMMARY_OUT
bash src/summarize_cases.sh $@ -o $SUMMARY_OUT $CATALOG $CASES

END2=$(date)
>&2 echo [ $END2 ] Summary complete


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
>&2 echo Summary start: [ $END ]  End: [ $END2 ]


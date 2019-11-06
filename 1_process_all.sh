# Perform discovery for all cases in CASES file

# This needs to be exported, to be visible to GDC Query scripts
export GDC_TOKEN="/home/mwyczalk_test/Projects/CPTAC3/discovery/token/gdc-user-token.2019-11-04T03_11_17.182Z.txt"

PROJECT="discover.20191104"
#CASES="/home/mwyczalk_test/Projects/CPTAC3/CPTAC3.catalog/CPTAC3.cases.dat"
CASES="dat/cases-test.dat"

# add suffix to sample names based on aliquot
SUFFIX_LIST="/home/mwyczalk_test/Projects/CPTAC3/CPTAC3.catalog/SampleRename.dat"

# With vvv each step outputs query details, fewer limits output
VERBOSE="-vvv"

# N determines how many discovery processes run at once
#N="-J 10"

##############################

mkdir -p dat

NOW=$(date)
>&2 echo [ $NOW ] Starting discovery
bash src/process_multi_cases.sh -s $SUFFIX_LIST $N -o dat/${PROJECT}.AR.dat -D dat/${PROJECT}.Demographics.dat $VERBOSE $@ $CASES

NOW=$(date)
>&2 echo [ $NOW ] Discovery complete

NERR=$(grep -il error dat/cases/*/*log* | wc -l)
if grep -q -i error dat/cases/*/*log* ; then
    >&2 echo The following $NERR files had errors or warnings \(top 10 shown\):
    grep -il error dat/cases/*/*log* | head
fi


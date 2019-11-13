# NOTE: this probably does not need to be run, doing catalog summary
# creation in step 1.  


PROJECT="discover.20191111"
CASES="/home/mwyczalk_test/Projects/CPTAC3/CPTAC3.catalog/CPTAC3.cases.dat"
#CASES="dat/cases-test.dat"
CATALOG="dat/${PROJECT}.Catalog.dat"

SUMMARY_OUT="dat/${PROJECT}.Catalog.Summary.txt"
rm -f $SUMMARY_OUT
bash src/summarize_cases.sh $@ -o $SUMMARY_OUT $CATALOG $CASES
rc=$?
if [[ $rc != 0 ]]; then
    >&2 echo Fatal ERROR $rc: $!.  Exiting.
    exit $rc;
fi



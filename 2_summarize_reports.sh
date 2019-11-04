
PROJECT="discover.20191103"
AR="dat/${PROJECT}.AR.dat"  
CASES="dat/cases-test.dat"
SUMMARY_OUT="dat/${PROJECT}.file-summary.txt"

rm -f $SUMMARY_OUT
bash src/summarize_cases.sh $@ -o $SUMMARY_OUT $AR $CASES
rc=$?
if [[ $rc != 0 ]]; then
    >&2 echo Fatal ERROR $rc: $!.  Exiting.
    exit $rc;
fi



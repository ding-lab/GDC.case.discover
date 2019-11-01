source discover.paths.sh

SR="dat/${PROJECT}.AR.dat"  # Combined SR and HAR
OUT_SR="dat/${PROJECT}.file-summary.txt"
rm -f $OUT_SR
bash CPTAC3.case.discover/summarize_cases.sh $DISCOVER_CASES $SR $OUT_SR
rc=$?
if [[ $rc != 0 ]]; then
    >&2 echo Fatal ERROR $rc: $!.  Exiting.
    exit $rc;
fi

echo Written to $OUT_SR


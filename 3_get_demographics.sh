source discover.paths.sh

OUT="dat/$PROJECT.Demographics.dat"
bash CPTAC3.case.discover/get_demographics.sh $DISCOVER_CASES > $OUT

rc=$?
if [[ $rc != 0 ]]; then
    >&2 echo Fatal ERROR $rc: $!.  Exiting.
    exit $rc;
fi

echo Written to $OUT



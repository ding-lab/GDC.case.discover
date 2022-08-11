>&2 echo Unimplemented.  See TODO
exit 1

GDC_TOKEN="unused"
PROJECT="CPTAC3"  # Administrative project associated with these cases


# this now excludes stopped cases
CASES="/home/mwyczalk_test/Projects/CPTAC3/CPTAC3.catalog/CPTAC3.cases.dat"

# Making catalog2 using data from previous discovery run
SUFFIX_LIST="/home/mwyczalk_test/Projects/CPTAC3/CPTAC3.catalog/SampleRename.dat"
ARGS="-C -c -s $SUFFIX_LIST"

CMD="bash src/run_discovery.sh $GDC_TOKEN $PROJECT $CASES $ARGS $@"
>&2 echo Running: $CMD
eval $CMD


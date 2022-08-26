source discovery_config.sh

# Making catalog2 using data from previous discovery run
SUFFIX_LIST="/home/mwyczalk_test/Projects/CPTAC3/CPTAC3.catalog/SampleRename.dat"
ARGS="-c -s $SUFFIX_LIST"

CMD="bash src/process_catalog.sh $@ $ARGS $PROJECT $CASES"
>&2 echo Running: $CMD
eval $CMD


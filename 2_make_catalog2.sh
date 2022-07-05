# Perform discovery for all cases in CASES file

GDC_TOKEN="../token/gdc-user-token.2022-06-15T18_08_38.120Z.txt"
PROJECT="DLBCL"  # Administrative project associated with these cases

#CASES="/home/mwyczalk_test/Projects/Catalog3/GDAN.catalog/Catalog3/DLBCL.cases.tsv"
CASES="config/cases-test.dat"

# Making catalog2 using data from previous discovery run
SUFFIX_LIST="/home/mwyczalk_test/Projects/CPTAC3/CPTAC3.catalog/SampleRename.dat"
ARGS="-C -c -s $SUFFIX_LIST"

CMD="bash src/run_discovery.sh $GDC_TOKEN $PROJECT $CASES $ARGS $@"
>&2 echo Running: $CMD
eval $CMD


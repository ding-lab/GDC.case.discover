# Perform discovery for all cases in CASES file

GDC_TOKEN="../token/gdc-user-token.2022-06-15T18_08_38.120Z.txt"
PROJECT="DLBCL"  # Administrative project associated with these cases

# Data model.  See src/get_aliquots.py for details
# * CPTAC for CPTAC projects
# * TCGA for various GDAN projects
# DATA_MODEL="CPTAC"
DATA_MODEL="TCGA"
CASES="/home/mwyczalk_test/Projects/Catalog3/GDAN.catalog/Catalog3/DLBCL.cases.tsv"

CMD="bash src/run_discovery.sh $GDC_TOKEN $PROJECT $DATA_MODEL $CASES $@"
>&2 echo Running: $CMD
eval $CMD


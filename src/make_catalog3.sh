#PYTHON="/diskmnt/Projects/Users/mwyczalk/miniconda3/bin/python"
PYTHON="/Users/mwyczalk/miniconda3/bin/python"

#DATD="/Users/mwyczalk/Projects/CPTAC3/Discovery/dev.TCGA2/CPTAC3.case.discover/data/TCGA-A6-6780"
#DATD="/Users/mwyczalk/Projects/CPTAC3/Discovery/dev.TCGA2/CPTAC3.case.discover/data/TCGA-44-6146"
# C3L-00016 has multiple samples per dataset
# DATD="/Users/mwyczalk/Projects/CPTAC3/Discovery/dev.TCGA2/CPTAC3.case.discover/data/C3L-00016"
# TCGA-A6-5665 has multiple annotations for some datasets
# DATD="/Users/mwyczalk/Projects/CPTAC3/Discovery/dev.TCGA2/CPTAC3.case.discover/data/TCGA-A6-5665"

OUT="catalog3-tmp.tsv"

DATD=$1
if [ ! -d $DATD ]; then >&2 echo ERROR: $DATD does not exist; exit 1; fi

AQ_FN="$DATD/aliquots.dat"
SR_FN="$DATD/submitted_reads.dat"
HR_FN="$DATD/harmonized_reads.dat"

if [ ! -e $AQ_FN ]; then >&2 echo ERROR: $AQ_FN does not exist; exit 1; fi
if [ ! -e $SR_FN ]; then >&2 echo ERROR: $SR_FN does not exist; exit 1; fi
if [ ! -e $HR_FN ]; then >&2 echo ERROR: $HR_FN does not exist; exit 1; fi

#    parser.add_argument("-o", "--output", dest="outfn", help="Output file name")
#    parser.add_argument("-Q", "--aliquots", dest="aliquots_fn", required=True, help="Aliquots file")
#    parser.add_argument("-D", "--disease", dest="disease", default="DISEASE", help="Disease code")
#    parser.add_argument("-P", "--project", dest="project", default="PROJECT", help="Project name")
#    parser.add_argument("-A", "--annotation", dest="annotation_fn", help="Annotation table")
#    parser.add_argument("-d", "--debug", action="store_true", help="Print debugging information to stderr")
#    parser.add_argument("-n", "--no-header", action="store_true", help="Do not print header")

echo SRFN: $SR_FN

CMD="$PYTHON src/make_catalog3.py -Q $AQ_FN -o $OUT $SR_FN"
echo Running: $CMD
eval $CMD

rc=$?
if [[ $rc != 0 ]]; then
    >&2 echo Fatal ERROR $rc: $!.  Exiting.
    exit $rc;
fi



#$PYTHON src/make_catalog3.py $@ -Q $AQ_FN $SR_FN

# Repeat for HR_FN

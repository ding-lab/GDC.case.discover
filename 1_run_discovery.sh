# Perform discovery for all cases in CASES file

source discovery_config.sh

mkdir -p logs
LOGE="logs/1_run_discovery.err"
LOGO="logs/1_run_discovery.out"

NJOBS="5"

CMD="bash src/run_discovery.sh $@ -J $NJOBS -vvv -t $GDC_TOKEN $CASES  > $LOGO 2> $LOGE"
>&2 echo Running: $CMD
>&2 echo Writing logs to $LOGO and $LOGE
eval $CMD


# this makes assumptions about log output.  Better to make discovery less noisy
OUTD="logs/outputs" 
NERR=$(grep -il error $OUTD/*/*log* | wc -l)
if grep -q -i error $OUTD/*/*log* ; then
    >&2 echo The following $NERR files had errors \(top 10 shown\):
    grep -il error $OUTD/*/*log* | head
else
    >&2 echo No errors found
fi
NWRN=$(grep -il warning $OUTD/*/*log* | wc -l)
if grep -q -i warning $OUTD/*/*log* ; then
    >&2 echo The following $NWRN files had warnings \(top 10 shown\):
    grep -il warning $OUTD/*/*log* | head

    # Give examples of warnings found, ignoring trivial ones
    grep -h -i warning $LOGE $LOGO | grep -v "exists. Deleting" | sort -u | head
else
    >&2 echo No warnings found
fi



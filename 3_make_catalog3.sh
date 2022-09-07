source discovery_config.sh

# Making catalog2 using data from previous discovery run
LOGE="logs/process_catalog3.err"
LOGO="logs/process_catalog3.out"

CMD="bash src/process_catalog.sh $@ $PROJECT $CASES > $LOGO 2> $LOGE "
>&2 echo Running: $CMD
>&2 echo Writing logs to $LOGO and $LOGE
eval $CMD

echo ' '
>&2 echo The following errors were observed
grep -h -i error $LOGE $LOGO | sort -u 

echo ' '
>&2 echo The following warnings were observed
# ignoring file exist warnings, whihch are common on reruns
grep -h -i warning $LOGE $LOGO | grep -v "exists. Deleting" | sort -u 



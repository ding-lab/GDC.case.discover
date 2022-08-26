# Perform discovery for all cases in CASES file

source discovery_config.sh

CMD="bash src/run_discovery.sh $@ -J 10 -vvv -t $GDC_TOKEN $CASES "
>&2 echo Running: $CMD
eval $CMD


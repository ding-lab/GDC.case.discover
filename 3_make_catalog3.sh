source discovery_config.sh

CMD="bash src/process_catalog.sh $@ $PROJECT $CASES"
>&2 echo Running: $CMD
eval $CMD


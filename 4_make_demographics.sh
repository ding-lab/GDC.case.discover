source discovery_config.sh

CMD="bash src/process_demographics.sh $@ $PROJECT $CASES"
>&2 echo Running: $CMD
eval $CMD


#!/bin/bash -l

# Execute given GraphQL file as a query to GDC
# Usage: queryGDC.sh [options] query.dat
#
# -t token.txt: define token file; may also be defined by `export GDC_TOKEN=file`.  Default ./gdc-user-token.txt
# -v: print diagnostic information to stderr
# -S: Verbose curl output (turns off `curl -s` flag)
# -r: repeat query in case of timeout errors until succeeds.  Stops on other errors.
# -d: dry run.  Print query but do not execute
# 
# token.txt contains GDC authentication token (see https://docs.gdc.cancer.gov/Data_Submission_Portal/Users_Guide/Authentication/ )
# query.dat contains "bare queryGL" script (see https://docs.gdc.cancer.gov/API/Users_Guide/Submission/#querying-submitted-data-using-graphql )
#       queryGDC - 
#   will read query from STDIN

# Matthew A. Wyczalkowski
# m.wyczalkowski@wustl.edu
# Ding Lab, Washington University School of Medicine

# #########

# Called after running scripts to catch fatal (exit 1) errors
# works with piped calls ( S1 | S2 | S3 > OUT )
# Usage:
#   bash script.sh DATA | python script.py > $OUT
#   test_exit_status # Calls `exit V` if any script in a pipe returns an exit value V which is not 0
function test_exit_status {
    # Evaluate return value for chain of pipes; see https://stackoverflow.com/questions/90418/exit-shell-script-based-on-process-exit-code
    # exit code 137 is fatal error signal 9: http://tldp.org/LDP/abs/html/exitcodes.html
    rcs=${PIPESTATUS[*]};
    for rc in ${rcs}; do
        if [[ $rc != 0 ]]; then
            >&2 echo Fatal error.  Exiting
            exit $rc;
        fi;
    done
}


# usage: run_query QUERY_JSON t
# where t is token string
function run_query {
    QUERY_JSON=$1
    t=$2

    # -s is silent.  It keeps download progress bar from appearing, but also discards warnings.
    if [ -z $CURL_NO_SILENT ]; then
        ARGS="-s $ARGS"
    fi

    URL="https://api.gdc.cancer.gov/v0/submission/graphql"

    if [ $DRYRUN ]; then
        >&2 echo curl $ARGS -XPOST -H \"X-Auth-Token: $t\" $URL --data \"$QUERY_JSON\" 
        >&2 echo Exiting after dry run.
        exit 0
    else
        curl $ARGS -XPOST -H "X-Auth-Token: $t" $URL --data "$QUERY_JSON" 
        test_exit_status 
    fi
}

# Perform query, repeating in case of timeout error until it succeeds.
# Goal is to handle this response:
# R = { "data": {}, "errors": [ "Query exceeded 20.0 second timeout. Please reduce query complexity and try again. Ways to limit query complexity include adding \"first: 1\" arguments to limit results, limiting path query filter usage (e.g. with_path_to), or limiting extensive path traversal field inclusion (e.g. _related_cases)." ] }
# This happens with variable frequency
# We will test for for errors, such as "Unauthorized query.", and quit if encountered.
#
# Another error results in R="<html><head><title>Hold up there!</title></head><body><center><h1>Hold up there!</h1><p>You are posting too quickly. Wait for few moments and try again.</p></body></html>"
# This will result in us waiting 5 seconds before trying again
function run_query_retry {
    QUERY_JSON=$1
    t=$2

    # GDC sometimes returns transient errors.  These are tricky to reproduce.
    R=$(run_query "$QUERY_JSON" "$t")  

    # We validate JSON as recommended here: https://github.com/stedolan/jq/issues/1637
    if jq -e . >/dev/null 2>&1 <<<"$R"; then
        ERR=$(echo $R | jq -r '.errors[]? ')
        test_exit_status
    else
        ERR="ERROR parsing result : $R"
    fi

#    # This is a transiet error and code below not fully tested.
#    if [[ $R = *"You are posting too quickly."* ]]; then
#        ERR="You are posting too quickly."
#    else
#        # Here assume valid JSON.  TODO: test whether JSON is in fact valid
#        ERR=$(echo $R | jq -r '.errors[]? ')
#        test_exit_status
#    fi

    if [ -z "$ERR" ]; then
        if [ $VERBOSE ]; then
            >&2 echo RESULT: $R
        fi
        echo "$R"
    else
        if [ "$ERR" == "Unauthorized query." ]; then
            >&2 echo Fatal error: $ERR
            exit 1
        fi
        if [ "$ERR" == "You are posting too quickly." ]; then
            >&2 echo Posting too quickly error.  Pausing.
            wait 5
        fi
        if [ $VERBOSE ]; then
            >&2 echo ERRORS: $ERR
            >&2 echo Query failed.  Retrying.
        fi
        run_query_retry "$QUERY_JSON" "$t"
    fi
}

function get_json {
    # Creates valid GDC query JSON string based on graphQL data
    # For testing, this content of GQL file works:
    # { sample(with_path_to: {type: "case", submitter_id:"C3L-00004"}) { id submitter_id sample_type } }

    # Escaping, in this context, means converting it to a format that could be
    # parsed as a string.  This involves replacing special characters that could
    # inhibit parsing, such as newline and tab, with escape sequences, which would
    # be "\n" and "\t" respectively.  The following page explains all of the
    # replacement and also has a tool that does this:
    # https://www.freeformatter.com/json-escape.html

    GQL=$1

    PY="import json, sys; query = sys.stdin.read().rstrip(); d = { 'query': query, 'variables': 'null' }; print(json.dumps(d))"

    if [ $GQL == '-' ]; then
        cat - | python -c "$PY"
    else
        python -c "$PY" < $GQL
    fi
    test_exit_status
}

# If GDC_TOKEN not defined by environment variable, set it to default value
if [ -z $GDC_TOKEN ]; then
GDC_TOKEN="gdc-user-token.txt"
fi

while getopts ":t:vrdS" opt; do
  case $opt in
    v)  
      VERBOSE=1
      ;;
    r)  
      REPEAT=1
      ;;
    d)  
      DRYRUN=1
      ;;
    t)
      GDC_TOKEN=$OPTARG
      ;;
    S)  
      CURL_NO_SILENT=1
      ;;
    \?)
      >&2 echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      >&2 echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))


if [ "$#" -ne 1 ]; then
    >&2 echo queryGDC error: Wrong number of arguments
    >&2 echo Usage: queryGDC \[options\] query.dat
    exit 1
fi

if [ $VERBOSE ]; then
    >&2 echo Using token file $GDC_TOKEN
fi

if [ ! -f $GDC_TOKEN ]; then
    >&2 echo Token $GDC_TOKEN not found
    exit 1
fi
T=$(cat $GDC_TOKEN)

GQL=$1
JSON=$(get_json $GQL)  

if [ $REPEAT ]; then
    run_query_retry "$JSON" "$T"
else
    run_query "$JSON" "$T"
fi


#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Start docker container in standard docker or LSF environments with optional mounted volumes
Usage: start_docker.sh [options] [ data_path_1 [ data_path_2 ...] ]

Required options:
-I DOCKER_IMAGE: Specify docker image.  Required.

Options:
-h: show help
-d: dry run.  print out docker statement but do not execute
-M SYSTEM: Available systems: MGI, compute1, docker.  Default: docker
-m MEM_GB: request given memory resources on launch.  Not implemented yet for SYSTEM=docker
-c DOCKER_CMD: run given command in non-interactive mode.  Default is to run /bin/bash in interactive mode
-L LOGD: Log directory on host.  Logs are written to $LOGD/log/RUN_NAME.[err|out] (non-interactive mode).  Default: ./logs
-l: Write all logs to stderr/stdout
-R RUN_NAME: specify base name of log output.  Default is start_docker.TIMESTAMP
-g LSF_ARGS: optional arguments to pass verbatim to bsub.  LSF mode only
-q LSFQ: queue to use when launching LSF command.  Defaults are research-hpc for SYSTEM = MGI;
   for SYSTEM = compute1, queue is general-interactive and general for interactive and non-interactive jobs, respectively
-P: Set LSF_DOCKER_PRESERVE_ENVIRONMENT to false, to prevent mapping of paths on LSF
-e ENV: sent environment variable as passed to `docker --env`.  Can be set multiple times.
    Example: -e VAR1=value1 -e VAR2=value2
    This is not fully implemented, see source for details

One or more data_path arguments will map volumes on docker start.  If data_path is PATH_H:PATH_C,
then PATH_C will map to PATH_H.  If only a single path is given, it is equivalent to PATH_C=PATH_H

General purpose docker launcher with the following features:
* Aware of MGI, compute, docker environments
  - select queue, other defaults accordingly
* Can map arbitrary paths through command line arguments 
* Select through command line arguments
  - memory
  - image
  - dryrun
  - run bash or given command line
  - arbitrary LSF arguments
  - environment variables
EOF

# Note on -e ENV flag
#  Docker implementation based on documentation here:
#    https://docs.docker.com/engine/reference/commandline/run/#set-environment-variables--e---env---env-file
#  has not yet been defined for LSF.  Suggestion about env params on LSF from Tom Mooney:
#    If you don’t use LSF_DOCKER_PRESERVE_ENVIRONMENT=false, the LSF job will inherit all of your current environment variables
#   Follow implementation like that for e.g., export LSF_DOCKER_NETWORK=host

# NOTE: if the documentation above is updated, please update README.md as well

function test_exit_status {
    # Evaluate return value for chain of pipes; see https://stackoverflow.com/questions/90418/exit-shell-script-based-on-process-exit-code
    rcs=${PIPESTATUS[*]};
    for rc in ${rcs}; do
        if [[ $rc != 0 ]]; then
            NOW=$(date)
            >&2 echo [ $NOW ] $SCRIPT Fatal ERROR \($rc\).  Exiting.
            exit $rc;
        fi;
    done
}

function confirm {
    FN=$1
    WARN=$2
    NOW=$(date)
    if [ ! -s $FN ]; then
        if [ -z $WARN ]; then
            >&2 echo [ $NOW ] ERROR: $FN does not exist or is empty
            exit 1
        else
            >&2 echo [ $NOW ] WARNING: $FN does not exist or is empty.  Continuing
        fi
    fi
}

# Evaluate given command CMD either as dry run or for real with
#     CMD="tabix -p vcf $OUT"
#     run_cmd "$CMD"
function run_cmd {
    CMD=$1
    DRYRUN=$2

    NOW=$(date)
    if [ "$DRYRUN" ]; then
        >&2 echo [ $NOW ] Dryrun: $CMD
    else
        >&2 echo [ $NOW ] Running: $CMD
        eval $CMD
        test_exit_status
        NOW=$(date)
        >&2 echo [ $NOW ] Completed successfully
    fi
}

SCRIPT=$(basename $0)
LSF_ARGS=""
DOCKER_CMD="/bin/bash"
INTERACTIVE=1
SYSTEM="docker"
LOGD="./logs"
TIMESTAMP=$(date "+%Y.%m.%d-%H.%M.%S")
RUN_NAME="start_docker.$TIMESTAMP"
DOCKER_ARGS=""

BSUB="bsub"
DOCKER="docker"

while getopts ":I:hdM:m:L:c:g:q:R:Pe:l" opt; do
  case $opt in
    I)
      DOCKER_IMAGE="$OPTARG"
      ;;    
    h)
      echo "$USAGE"
      exit 0
      ;;
    d) 
      DRYRUN="d"  
      ;;
    M)  
      SYSTEM="$OPTARG"
      ;;
    m)  
      MEM_GB="$OPTARG"
      ;;
    L)  
      LOGD=$OPTARG
      ;;
    c)
      DOCKER_CMD="$OPTARG"
      INTERACTIVE=0
      ;;    
    g)
      LSF_ARGS="$LSF_ARGS $OPTARG"
      ;;
    q)  
      LSFQ="$OPTARG"
      ;;
    R)  
      RUN_NAME="$OPTARG"
      ;;
    P)
      PRE_CMD="export LSF_DOCKER_PRESERVE_ENVIRONMENT=false"
      ;;
    l)
      WRITE_LOGS=0
      ;;
    e)  
      # https://docs.docker.com/engine/reference/commandline/run/#set-environment-variables--e---env---env-file
      # for docker, just add additional arguments
      DOCKER_ARGS="$DOCKER_ARGS --env $OPTARG"
      # for LSF implementation, add environment variables...
      # this needs to be adjusted for multiple....  continue implemenation here
      LSF_ENV="export $OPT_ARG"
      ;;
    \?)
      >&2 echo "$SCRIPT: ERROR. Invalid option: -$OPTARG" >&2
      >&2 echo "$USAGE"
      exit 1
      ;;
    :)
      >&2 echo "$SCRIPT: ERROR. Option -$OPTARG requires an argument." >&2
      >&2 echo "$USAGE"
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

if [ -z $DOCKER_IMAGE ]; then
    >&2 echo Error: Docker image \(-I\) not specified
    >&2 echo "$USAGE"
    exit 1
fi

if [ $SYSTEM == "docker" ]; then
    LSFQ_DEFAULT=""
    IS_LSF=0
elif [ $SYSTEM == "MGI" ]; then
    LSFQ_DEFAULT="-q research-hpc"  
    IS_LSF=1
elif [ $SYSTEM == "compute1" ]; then
    if [ "$INTERACTIVE" == 1 ]; then
        LSFQ_DEFAULT="-q general-interactive"  
    else
        LSFQ_DEFAULT="-q general"  
    fi
    IS_LSF=1
else
    >&2 echo ERROR: Unknown SYSTEM: $SYSTEM
    >&2 echo "$USAGE"
    exit 1
fi
if [ $IS_LSF == 1 ] && [ -z $LSFQ ]; then
    LSFQ=$LSFQ_DEFAULT
fi

if [ $MEM_GB ]; then
    if [ $IS_LSF == 1 ]; then
        SELECT="select[mem>$(( $MEM_GB * 1000 ))] rusage[mem=$(( $MEM_GB * 1000 ))]";
        # -M argument takes kb at MGI, mb in compute1
        if [ $SYSTEM == "MGI" ]; then 
            M_ARG=$(( $MEM_GB * 1000000 ))
        else 
            M_ARG=$(( $MEM_GB * 1000 ))
        fi
        MEM_ARGS="-M $M_ARG -R \"$SELECT\""
    else
        >&2 echo WARNING: MEM_GB not implemented yet for system = docker.  Ignoring 
        MEM_ARGS=""
    fi
fi

# Interactive jobs write logs unless overridden with -l
if [ -z $WRITE_LOGS ]; then
    if [ "$INTERACTIVE" == 0 ]; then
        WRITE_LOGS=1
    else
        WRITE_LOGS=0
    fi
fi

PATH_MAP=""
# Loop over all arguments, host directories which will be mapped to container directories
for DP in "$@"
do
    # Each data path DP consists of one or two paths separated by :
    # If 2 paths, they are PATH_H:PATH_C
    # If 1 path, define PATH_C = PATH_H
    PATH_H=$(echo "$DP" | cut -f 1 -d : -s)
    PATH_C=$(echo "$DP" | cut -f 2 -d : -s)

    # cut -s supresses output of lines with no matching delimiters
    # In this case, assume 1 path specified
    if [ -z $PATH_H ]; then
        PATH_H="$DP"
    fi

    if [ ! -d $PATH_H ]; then
        >&2 echo ERROR: $PATH_H is not an existing directory
        exit 1
    fi

    # Using python to get absolute path of DATDH.  On Linux `readlink -f` works, but on Mac this is not always available
    # see https://stackoverflow.com/questions/1055671/how-can-i-get-the-behavior-of-gnus-readlink-f-on-a-mac
    ABS_PATH_H=$(python -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' $PATH_H)

    if [ -z $PATH_C ]; then
        PATH_C=$ABS_PATH_H
    fi

    >&2 echo Mapping $PATH_C to $ABS_PATH_H
    if [ $IS_LSF == 1 ]; then
        PATH_MAP="$PATH_MAP $ABS_PATH_H:$PATH_C"
    else
        PATH_MAP="$PATH_MAP -v $ABS_PATH_H:$PATH_C"
    fi 
done

if [ $WRITE_LOGS == 1 ]; then
    run_cmd "mkdir -p $LOGD" $DRYRUN
    test_exit_status
    ERRLOG="$LOGD/${RUN_NAME}.err"
    OUTLOG="$LOGD/${RUN_NAME}.out"
    >&2 echo Output logs written to: $OUTLOG and $ERRLOG
    rm -f $ERRLOG $OUTLOG

    if [ $IS_LSF == 1 ]; then
        LSF_LOGS="-e $ERRLOG -o $OUTLOG"
    else
        LOG_REDIRECT="> $OUTLOG 2> $ERRLOG"
    fi
fi

# This is the command that will execute on docker
if [ $INTERACTIVE == 1 ]; then
    if [ $IS_LSF == 1 ]; then
        LSF_ARGS="$LSF_ARGS -Is"
    else
        DOCKER_ARGS="$DOCKER_ARGS -it"
    fi
fi

if [ $IS_LSF == 1 ]; then
    if [ "$PRE_CMD" ]; then
        PRE_CMD="&& $PRE_CMD"
    fi
    ECMD="export LSF_DOCKER_NETWORK=host && export LSF_DOCKER_VOLUMES=\"$PATH_MAP\" $PRE_CMD"
    run_cmd "$ECMD" $DRYRUN
    DCMD="$BSUB $LSFQ $LSF_ARGS $LSF_LOGS $MEM_ARGS -a \"docker($DOCKER_IMAGE)\" $DOCKER_CMD "
else
    DCMD="$DOCKER run $DOCKER_ARGS $PATH_MAP $DOCKER_IMAGE $DOCKER_CMD $LOG_REDIRECT"
fi

run_cmd "$DCMD" $DRYRUN

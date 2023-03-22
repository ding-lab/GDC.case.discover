# WUDocker

Utilities for launching docker in various systems at Washington University:
* Default docker installations
* LSF docker installations
  * MGI
  * compute1

## Usage
```
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
-R RUN_NAME: specify base name of log output.  Default is start_docker.TIMESTAMP
-g LSF_ARGS: optional arguments to pass verbatim to bsub.  LSF mode only
-q LSFQ: queue to use when launching LSF command.  Defaults are research-hpc for SYSTEM = MGI;
   for SYSTEM = compute1, queue is general-interactive and general for interactive and non-interactive jobs, respectively
-P: Set LSF_DOCKER_PRESERVE_ENVIRONMENT to false, to prevent mapping of paths on LSF

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
```

## Contact

Matt Wyczalkowski (m.wyczalkowski@wustl.edu)



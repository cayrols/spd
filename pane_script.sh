#!/bin/bash

# Used to avoid errors when executed.
set -euo pipefail

TRUE=1
FALSE=0

PIPE_MODE=1
GDB_MODE=2

DEV_MODE=${TRUE}
DEV_MODE=${FALSE}
VERBOSE=${FALSE}
VERBOSE=${TRUE}

main() {
  local input_params=$@
  local pipe=/dev/fd/1
  
  parse_param ${input_params[@]}
  
  if [ ${MODE} -eq ${PIPE_MODE} ]; then
    pipe=${LOCAL_FIFOS}/fifo_${PIPE_ID}
    launch_pipe_listening ${pipe}
  elif [ ${MODE} -eq ${GDB_MODE} ]; then
    launch_gdb $HOST $PORT
  fi
}

################################################################################
#                                  FUNCTIONS                                  #
################################################################################

decho() {
  if [ "${DEV_MODE:-${FALSE}}" -eq "${TRUE}" \
    -o "${VERBOSE:-${FALSE}}" -eq "${TRUE}" ]; then
    echo "$@"
  fi 
}

chelp() {
  bold "TODO FINISH IT"
  bold "TODO FINISH IT"
  bold "TODO FINISH IT"
  echo -e "\t\t\t\tGeneral Commands Manual\t\t\t\t"
  bold    "NAME"
  echo -e "\t$0 - splits ranks or connects (some) to the gdbserver."
  bold    "SYNOPSIS"
  echo -e "\t$0 [OPTIONS] --run <commandline>"
  bold    "\t--run <commandline>"
  echo -e "\t\tThe commandline as used for gdb"
  bold    "OPTIONS"
  bold    "\t--gdb"
  echo -e "\t\tTurn on the gdb for all ranks. Can be overwritten by splittingRanks."
  bold    "\t--split"
  echo -e "\t\tTurn on the split for all ranks. Can be overwritten by debuggingRanks."
  bold    "\t--port <int>"
  echo -e "\t\tThe port used by to connect to the gdbserver."
  echo -e "\t\tEach MPI process is associated with this port + MPI_rank."
  bold    "\t--debuggingRanks <int,...>"
  echo -e "\t\tTurn on the debugging for the associated ranks"
  bold    "\t--splittingRanks <int,...>"
  echo -e "\t\tTurn on the splitting for the associated ranks"
  bold "TODO FINISH IT" # XXX
  bold    "DESCRIPTION"
  echo -e "\tNone"
  bold    "OPTIONS"
}

parse_param() {
  local desc="Parse the input parameters."
  while [ $# -gt 0 ]; do
    case $1 in
      -h | --help )
        chelp $(basename $0)
        exit 0
        ;;
      --gdb)
        shift
        MODE=${GDB_MODE}
        ;;
      --gdb_exec)
        shift
        GDB_EXEC=$1
        shift
        ;;
      --gdb_params)
        shift
        local raw_params=""
        local argv=""
        while [ $# -gt 0 ]; do
          argv="$1"
          if [ ${argv} == "--host" -o ${argv} == "--port" -o ${argv} == "--run" ]; then
            break
          fi
          raw_params+=" ${argv}"
          shift                                                                   
        done 
        GDB_PARAMS=${raw_params}
        ;;
      --host)
        shift
        HOST=$1
        shift
        ;;
      --port)
        shift
        PORT=$1
        shift
        ;;
      --pipe)
        shift
        MODE=${PIPE_MODE}
        ;;
      --pipe_dir)
        shift
        LOCAL_FIFOS=$1
        shift
        ;;
      --pipe_id)
        shift
        PIPE_ID=$1
        shift
        ;;
      --run)
        shift
        CMD=$*
        break
        ;;
      --dev) #Intent to be removed
        shift
        DEV_MODE=${TRUE}
        ;;
      *)
        echo "$1 unknown argument" 1
        shift
        ;;
    esac
  done
}

launch_pipe_listening() {
  local desc="This function listens and prints the content "
    desc+="of the pipe given in parameter."
  local pipe=$1

  if [ ! -e ${pipe} ]; then
    pipe=/dev/fd/1
  fi

  local cpt=0
  if [ ${DEV_MODE} -eq ${FALSE} ]; then
    while true; do 
      echo -e "\n******************* Start run $cpt\n"
      while IFS= read -r line; do
        if [ "${line}" == "__PIPE_STOP__" ]; then
          break 2
        fi
        echo ${line}
      done < ${pipe}
      cpt=$(( cpt + 1))
    done
  fi
}

launch_gdb() {
  local desc="This function starts gdb with the parameters given in input."
  local host=$1
  local port=$2
  local remote=${host}:${port}

  # XXX How to pass GDB_ADDITIONAL_CMD?
  decho ${GDB_EXEC} ${GDB_PARAMS} -ex \'"target remote ${host}:${port}"\' ${GDB_ADDITIONAL_CMD-} --args ${CMD}
  if [ ${DEV_MODE} -eq ${FALSE} ]; then
    ${GDB_EXEC} ${GDB_PARAMS} -ex 'target remote '${host}:${port}'' ${GDB_ADDITIONAL_CMD-} --args ${CMD}
  fi
}

main "$@"

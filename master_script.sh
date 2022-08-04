#!/bin/bash

TRUE=1
FALSE=0

START_SERVER=$FALSE
SPLIT_OUTPUT=$FALSE

DEV_MODE=$TRUE
DEV_MODE=$FALSE
VERBOSE=${TRUE}

main() {
  local input_params=$@

  get_world_rank
  
  parse_param ${input_params[@]}

  if [ ${START_SERVER} -eq ${TRUE} ]; then
    local gdb_port=$(( PORT + ${WORLD_RANK} ))
    decho "GDB server for rank ${WORLD_RANK} available on port ${gdb_port}"
    decho "exec ${GDBSERVER_BIN} ${GDBSERVER_PARAMS} :${gdb_port} ${CMD}"
    if [ "${DEV_MODE}" -eq "${FALSE}" ]; then
      exec ${GDBSERVER_BIN} ${GDBSERVER_PARAMS} :${gdb_port} ${CMD}
    fi
  else
    local fifo_pane_id=1 # = stdout
    if [ ${SPLIT_OUTPUT} -eq ${TRUE} ]; then
      # Assuming that the pipe already exists.
      fifo_pane_id=${LOCAL_FIFOS}/fifo_${WORLD_RANK}
    fi
    
    decho "[${WORLD_RANK}] execute: ${CMD} > ${fifo_pane_id} 2>&1"
    if [ "${DEV_MODE}" -eq "${FALSE}" ]; then
      exec ${CMD} > ${fifo_pane_id} 2>&1
    fi
  fi
}

################################################################################
#                                  FUNCTIONS                                  #
################################################################################

function decho(){
  if [ "${DEV_MODE:-${FALSE}}" -eq "${TRUE}" \
    -o "${VERBOSE:-${FALSE}}" -eq "${TRUE}" ]; then
    echo "$@"
  fi 
}

# This function seeks on the possible patterns in the env to extract the
# world rank.
function get_world_rank() {
  local desc="This functions returns the world rank obtained from printenv."
  local possible_patterns=( OMPI_COMM_WORLD_RANK PMI_RANK )
  local output=$( printenv | grep RANK )
  decho ${output}

  # For each possible patterns
  for possible_pattern in ${possible_patterns[@]}; do
    if [[ ${output} == *"${possible_pattern}"* ]]; then
      decho "Found: ${possible_pattern}"

      # Search env var
      for env_var in ${output}; do
        if [[ ${env_var} == "${possible_pattern}"* ]]; then
          WORLD_RANK=$( echo ${env_var} | cut -d '=' -f 2 )
          break
        fi
      done
      break
    fi
  done

  if [ "${WORLD_RANK}" == "" ]; then
    echo "Error, no world rank found"
    exit 1
  fi
}

function chelp(){
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

function parse_param(){
  local desc="Parse the input parameters. WARNING:"
    desc+="Order matters here?"
  while [ $# -gt 0 ]; do
    case $1 in
      -h | --help )
        chelp $(basename $0)
        exit 0
        ;;
      --gdb)
        shift
        START_SERVER=$TRUE
        SPLIT_OUTPUT=$FALSE # Disable
        ;;
      --split)
        shift
        SPLIT_OUTPUT=$TRUE
        START_SERVER=$FALSE # Disable
        ;;
      --debuggingRanks)
        shift
        START_SERVER=$FALSE
        ranks=( $( echo $1 | tr -s ',' ' ' ) )

        # Check whether world_rank is in the list
        for rank in ${ranks[@]}; do
          if [ ${rank} -eq ${WORLD_RANK} ]; then
            START_SERVER=$TRUE
            # Disable it
            SPLIT_OUTPUT=$FALSE
            break;
          fi
        done
        shift
        ;;
      --splittingRanks)
        shift
        START_SERVER=$FALSE
        ranks=( $( echo $1 | tr -s ',' ' ' ) )

        # Check whether world_rank is in the list
        for rank in ${ranks[@]}; do
          if [ ${rank} -eq ${WORLD_RANK} ]; then
            SPLIT_OUTPUT=$TRUE
            # Disable it
            START_SERVER=$FALSE
            break;
          fi
        done
        shift
        ;;
      --server_bin)
        shift
        GDBSERVER_BIN=$1
        shift
        ;;
      --server_params)
        shift
        GDBSERVER_PARAMS=$1
        shift
        ;;
      --port)
        shift
        PORT=$1
        shift
        ;;
      --pipe_dir)
        shift
        LOCAL_FIFOS=$HOME/.spd/local_fifos # XXX move it
        LOCAL_FIFOS=$1
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

  # TODO check required params
}

main "$@"

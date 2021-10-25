#!/bin/bash
# Usage: debug_server.sh [--debuggingRanks <int,...>] <gdb_server_exec> <gdb_server_params> <default_port> <executable> <arguments>

#GDB_SERVER=$1
#DEFAULT_PORT=$2
#GDB_SERVERPARAMS="--cuda-use-lockfile=0"
TRUE=1
FALSE=0
start_server=$TRUE

# TODO add support for other mpi distrib than OMPI, meaning manage the env var
world_rank=$OMPI_COMM_WORLD_RANK
if [ "$world_rank" == "" ]; then
  echo "Error, no world rank found"
  exit 1
fi

function chelp(){
  bold "TODO FINISH IT"
  bold "TODO FINISH IT"
  bold "TODO FINISH IT"
  echo -e "\t\t\t\tGeneral Commands Manual\t\t\t\t"
  bold    "NAME"
  echo -e "\t$0 - connects to the gdbserver"
  bold    "SYNOPSIS"
  echo -e "\t$0 [OPTIONS] [--noDebug] --server_bin <exec>--port <port> --run <commandline>"
  bold    "\t--port <int>"
  echo -e "\t\tThe port used by to connect to the gdbserver."
  echo -e "\t\tEach MPI process is associated with this port + MPI_rank."
  bold    "\t--run <commandline>"
  echo -e "\t\tThe commandline as used for gdb"
  bold    "\t--debuggingRanks <int,...>"
  echo -e "\t\tTurn on the debugging for the associated ranks"
  bold    "DESCRIPTION"
  echo -e "\tNone"
  bold    "OPTIONS"
}

function parse_param(){
  while [ $# -gt 0 ]; do
    case $1 in
      -h | --help )
        chelp $(basename $0)
        exit 0
        ;;
      --debuggingRanks)
        shift
        start_server=$FALSE
        ranks=( $( echo $1 | tr -s ',' ' ' ) )

        # Check whether world_rank is in the list
        for rank in ${ranks[@]}; do
          if [ $rank -eq $world_rank ]; then
            start_server=$TRUE
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
        DEFAULT_PORT=$1
        shift
        ;;
      --run)
        shift
        CMD=$*
        break
        ;;
      *)
        echo "$1 unknown argument" 1
        shift
        ;;
    esac
  done
}

parse_param "$@"

GDB_HOST=$(hostname) # Do we need the host name ?
GDB_PORT=$(( DEFAULT_PORT + $world_rank ))

if [ $start_server -eq $FALSE ]; then
  echo "[$world_rank] exec $CMD"
  exec $CMD
  exit 0
fi

# Default behavior
echo "GDB server for rank $world_rank available on $GDB_HOST:$GDB_PORT"
echo "exec $GDBSERVER_BIN $GDBSERVER_PARAMS :$GDB_PORT $CMD"
exec $GDBSERVER_BIN $GDBSERVER_PARAMS :$GDB_PORT $CMD
#echo "exec $GDB_SERVER :$GDB_PORT $*"
#exec $GDB_SERVER :$GDB_PORT $*

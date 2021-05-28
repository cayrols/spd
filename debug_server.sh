#!/bin/bash
# Usage: debug_server.sh <default_port> <executable> <arguments>

GDB_SERVER=$1
DEFAULT_PORT=$2
GDB_HOST=$(hostname) # Do we need the host name ?
GDB_PORT=$(( DEFAULT_PORT + $OMPI_COMM_WORLD_RANK ))

# Get rid of the default port in the param list
shift
shift

echo "GDB server for rank $OMPI_COMM_WORLD_RANK available on $GDB_HOST:$GDB_PORT"
#echo "exec $GDB_SERVER --cuda-use-lockfile=0 :$GDB_PORT $*"
#exec $GDB_SERVER --cuda-use-lockfile=0 :$GDB_PORT $*
echo "exec $GDB_SERVER :$GDB_PORT $*"
exec $GDB_SERVER :$GDB_PORT $*

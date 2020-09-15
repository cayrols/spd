#!/bin/bash
# Usage: debug_server.sh <default_port> <executable> <arguments>

DEFAULT_PORT=$1
GDB_HOST=$(hostname) # Do we need the host name ?
GDB_PORT=$(( DEFAULT_PORT + $OMPI_COMM_WORLD_RANK ))

# Get rid of the default port in the param list
shift

echo "GDB server for rank $OMPI_COMM_WORLD_RANK available on $GDB_HOST:$GDB_PORT"
exec gdbserver :$GDB_PORT $*

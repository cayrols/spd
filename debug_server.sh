#!/bin/bash
# Usage: debug_server.sh <executable> <arguments>

GDBSERVER_BIN=/autofs/nccs-svm1_sw/summit/.swci/0-core/opt/spack/20180914/linux-rhel7-ppc64le/gcc-4.8.5/gdb-8.2-wqepjcgazxilipyw7oqoee24dnczbeac/bin
GDB_HOST=$(hostname)
GDB_PORT=$(( 60000 + $OMPI_COMM_WORLD_RANK ))
echo "GDB server for rank $OMPI_COMM_WORLD_RANK available on $GDB_HOST:$GDB_PORT"
exec $GDBSERVER_BIN/gdbserver :$GDB_PORT $*

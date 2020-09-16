#!/bin/bash
# Usage: pgdb [args...] -exec <exec_name> --run <classical command to execute>
# We use the exec_name to split the classical command into the mpi param and
# the exec param

TRUE=1
FALSE=0

#By default we assume that the gdbserver needs to be started
# when the attach flag is set to true, the gdbserver cretion is skipped
ATTACH=$FALSE

#debug_mode Grid 1x2
P=1
Q=2
PORT=60000

#Pane creation var
VERTICAL=v
HORIZONTAL=h

GDB=gdb
GDBSERVER=gdbserver

################################################################################
#                                  FUNCTIONS                                  #
################################################################################
#print in bold text
function bold(){

  echo -e "\033[1m$1\033[0m"

}



function chelp(){
  echo -e "\t\t\t\tGeneral Commands Manual\t\t\t\t"
  bold    "NAME"
  echo -e "\t$0 - sets the gdbserver as well as the tmux env to ease the debug"
  bold    "SYNOPSIS"
  echo -e "\t$0 [OPTIONS]"
  bold    "DESCRIPTION"
  echo -e "\tNone"
  bold    "OPTIONS"
  bold    "\t-p <int>"
  echo -e "\t\tThe number of hosts"
  bold    "\t-q <int>"
  echo -e "\t\tThe number of MPI processes per host"
  bold    "\t--port <int>"
  echo -e "\t\tThe port used by the gdbserver. Each MPI process is associated"
  echo -e "\t\twith this port + MPI_rank."
  bold    "\t--attach"
  echo -e "\t\tDo not create the gdbserver. Instead, just consider the server"
  echo -e "\t\tset and listening on the ports as described above."
  bold    "\t--exec <exec_name>"
  echo -e "\t\tThe name of the executable that is used to split the <commandline>"
  echo -e "\t\tso that the MPI parameters and the executable parameters can be found."
  bold    "\t--run <commandline>"
  echo -e "\t\tThe commandline as used in a classic run"
  bold    "REMARKS"
  echo -e "\t\tOn some plateformes, the gdb env does not work properly."
  echo -e "\t\tTherefore, if needed, export the GDB_BIN and GDBSERVER_BIN."
  bold    "EXAMPLES"
  echo -e "\t\tThere is a test folder with a toto.c program."
  echo -e "\t\tGo to test and compile it using make."
  echo -e "\t\tExport PGDB_BIN=<location_of_debug_server.sh>"
  echo -e "\t\tMake sure, you already have a tmux session running."
  echo -e "\t\tThen, use the program as follow :"
  echo -e "\t\t\t../pgdb.sh -p 1 -q 2 --port 65000 --exec toto --run mpirun -n 2 toto"
  echo -e "\t\tFinally, attach to the tmux session."
  echo -e "\t\tTIPS : during debug session, the bind 'C-b z' focuses on the current pane."
}

function parse_param(){
  while [ $# -gt 0 ]; do
    case $1 in
      -h | --help )
        chelp $(basename $0)
        exit 0
        ;;
      -p)
        shift
        P=$1
        shift
        ;;
      -q)
        shift
        Q=$1
        shift
        ;;
      --port)
        shift
        PORT=$1
        shift
        ;;
      --attach)
        ATTACH=$TRUE
        shift
        ;;
      --exec)
        shift
        EXEC=$1
        shift
        ;;
      --run)
        shift
        CMDLINE=$*
        break
        ;;
      *)
        echo "$1 unknown argument" 1
        shift
        ;;
    esac
  done
}

#create the panes
function create_pane() {
  local PANE=$1
  local ORIENT=$2
  local SIZE=$3
  local HOST=$4
  local PORT=$5
 #local GDBCMD="gdb -ex "\'"target remote ${HOST}:${PORT}"\'""
  local cmd="$GDB -ex "\'"target remote ${HOST}:${PORT}"\'""
 #cmd="gdb target remote ${HOST}:${PORT}"
 #cmd="sh"

  echo "tmux splitw -$ORIENT -p $SIZE -t $PANE "$cmd""
  tmux splitw -$ORIENT -p $SIZE -t $PANE "$cmd"

 #sleep 2

 #echo "tmux send-keys -t $((PANE + 1)) "$GDBCMD" Enter"
 #tmux send-keys -t $((PANE + 1)) "$GDBCMD" Enter
}

################################################################################
#                                  EXECUTION                                  #
################################################################################

#===============================
# Parse the input parameters
#===============================
parse_param "$@"
#MPI_PARAM=$(echo $CMDLINE | cut -d "$EXEC" -f 1)
#EXEC_PARAM=$(echo $CMDLINE | cut -d "$EXEC" -f 2)
MPI_PARAM=$(echo $CMDLINE | sed "s:${EXEC} .*$::" | sed "s%${EXEC}%%" )
EXEC_PARAM=$(echo $CMDLINE | sed "s:^.*${EXEC}::" )

echo "EXECUTION: grid of ${P}x${Q}"
echo "CMDLINE: $CMDLINE"
echo "MPI params: $MPI_PARAM"
echo "EXEC params: $EXEC_PARAM"


#===============================
# Create the gdbserver if needed
#===============================
if [ ! -z "${GDB_BIN}" ]; then
  GDB=$GDB_BIN/gdb
else
  echo "TODO add checker for gdb"
fi

if [ ! -z "${GDBSERVER_BIN}" ]; then
  GDBSERVER=$GDBSERVER_BIN/gdbserver
else
  echo "TODO add checker for gdbserver"
fi

if [ $ATTACH -eq $FALSE ]; then
  #create the server
  SERVERCMD=$(echo $CMDLINE | sed "s:${EXEC}:${PGDB_BIN}/debug_server.sh $GDBSERVER ${PORT} &:" )

  echo "tmux send-keys -t 0 "$SERVERCMD" Enter"
  tmux send-keys -t 0 "$SERVERCMD" Enter

 #sleep 2
fi

#================
# Detect the hosts
#================
if [[ "$MPI_PARAM" == *"-H"* ]]; then
  HOSTSLOCATION=$( echo $MPI_PARAM | sed "s/^.*-H[ ]*//" )
  HOSTS=( $(echo $HOSTSLOCATION | sed "s/:[0-9]*,*/ /gI" ) )
else
  echo "No -H parameters given to mpirun => trying to detect the hostnames that will be sorted"
  HOSTS_RAW_INFO=$( $MPI_PARAM hostname )
  echo $HOSTS_RAW_INFO
  HOSTS=( $(echo $HOSTS_RAW_INFO | tr ' ' '\n' | sort | uniq ) )
fi
echo "HOSTS : ${HOSTS[@]}"

#================
# Create the env for the panes
#================
create_pane 0 $HORIZONTAL 70 ${HOSTS[0]} $PORT

# Create the columns
for q in $(seq 1 $((Q-1))); do
  sleep 3
  HOST=${HOSTS[0]}
  create_pane $((q)) $HORIZONTAL $((100 - 100 / (Q - q + 1) )) $HOST $((PORT + q))
done

# Creation of the panes as a grid PxQ, column by column
for q in $(seq 1 $Q); do
  echo "Q = $q"
  col_pane_id=$(( (q - 1) * $P + 1))
  echo "Col_pane_id $col_pane_id"

  for p in $(seq 2 $((P - 0))); do
    HOST=${HOSTS[$((p - 1))]}
    create_pane $col_pane_id $VERTICAL $((100 / (P - p + 2) )) $HOST $((PORT + (q - 1 ) * P + p - 1))
  done
done
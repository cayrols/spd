#!/bin/bash -l
# Usage: pgdb [args...] -exec <exec_name> --run <classical command to execute>
# We use the exec_name to split the classical command into the mpi param and
# the exec param

TRUE=1
FALSE=0

#Disable the tmux creation
DEVMODE=$TRUE
DEVMODE=$FALSE

#By default we assume that the gdbserver needs to be started
# when the attach flag is set to true, the gdbserver cretion is skipped
ATTACH=$FALSE

#debug_mode Grid 1x2
P=1
Q=2
PORT=60000
RANKS=""
#REARRANGEGRID=$FALSE
PAGING=$FALSE

#Pane creation var
VERTICAL=v
HORIZONTAL=h

GDBEXEC=gdb
GDBSERVEREXEC=gdbserver

MY_TMUX_TMPDIR=$HOME/tmux_tmp
TMUXCMD="tmux -S $MY_TMUX_TMPDIR"
TMUXSESSIONNAME=debug
PGDBWAITINGTIME=2

################################################################################
#                                  FUNCTIONS                                  #
################################################################################
#print in bold text
function bold(){

  echo -e "\033[1m$1\033[0m"

}

function decho(){
  if [ "$DEVMODE" -eq "$TRUE" ]; then
    echo "$@"
  fi 
}

function step(){
  echo -e "\n******** $1"
}



function chelp(){
  echo -e "\t\t\t\tGeneral Commands Manual\t\t\t\t"
  bold    "NAME"
  echo -e "\t$0 - sets the gdbserver as well as the tmux env to ease the debug"
  bold    "SYNOPSIS"
  echo -e "\t$0 [OPTIONS] --exec <exec_name> --run <commandline>"
  bold    "\t--exec <exec_name>"
  echo -e "\t\tThe name of the executable that is used to split the <commandline>"
  echo -e "\t\tso that the MPI parameters and the executable parameters can be found."
  bold    "\t--run <commandline>"
  echo -e "\t\tThe commandline as used in a classic run"
  
  bold    "DESCRIPTION"
  echo -e "\tNone"
  
  bold    "OPTIONS"
  bold    "\t-p <int: DEFAULT $P>"
  echo -e "\t\tThe number of hosts"
  
  bold    "\t-q <int: DEFAULT $Q>"
  echo -e "\t\tThe number of MPI processes per host"
  
  bold    "\t--port <int: DEFAULT $PORT>"
  echo -e "\t\tThe port used by the gdbserver. Each MPI process is associated"
  echo -e "\t\twith this port + MPI_rank."
  
  bold    "\t--gdbaddcmd 'cmd'"
  echo -e "\t\tAdd the 'cmd' commands to gdb. USE the gdb syntax -ex for each."
  
  bold    "\t--ranks <int,...>"
  echo -e "\t\tList of ranks to debug, separated by a comma and NO SPACE."
  
  bold    "\t--attach"
  echo -e "\t\tDo not create the gdbserver. Instead, just consider the server"
  echo -e "\t\tset and listening on the ports as described above."
  
  bold    "\t--cudagdb"
  echo -e "\t\tUse cuda-gdb and cuda-gdbserver instead of gdb and gdbserver."
  
  bold    "\t--paging"
  echo -e "\t\tCreate paging window."

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
  echo -e "\t\tTIPS : during debug session, the command kill-all -a -t 0 closes"
  echo -e "\t\t\tall panes except for the pane 0 (entered using 'C-b :')."
}

# This piece of code is needed here since the parameters can overwrite part
# of the content of the configuration file.
step "Configuration file"
# Source the RC file that will overwrite the path
#   of GDB_BIN, GDBSERVER_BIN, and PGDB_BIN
if [ -e $HOME/.pgdbrc ]; then
  echo "Load $HOME/.pgdbrc"
  source $HOME/.pgdbrc
else
  echo "No .gdbrc file found in $HOME"
fi

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
      --cudagdb)
        GDBEXECNAME=cuda-gdb
        GDBSERVEREXECNAME=cuda-gdbserver
        shift
        ;;
      --port)
        shift
        PORT=$1
        shift
        ;;
      --gdbaddcmd)
        shift
        GDBADDCMD="$1"
        shift
        ;;
      --attach)
        ATTACH=$TRUE
        shift
        ;;
      --paging)
        PAGING=$TRUE
        shift
        ;;
     #--rearrangeGrid) # TODO but not implemented yet
     #  REARRANGEGRID=$TRUE
     #  shift
     #  ;;
      --ranks)
        shift
        RANKS=$1
        RANK_LIST=$( echo $RANKS | tr -s ',' ' ' )
        decho "List of provided ranks: ${RANK_LIST[@]}"
        shift
        ;;
      --exec)
        shift
        EXEC=$1
        shift
        decho "GIVEN $EXEC"
        ;;
      --run)
        shift
        CMDLINE=$*
        break
        ;;
      --dev)#Intent to be removed
        shift
        DEVMODE=$TRUE
        ;;
      *)
        echo "$1 unknown argument" 1
        shift
        ;;
    esac
  done
}

function create_window(){
  local tmuxSession=$1
  local windowId=$2
  shift 2
  local windowName=( $@ )

  decho "Creation of window id:$windowId named ${windowName[@]}"\
    " in Session $tmuxSession"
  if [ $DEVMODE -eq $FALSE ]; then
    $TMUXCMD new-window -t ${tmuxSession}:$windowId -n "${windowName[@]}"
  fi
}

function select_window(){
  local tmuxSession=$1
  local windowId=$2

  decho "Selection of window id:$windowId in Session $tmuxSession"
  if [ $DEVMODE -eq $FALSE ]; then
    $TMUXCMD select-window -t ${tmuxSession}:$windowId
  fi
}

#create the panes
# NOTE: Use the bash global vars GDBADDCMD and EXEC
function create_pane() {
  local PANE=$1
  local ORIENT=$2
  local SIZE=$3
  local HOST=$4
  local PORT=$5
  local RUNGDB=$6
 #local GDBCMD="gdb -ex "\'"target remote ${HOST}:${PORT}"\'""
 #local gdb_params="--cuda-use-lockfile=0 -ex "\'"set cuda memcheck on"\'""
  local cmd="bash"

  decho "PANE:$PANE, ORIENT:$ORIENT, SIZE:$SIZE, HOST:$HOST, PORT:$PORT, RUNGDB:$RUNGDB"
  
  if [ $RUNGDB -eq $TRUE ]; then
  cmd="$GDB $GDBPARAMS -ex "\'"target remote ${HOST}:${PORT}"\'" $GDBADDCMD --args $EXEC"
 #local cmd="$GDB -ex "\'"target remote ${HOST}:${PORT}"\'" $GDBADDCMD --args $EXEC"
 #cmd="$GDB --cuda-use-lockfile=0 $EXEC"
 #cmd="gdb target remote ${HOST}:${PORT}"
 #cmd=$GDB
  fi


  sleep 1
  echo "$TMUXCMD splitw -$ORIENT -p $SIZE -t $PANE "$cmd""
  if [ $DEVMODE -eq $FALSE ]; then
    $TMUXCMD splitw -$ORIENT -p $SIZE -t $PANE "$cmd"
   #tmux send-keys -t $PANE "set sysroot target:/" Enter
   #tmux send-keys -t $PANE "target remote ${HOST}:${PORT}" Enter
  fi

}

function create_regular_grid(){
  local nrow=$1
  local ncol=$2

  local lrowPtr=()
  local lpaneId=()
  local lpaneAncestorId=()
  local lpaneRanks=()
  local nval=0

  lrowPtr+=( 0 )
  rowAncestor=0
  colAncestor=0
  for p in $(seq 1 $nrow ); do
    isRowLeader=$TRUE
   #rank=$nval
   #nval=$((nval + 1))

   #lpaneId+=( $nval )
   #lpaneRanks+=( $rank )
   #lpaneAncestorId+=( $colAncestor )

   #colAncestor=$p
   #rowAncestor=$nval

    for q in $(seq 0 $((ncol - 1)) ); do
      if [ $isRowLeader -eq $TRUE ]; then
        ancestor=$colAncestor
        colAncestor=$p
        isRowLeader=$FALSE
      else
        ancestor=$rowAncestor
      fi
      cur_rank=$(( (p - 1) * ncol + q ))
      nval=$((nval + 1))

      lpaneId+=( $nval )
      lpaneRanks+=( $cur_rank )
      lpaneAncestorId+=( $ancestor )

      rowAncestor=$nval
    done
    lrowPtr+=( $nval )
  done
  decho "rowPtr         ${lrowPtr[@]}"
  decho "paneId         ${lpaneId[@]}"
  decho "paneRanks      ${lpaneRanks[@]}"
  decho "paneAncestorId ${lpaneAncestorId[@]}"

  # Return arrays
  rowPtr=( ${lrowPtr[@]} )
  paneId=( ${lpaneId[@]} )
  paneRanks=( ${lpaneRanks[@]} )
  paneAncestorId=( ${lpaneAncestorId[@]} )
}

function is_active_rank(){
  local rank=$1
  shift
  local ranks=$@

  active_rank=$FALSE
  for lrank in ${ranks[@]}; do
    if [ $lrank -eq $rank ]; then
      active_rank=$TRUE
      decho "Rank $rank found in ${ranks[@]}"
      break
    fi
  done
}

function create_grid(){
  local nrow=$1
  local ncol=$2
  shift 2
  local ranks=( $@ )

  local lrowPtr=()
  local lpaneId=()
  local lpaneAncestorId=()
  local lpaneRanks=()
  local nval=0
  local size=$(( nrow * ncol ))
  local cur_rank=0

  lrowPtr+=( 0 )
  rowCounter=0
  colAncestor=0 # XXX assuming the gdbserver pane is 0
  rowAncestor=0
  for p in $(seq 1 $nrow ); do
    isRowLeader=$TRUE
    for q in $(seq 0 $((ncol - 1)) ); do
      cur_rank=$(( (p - 1) * ncol + q ))
      
      # Check whether the cu_rank is involved in the debugging
      is_active_rank $cur_rank ${ranks[@]}

      if [ $active_rank -eq $TRUE ]; then
        if [ $isRowLeader -eq $TRUE ]; then
          rowCounter=$((rowCounter + 1))
          ancestor=$colAncestor
          colAncestor=$rowCounter
          isRowLeader=$FALSE
        else
          ancestor=$rowAncestor
        fi
        nval=$((nval + 1))

        lpaneId+=( $nval )
        lpaneRanks+=( $cur_rank )
        lpaneAncestorId+=( $ancestor )
        
        rowAncestor=$nval
      fi
    done
    lrowPtr+=( $nval )
  done
  decho "rowPtr         ${lrowPtr[@]}"
  decho "paneId         ${lpaneId[@]}"
  decho "paneRanks      ${lpaneRanks[@]}"
  decho "paneAncestorId ${lpaneAncestorId[@]}"

  # Return arrays
  rowPtr=( ${lrowPtr[@]} )
  paneId=( ${lpaneId[@]} )
  paneRanks=( ${lpaneRanks[@]} )
  paneAncestorId=( ${lpaneAncestorId[@]} )
}

function display_pane(){
  local tmuxSession=$1
  local windowId=$2
  local rowOffset=$3
  local paneOffset=$4
  shift 4
  local row_idx=( $@ )

  # Select the window
  select_window $tmuxSession $windowId

  ## Create the rows first
  local nrowCreated=0
  local nlpaneCreated=0
  local pane_size=70
  local orient=$HORIZONTAL
 #for p in $(seq 0 $((P - 1))); do
  for p in ${row_idx[@]}; do
    nlrank=$(( ${rowPtr[$((p + 1))]} - ${rowPtr[$p]} ))
    if [ $nlrank -eq 0 ]; then 
      continue
    fi

    HOST=${HOSTS[$p]}
    HOST=${HOSTS[0]}
    if [ $nrowCreated -gt 0 ]; then
      pane_size=$((100 - 100 / (nactiveRow - nrowCreated + 1) ))
      orient=$VERTICAL
    fi
    pane_idx=${rowPtr[$p]}
    pane_rank=${paneRanks[$pane_idx]}
    col_pane_id=$(( ${paneAncestorId[$pane_idx]} - $rowOffset ))
    pane_port=$((PORT + pane_rank))
    pane_exec_gdb=$TRUE

    create_pane $col_pane_id $orient $pane_size \
      $HOST $pane_port $pane_exec_gdb

    nrowCreated=$(( nrowCreated + 1 ))
  done

  decho "Creation of $nrowCreated rows completed for window $windowId"

  # Creation of the panes as a grid PxQ, row by row
 #for p in $(seq 0 $((P - 1))); do
  for p in ${row_idx[@]}; do
    nlrank=$(( ${rowPtr[$((p + 1))]} - ${rowPtr[$p]} ))
    if [ $nlrank -eq 0 ]; then 
      continue
    fi
    decho "Add $nlrank for row $p"
    nlpaneCreated=$(( nlpaneCreated + nlrank ))

    for q in $(seq 1 $((nlrank - 1))); do
     #if [ $q -eq 1 ]; then
     #  offset=$rowOffset
     #else
        offset=$paneOffset
     #fi
      HOST=${HOSTS[$p]}
      HOST=${HOSTS[0]}
      pane_size=$((100 - 100 / (nlrank - q + 1) ))
      pane_idx=$(( ${rowPtr[$p]} + q ))
      pane_rank=${paneRanks[$pane_idx]}
      col_pane_id=$(( ${paneAncestorId[$pane_idx]} - $offset ))
      decho "col_pane_id=${paneAncestorId[$pane_idx]} - $offset "
      pane_port=$((PORT + $pane_rank))
      pane_exec_gdb=$TRUE

      create_pane $col_pane_id $HORIZONTAL $pane_size \
        $HOST $pane_port $pane_exec_gdb
    done
  done

  cur_npaneDisplayed=$nlpaneCreated
  decho "Returned cur_npaneDisplayed:$cur_npaneDisplayed"
}

function get_rows_to_display(){
  local nrow=$1
  local nrowStart=$2
  local pageMaxNrow=$3
  shift 3
  local lrowPtr=( $@ )

  local nlactiveRow=0
  local lrowToDisplay=()

  for i in $(seq $nrowStart $((nrow - 1)) ); do
    nlrank=$(( ${rowPtr[$((i + 1))]} - ${rowPtr[$i]} ))
    decho "Row $i: $nlrank elements"
    if [ $nlrank -gt 0 ]; then
      nlactiveRow=$(( nlactiveRow + 1 ))
      lrowToDisplay+=( $i )
      if [ $nlactiveRow -eq $pageMaxNrow ]; then
        break
      fi
    fi
  done

  rowToDisplay=( ${lrowToDisplay[@]} )
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

step "Parsed required information"
echo "EXECUTION: grid of ${P}x${Q}"
echo "CMDLINE: $CMDLINE"
echo "MPI params: $MPI_PARAM"
echo "EXEC params: $EXEC_PARAM"

#================
# Detect the hosts
#================
step "Detection of the hosts"
if [[ "$MPI_PARAM" == *"-H"* ]]; then
  HOSTSLOCATION=$( echo $MPI_PARAM | sed "s/^.*-H[ ]*//" | sed "s/-.*$//")
  HOSTS=( $(echo $HOSTSLOCATION | sed "s/:[0-9]*,*/ /gI" ) )
else
  echo "No -H parameters given to mpirun => trying to detect the hostnames that will be sorted"
  HOSTS_RAW_INFO=$( $MPI_PARAM hostname )
  echo $HOSTS_RAW_INFO
  HOSTS=( $(echo $HOSTS_RAW_INFO | tr ' ' '\n' | sort | uniq ) )
fi
echo "HOSTS : ${HOSTS[@]}"

#===============================
# Create the gdbserver if needed
#===============================
if [ ! -z "${GDB_BIN}" ]; then
  GDB=$GDB_BIN/$GDBEXECNAME
else
  echo "TODO add checker for gdb"
  GDB=$GDBEXECNAME
fi

if [ ! -z "${GDBSERVER_BIN}" ]; then
  GDBSERVER=$GDBSERVER_BIN/$GDBSERVEREXECNAME
else
  echo "TODO add checker for gdbserver"
  GDBSERVER=$GDBSERVEREXECNAME
fi


# Check that tmux session already exists
step "Gestion of the tmux"
echo "Checking session $TMUXSESSIONNAME"

tmuxsessions=$($TMUXCMD ls 2>/dev/null | grep $TMUXSESSIONNAME)
tmuxExist=$?
echo "#sessions: $tmuxNsession"
if [ $tmuxExist -eq 1 ]; then
  echo "Creation of the tmux session named '$TMUXSESSIONNAME'"
  $TMUXCMD new -s $TMUXSESSIONNAME -d -x "$(tput cols)" -y "$(tput lines)"
else
  echo "Tmux session named '$TMUXSESSIONNAME' already exists"
  #Ensure this session is the current one by attaching to it if more than one
  tmuxNsession=$($TMUXCMD ls | wc -l)
  if [ $tmuxNsession -gt 1 ]; then
    $TMUXCMD attach -t $TMUXSESSIONNAME
  fi
fi

if [ $ATTACH -eq $FALSE ]; then
  #create the server
  GDBSERVER_CMD="${PGDB_BIN}/debug_server.sh"

  # Select the ranks to debug
  if [ "$RANKS" != "" ]; then
    GDBSERVER_CMD+=" --debuggingRanks '$RANKS'"
  fi
  GDBSERVER_CMD+=" --server_bin $GDBSERVER"
  if [ ! -z "$GDBSERVERPARAMS" ]; then
    GDBSERVER_CMD+=" --server_params $GDBSERVERPARAMS"
  fi
  GDBSERVER_CMD+=" --port ${PORT}"
  GDBSERVER_CMD+=" --run"
  SERVERCMD=$(echo $CMDLINE | sed "s:${EXEC}:${GDBSERVER_CMD} &:" )

  step "Creation of the gdbserver"
  echo "$TMUXCMD send-keys -t 0 "$SERVERCMD" Enter"
  if [ $DEVMODE -eq $FALSE ]; then
    $TMUXCMD send-keys -t 0 "$SERVERCMD" Enter
  fi


  echo -e "\nWait for the gdbserver to start: $PGDBWAITINGTIME s"
  sleep $PGDBWAITINGTIME
fi

# Generate the grid 
if [ "$RANKS" != "" ]; then
  create_grid $P $Q ${RANK_LIST[@]}
else
  create_regular_grid $P $Q
fi

#================
# Create the env for the panes
#================
step "Creation of the pane"

nrowPerPage=2
nrowDisplayed=0
npaneDisplayed=0
rowToDisplay=()
# Count the number of rows to display
nactiveRow=0
for i in $(seq 0 $((P - 1)) ); do
  nlrank=$(( ${rowPtr[$((i + 1))]} - ${rowPtr[$i]} ))
  decho "Row $i: $nlrank elements"
  if [ $nlrank -gt 0 ]; then
    nactiveRow=$(( nactiveRow + 1 ))
   #rowToDisplay+=( $i )
  fi
done

if [ $PAGING -eq $TRUE ]; then
  nrowToDisplay=$nrowPerPage
  PYTHONCMD="from math import ceil; print( ceil(${nactiveRow}/$nrowPerPage) )"
  nwindows=$( python3 -c "$PYTHONCMD" )
  decho "nwindows:$nwindows"

 #get_rows_to_display $P $nrowDisplayed $nrowPerPage ${rowPtr[@]}
else
  nwindows=1
  nrowToDisplay=$P
fi

get_rows_to_display $P $nrowDisplayed $nrowToDisplay ${rowPtr[@]}

for windowId in $(seq 0 $((nwindows - 1)) ); do 
  if [ $windowId -gt 0 ]; then
    get_rows_to_display $P $nrowDisplayed $nrowToDisplay ${rowPtr[@]}

    windowName="Range_${rowToDisplay[0]}_${rowToDisplay[$(( ${#rowToDisplay[@]} - 1))]}"
    create_window $TMUXSESSIONNAME $windowId $windowName
  fi
  nactiveRow=${#rowToDisplay[@]}
  decho "[Page:$windowId] nactiveRow: $nactiveRow"

  decho "Rows to display: ${rowToDisplay[@]}"
  display_pane $TMUXSESSIONNAME $windowId $nrowDisplayed $npaneDisplayed ${rowToDisplay[@]}

  nrowDisplayed=$(( nrowDisplayed + ${#rowToDisplay[@]} ))
  npaneDisplayed=$(( npaneDisplayed + cur_npaneDisplayed ))
done

echo -e "\nAttach to the session $TMUXSESSIONNAME:\t$TMUXCMD attach -t $TMUXSESSIONNAME"

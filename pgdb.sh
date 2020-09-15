#!/bin/bash

HOSTS=( $@ )

#debug_mode Grid 1x2
P=1
Q=2
PORT=60000

#create the server
VERTICAL=v
HORIZONTAL=h

#create the panes
create_pane() {
  local PANE=$1
  local ORIENT=$2
  local SIZE=$3
  local HOST=$4
  local PORT=$5
  local cmd="gdb -ex "\'"target remote ${HOST}:${PORT}"\'""
  cmd="gdb target remote ${HOST}:${PORT}"
  cmd="bash"

# echo $cmd
  echo "tmux splitw -$ORIENT -p $SIZE -t $PANE "$cmd""
  tmux splitw -$ORIENT -p $SIZE -t $PANE "$cmd"
}

#create the server
SERVERCMD="mpirun -n $((P * Q)) -H "
for h in ${HOSTS[@]}; do
  SERVERCMD+="${h}:$Q,"
done
SERVERCMD=${SERVERCMD%?}
SERVERCMD+=" -x LD_LIBRARY_PATH"
SERVERCMD+=" ./debug_server.sh"
SERVERCMD+=" ./speed3d_c2c cufft double 128 128 128 -reorder -a2a"

#echo "tmux send-keys -t 0 "$SERVERCMD" Enter"
#tmux send-keys -t 0 "$SERVERCMD" Enter

sleep 2

#Create the env for the panes
create_pane 0 $HORIZONTAL 70 ${HOSTS[0]} $PORT
#tmux send-keys -t 0 "splitw -h -p 70 ${HOSTS[0]} $PORT" ENTER

for q in $(seq 1 $((Q-1))); do
  HOST=${HOSTS[0]}
  create_pane $((q)) $HORIZONTAL $((100 - 100 / (Q - q + 1) )) $HOST $((PORT + q))
done

#creation of the panel as a grid PxQ, column by column
for q in $(seq 1 $Q); do
  echo "Q = $q"
  col_pane_id=$(( (q - 1) * $P + 1))
  echo "Col_pane_id $col_pane_id"

  for p in $(seq 2 $((P - 0))); do
    HOST=${HOSTS[$((p - 1))]}
    create_pane $col_pane_id $VERTICAL $((100 / (P - p + 2) )) $HOST $((PORT + (q - 1 ) * P + p - 1))
  done
  
# echo "----"
# #Prepare next row only if needed
# if [ $(( p + 1 )) -le $P ]; then
#   HOST=${HOSTS[$p]}
#   create_pane $row_pane_id $VERTICAL $((100/(P - p + 1))) $HOST $((PORT + p * Q))
# fi

done

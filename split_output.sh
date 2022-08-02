#!/bin/bash

# Needed params
LOCAL_FIFOS=local_fifos

TRUE=1
FALSE=0

DEVMODE=$TRUE
DEVMODE=$FALSE

function decho(){
  if [ "$DEVMODE" -eq "$TRUE" ]; then
    echo "$@"
  fi 
}

# This function seeks on the possible patterns in the env to extract the
# world rank.
function get_world_rank() {

  local possible_patterns=( OMPI_COMM_WORLD_RANK PMI_RANK )
  local output=$( printenv | grep RANK )
  echo $output

  # For each possible patterns
  for possible_pattern in ${possible_patterns[@]}; do
    if [[ $output == *"$possible_pattern"* ]]; then
      decho "Found: $possible_pattern"

      # Search env var
      for env_var in $output; do
        if [[ $env_var == "$possible_pattern"* ]]; then
          world_rank=$( echo $env_var | cut -d '=' -f 2 )
          break
        fi
      done
      break
    fi
  done

  if [ "$world_rank" == "" ]; then
    echo "Error, no world rank found"
    exit 1
  fi
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

get_world_rank

parse_param "$@"

pane_id=$world_rank
fifo_pane_id=$LOCAL_FIFOS/fifo_$pane_id

# Assuming for now that the pane created it.
#mkfifo $fifo_pane_id

echo "execute: $CMD > $fifo_pane_id 2>&1"
if [ "$DEVMODE" -eq "$FALSE" ]; then
  exec $CMD > $fifo_pane_id 2>&1
fi

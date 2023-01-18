#!/bin/bash -l

# Used to avoid errors when executed.
set -euo pipefail

#-------------------
# Rules of coding
# Capital varname are global var
# Lower case varname is used for local var
# All var must be ${}
# For each function, a desc local var is used

TRUE=1
FALSE=0

# Default tmux command that may be updated in the main function
TMUX_CMD="tmux"

# Pane orientation choices
VERTICAL=v
HORIZONTAL=h

# Pseudo code
# Considering a 3D grid to display of size x,y,z
#   - For 1:z
#     # Create a 2D plan x,y:
#     - For each 1:x
#       - For each 1:y
#         - Create an element
#
# Because of the constraint of TMUX, the rows are created first
# and then the columns.

# Question: 
#   - Should we create a regular 3D grid and kill the elements that
#    are not needed?
#   - 

main(){
  local desc="This function manages the creation of a 3D grid of panes."
  local input_params=$@

  #================
  # Init the env
  #================
  # Determine the root of the script
  GRID_MANAGER_ROOT=$( dirname ${BASH_SOURCE[0]} ) #TODO rename
  decho "GRID_MANAGER_ROOT: ${GRID_MANAGER_ROOT}"

  source_config_and_rc_files

  setup_output_format

  #================
  # Parse the input parameters and extract info
  #================
  step "Parse user input"
  parse_param ${input_params[@]}

  bold "Parsed information:"
  echo "Execution : grid ${DIM_X}*${DIM_Y}*${DIM_Z}"

  # Update the TMUX command that is used by inner functions
  if [ ${GRID_MANAGER_TMUX_USE_USER_SOCKET} -eq ${TRUE} ]; then
    TMUX_CMD+=" -S ${GRID_MANAGER_USER_TMUX_TMPDIR}"
  fi
  decho "TMUX_CMD: ${TMUX_CMD}"
  
  #================
  # Main
  #================
  create_3d_grid ${DIM_X} ${DIM_Y} ${DIM_Z} \
    ${GRID_MANAGER_TMUX_SESSION_NAME} \
    ${GRID_MANAGER_TMUX_INITIAL_WINDOW_ID} \
    ${GRID_MANAGER_WITH_MASTER}
}

create_3d_grid(){
  local desc="This function creates a 3D grid of panes,"
    desc+=" using z-dim for managing number of tmux windows needed"
  local dim_x=$1
  local dim_y=$2
  local dim_z=$3
  local tmux_session=$4
  local initial_window=$5
  local with_master=$6

  local window_id=${initial_window}
  local window_name=""
  local pane_size=$(( 100 - MASTER_PANE_SIZE ))
  local pane_ancestor_id=0

  # Create the first grid alongwith a master pane if requested.
  if [ ${with_master} -eq ${TRUE} ]; then
    create_pane ${tmux_session} ${window_id} ${pane_ancestor_id} \
      ${HORIZONTAL} ${pane_size}
    pane_ancestor_id=${_RETVAL}
  fi

  create_2d_grid ${tmux_session} ${window_id} ${pane_ancestor_id} \
    ${dim_x} ${dim_y}

  # All remaining windows should be empty and so starts with pane_0
  pane_ancestor_id=0
  for k in $( seq 2 ${dim_z} ); do
    window_id=$(( initial_window + k - 1 )) # -1 because of k
    window_name="page_"${k}

    create_window ${tmux_session} ${window_id} ${window_name}
    create_2d_grid ${tmux_session} ${window_id} ${pane_ancestor_id} \
      ${dim_x} ${dim_y}
  done
}

# Wrapper over tmux command to create a new window.
# This function creates a new window with a name in an existing session
create_window() {
  local desc="This function creates a new window in an existing session."
  local tmux_session=$1
  local window_id=$2
  shift 2
  local window_name=( $@ )

  decho "Creation of window id:${window_id} named ${window_name[@]}"\
    " in Session ${tmux_session}"
  if [ ${DEV_MODE} -eq ${FALSE} ]; then
    decho ${TMUX_CMD} new-window -t ${tmux_session}:${window_id} -n "${window_name[@]}"
    ${TMUX_CMD} new-window -t ${tmux_session}:${window_id} -n "${window_name[@]}"
  fi
}

create_2d_grid(){
  local desc="This function creates a 2D grid x * y in a given window."
    desc+="Note: x is the number of rows."
  local tmux_session=$1
  local window_id=$2
  local pane_ancestor_id=$3
  local dim_x=$4
  local dim_y=$5
  local pane_parent_id=${pane_ancestor_id}

  local pane_offset=0

  # Create the rows first
  local pane_size=100
  local pane_id=-1 # Incorrect on purpose

  decho "[W:${window_id}] Creation of ${dim_x} rows."
  for p in $( seq 2 ${dim_x} ); do
    compute_pane_size $(( p - 1 )) ${dim_x}
    pane_size=${_RETVAL}

    decho "[W:${window_id}] Creation of a new pane from pane ${pane_parent_id}"
    create_pane ${tmux_session} ${window_id} ${pane_parent_id} \
      ${VERTICAL} ${pane_size}
    pane_id=${_RETVAL}
    decho "[W:${window_id}]\t\t\t\tPane ${pane_id} created"

    # Prepare for the next iteration
    pane_parent_id=${pane_id}
  done

  decho "[W:${window_id}] Creation of ${dim_y} elements per row."
  # Creation of the panes as a grid PxQ, row by row
  for p in $( seq ${dim_x} ); do
    pane_parent_id=$(( (p - 1)*dim_y + pane_ancestor_id))
    for q in $( seq 2 ${dim_y} ); do
      compute_pane_size ${q} $(( dim_y + 1 ))
      pane_size=${_RETVAL}

      decho "[W:${window_id}] Creation of a new pane from pane ${pane_parent_id}"
      create_pane ${tmux_session} ${window_id} ${pane_parent_id} \
        ${HORIZONTAL} ${pane_size}
      pane_id=${_RETVAL}
      decho "[W:${window_id}]\t\t\t\tPane ${pane_id} created."

      # Prepare for the next iteration
      pane_parent_id=${pane_id}
    done
  done
}

# Wrapper over tmux command to split a pane in order to create a pane
create_pane() {
  local desc="This function splits an existing pane to get a new pane."
    desc+="It also starts a bash in the new pane."
  local tmux_session=$1
  local window_id=$2
  local parent_pane_id=$3
  local orientation=$4
  local pane_size=$5

  local cmd="bash"

  decho "Creation of pane: " \
          "Parent_pane_id: ${parent_pane_id}, " \
          "Orientation: ${orientation}, " \
          "Size: ${pane_size}"
  
  # TODO prepend with log_
  log_tmux_cmd_sent "${TMUX_CMD} splitw -${orientation} -p ${pane_size} " \
    "-t ${tmux_session}:${window_id}.${parent_pane_id} \"${cmd}\""
  if [ ${DEV_MODE} -eq ${FALSE} ]; then
    _RETVAL=$( ${TMUX_CMD} splitw -${orientation} -p ${pane_size} \
      -t ${tmux_session}:${window_id}.${parent_pane_id} -P -F "#{pane_index}" \
      "${cmd}" )
  fi
}

compute_pane_size() {
  local desc="This function computes the size of a pane within a row."
  local i=$1
  local dim=$2

  # Returned value
  _RETVAL=$((100 - 100 / (dim - i + 1) ))
}


################################################################################
#                      Auxiliary Functions                                    #
################################################################################
# Print in a text in bold
bold() {
  local desc="This function prints in bold the given parameter."

  echo -e "${BOLD}${1-}${NOFORMAT}"
}

# Conditional print
decho() {
  local desc="This function prints the given parameters only if dev_mode is on."

  if [ "${DEV_MODE:-${FALSE}}" -eq "${TRUE}" \
    -o "${VERBOSE:-${FALSE}}" -eq "${TRUE}" ]; then
    echo -e "$@"
  fi 
}

# Format the print of a step given in parameter
step() {
  local desc="This function prints the name of the step passed in parameter."

  decho "\n${GREEN}******** $1${NOFORMAT}"
}

# Print error message and can exit if two parameters are given
# PARAM
# $1    is the message to be displayed
# $2    is the exit code
error() {
  local desc="This function prints an error message."

  echo -e "\n${RED}Error,\t${1-}${NOFORMAT}" >&2
  exit $2

}

# Print warning message
# PARAM
# $1    is the message to be displayed
warning() {
  local desc="This function prints a warning message."
  local msg=$*

  echo -e "${YELLOW}Warning,\t${msg}${NOFORMAT}" >&2
}

# Print important message
# PARAM
# $1    is the message to be displayed
important() {
  local desc="This function prints important message."
  local msg=$*

  echo -e "\n${BLUE}User info,\t${msg}${NOFORMAT}\n"
}

# Print important message
# PARAM
# $1    is the message to be displayed
log_tmux_cmd_sent() {
  local desc="This function prints message related to tmux commands sent."
  local msg=$*

  decho "${CYAN}${msg}${NOFORMAT}"
}

# Concat elements of an array
concat_array() {
  local IFS=$1
  shift

  echo "$*"
}

# Original function from: https://betterdev.blog/minimal-safe-bash-script-template/
setup_output_format() {
  # NOTE: -t is used to test if the file descriptor 1 exists i.e. stdout
  if [[ -t 1 ]] && [[ ${NO_COLOR:-FALSE} -eq ${FALSE} ]] \
    && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m'
    BOLD='\033[1m'
    RED='\033[0;31m'    GREEN='\033[0;32m' YELLOW='\033[1;33m'
    ORANGE='\033[0;33m' BLUE='\033[0;34m'
    PURPLE='\033[0;35m' CYAN='\033[0;36m'
  else
    NOFORMAT=''
    BOLD=''
    GREEN='' RED='' YELLOW=''
    BLUE='' PURPLE='' CYAN=''
    ORANGE=''
  fi
}

# Help routine that lists all parameters of the script
chelp() {
  local desc="This function lists and describes all parameters of the script."

  echo -e "\t\t\t\tGeneral Commands Manual"
  bold    "NAME"
  echo -e "\t$0 - creates a 3D grid of panes."
  bold    "SYNOPSIS"
  echo -e "\t$0 -x <dim_x> -y <dim_y> -z <dim_z>" \
          " --tmux_session <tmux_session_name>" \
          " --tmux_initial_window_id <window_id>" \
          " --create_with_master <TRUE|FALSE>"
  
  bold    "DESCRIPTION"
  echo -e "\tNone"
  
  bold    "OPTIONS"
  bold    "\t-x <int: DEFAULT ${DIM_X-}>"
  echo -e "\t\tThe number of hosts per 2D grid."
  
  bold    "\t-y <int: DEFAULT ${DIM_Y-}>"
  echo -e "\t\tThe number of MPI processes per host."

  bold    "\t-z <int: DEFAULT ${DIM_Z-}>"
  echo -e "\t\tThe number of 2D grid."
  
  bold    "\t--tmux_session <name: DEFAULT ${GRID_MANAGER_TMUX_SESSION_NAME-}>"
  echo -e "\t\tThe name of the tmux session to use."
  
  bold    "\t--tmux_socket <path/name: DEFAULT ${GRID_MANAGER_USER_TMUX_TMPDIR-}>"
  echo -e "\t\tThe name of the tmux session to use."
  
  bold    "\t--tmux_initial_window_id <int: DEFAULT ${GRID_MANAGER_TMUX_INITIAL_WINDOW_ID}>"
  echo -e "\t\tThe initial window ID where to create the grid."
  
  bold    "\t--create_with_master <bool: DEFAULT ${GRID_MANAGER_WITH_MASTER-}>"
  echo -e "\t\tCreate space for a master pane."
  
  bold    "REMARKS"
  bold    "EXAMPLES"
}

# Parse the given parameters
parse_param() {
  local desc="This function parses the parameters given to this script."
  local answer=""

  while [ $# -gt 0 ]; do
    case $1 in
      # Alphabetic order
      --create_with_master)
        shift
        GRID_MANAGER_WITH_MASTER=${FALSE}
        if [ $1 -ne 0 ]; then
          GRID_MANAGER_WITH_MASTER=${TRUE}
        fi
        shift
        ;;
      --dev) #Intent to be removed
        shift
        DEV_MODE=${TRUE}
        ;;
      -h | --help )
        chelp $( basename $0 )
        exit 0
        ;;
      --tmux_initial_window_id)
        shift
        GRID_MANAGER_TMUX_INITIAL_WINDOW_ID=$1
        shift
        ;;
      --tmux_session)
        shift
        GRID_MANAGER_TMUX_SESSION_NAME=$1
        shift
        ;;
      --tmux_socket)
        shift
        GRID_MANAGER_USER_TMUX_TMPDIR=$1
        shift
        ;;
      -x)
        shift
        DIM_X=$1
        shift
        ;;
      -y)
        shift
        DIM_Y=$1
        shift
        ;;
      -z)
        shift
        DIM_Z=$1
        shift
        ;;
      # Alphabetic order
      *)
        echo "$1 unknown argument" 1
        shift
        ;;
    esac
  done
}

source_config_and_rc_files() {
  local desc="This function loads grid_config and may load .gridrc file."
  local config_files=( )
  local rc_files=( )

  # List of potential spd_config.in ORDERED
  config_files=(  ./grid_config.in )
  config_files+=( ${HOME}/.spd/grid_config.in ) #We consider SPD as main purpose
  config_files+=( ${GRID_MANAGER_ROOT}/grid_config.in )
  for config_file in ${config_files[@]}; do
    if [ -e ${config_file} ]; then
      echo "Source config file ${config_file}"
      source ${config_file}
      local errCode=$?
      if [ ${errCode} -ne 0 ]; then
        warning "Failed to source ${config_files} with errCode ${errCode}." \
          "Try the next one."
      else
        break
      fi
    fi
  done

  # List of potential spd_config.in ORDERED
  rc_files=(  ./.gridrc )
  rc_files+=( ${HOME}/.gridrc )
  for rc_file in ${rc_files[@]}; do
    if [ -e ${rc_file} ]; then
      echo "Source rc file ${rc_file}"
      source ${rc_file}
      local errCode=$?
      if [ ${errCode} -ne 0 ]; then
        warning "Failed to source ${rc_files} with errCode ${errCode}." \
          "Try the next one."
      else
        break
      fi
    fi
  done
}

main "$@"

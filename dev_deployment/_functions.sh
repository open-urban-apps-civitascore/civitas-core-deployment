# Utility functions

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to increment IP address
increment_ip() {
  local ip=$1
  local inc=$2

  IFS='.' read -r -a octets <<< "$ip"
  for ((i=${#octets[@]}-1; i>=0; i--)); do
    octets[$i]=$((octets[$i]+inc))
    if [ "${octets[$i]}" -lt 256 ]; then
      break
    fi
    octets[$i]=0
  done
  echo "${octets[0]}.${octets[1]}.${octets[2]}.${octets[3]}"
}


# Function to echo in green
echo_green() {
  echo -e "${GREEN}$1${NC}"
}

# Function to echo in blue
echo_blue() {
  echo -e "${BLUE}$1${NC}"
}

# Function to echo in yellow
echo_yellow() {
  echo -e "${YELLOW}$1${NC}"
}

# Function to echo in red
echo_red() {
  echo -e "${RED}$1${NC}"
}

# Function to echo in green with a newline
echo_green_nl() {
  echo -e "\n${GREEN}$1${NC}"
}

# Function to echo in blue with a newline
echo_blue_nl() {
  echo -e "\n${BLUE}$1${NC}"
}

# Function to echo in yellow with a newline
echo_yellow_nl() {
  echo -e "\n${YELLOW}$1${NC}"
}

# Function to echo in red with a newline
echo_red_nl() {
  echo -e "\n${RED}$1${NC}"
}


# Function to start a color
start_color() {
  case $1 in
    "red")
      echo -ne "${RED}"
      ;;
    "green")
      echo -ne "${GREEN}"
      ;;
    "yellow")
      echo -ne "${YELLOW}"
      ;;
    "blue")
      echo -ne "${BLUE}"
      ;;
    *)
      echo -ne "${NC}"
      ;;
  esac
}

# Function to stop all colors
stop_color() {
  echo -ne "${NC}"
}

format_time() {
    local total_seconds=$1
    local hours=$((total_seconds / 3600))
    local minutes=$(( (total_seconds % 3600) / 60 ))
    local seconds=$((total_seconds % 60))

    if (( hours > 0 )); then
        printf "%d hours, %d minutes and %d seconds\n" "$hours" "$minutes" "$seconds"
    elif (( minutes > 0 )); then
        printf "%d minutes and %d seconds\n" "$minutes" "$seconds"
    else
        printf "%d seconds\n" "$seconds"
    fi
}

# Checks if all given commands are available on the system. 
#
# Arguments:
#   $@ - One or more command names to check for availability.
# 
# Example: 
#   requirementsMet curl wget
requirementsMet() {
    local unmet=() # save all unmet requirements, so they are all checked
    local cmd
    for cmd in "$@"; do
        if ! command -v $cmd 2>&1 >/dev/null; then
            unmet+=($cmd)
        fi
    done
    if [ ${#unmet[@]} -gt 0 ]; then
        start_color red
        for cmd in "${unmet[@]}"; do
            echo "Required command '${cmd}' is not available"
        done
        stop_color
        exit 1
    fi
}

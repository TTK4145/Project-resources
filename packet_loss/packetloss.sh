#!/bin/bash
# Note: Since packets are dropped on both input and output unless -i or -o is specified, a packet
# loss argument of 50% will result in an effective loss of 75% when measuring roundtrip packet
# loss, etc...
#
# Note: -dport DROP on outbound connections causes send() operations to return EPERM, rather
# than just dropping packets like it would with actual packet loss. Ideally you should avoid
# running the script with -o enabled (by default enabled unless -i is specified) if you drop on all
# ports.

# Functions defs
print_help() {
  echo "Usage: sudo $0 <percentage> -[i|o|e|u] [--input|--output|--elixir|--unsafe] [ports...](optional)"
  echo "Example: sudo $0 50 -i --unsafe 12345 67890"
  echo "Recommended Elixir usage: sudo $0 <percentage> -ie"
  echo "Recommended general usage: sudo $0 <percentage> -i <ports>"
  echo "Options:"
  echo "  -i, --input    Apply packet loss to incoming traffic only"
  echo "  -o, --output   Apply packet loss to outgoing traffic only. Note that this may cause send()"
  echo "                 operations to return EPERM on dropped packets if ports is set to <all>"
  echo "  -e, --elixir   Dynamically apply packet loss to detected elixir processes alongside the "
  echo "                 given ports."
  echo "  -u, --unsafe   Run the script without a 15-minute safety timeout, don't enable if you ssh"
  echo "                 into the machine running this script."
  echo "  -h, --help     Display this help message"
  echo "Arguments:"
  echo "  <percentage>   Percentage of packets to drop (0-100)"
  echo "  [ports...]     List of ports to apply packet loss (default: 20000 20001)"
  echo "                 Use <all> to apply to all ports"
}

cleanup() {
  echo "Removing iptables rules..."
  iptables -F
  echo "iptables rules removed"
}

get_elixir_ports() {
  pids=$(pidof "beam.smp")
  ports=()
  for pid in $pids; do
      cmd=$(sudo netstat -aputn | grep "0.0.0.0" | grep "$pid" | awk '{print $4}' | awk -F ':' '{print $2}')
      ports+=("$cmd")
  done
  ports=("$(echo "${ports[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')")
  echo "${ports[@]}"
}

set_elixir_iptables_rules() {
  IFS=" " read -r -a elixir_ports <<< "$(get_elixir_ports)"
  for port in "${elixir_ports[@]}"; do
    if $input || $both; then
      if ! iptables -L -n | grep -q "$PROTOCOL.*dpt:$port"; then
        iptables -A INPUT -p tcp --dport "$port" -m statistic --mode random --probability "$decimal" -j DROP
        iptables -A INPUT -p udp --dport "$port" -m statistic --mode random --probability "$decimal" -j DROP
        echo "New elixir port detected and added to iptables rules: $port (incoming)"
      fi
    fi
    if $output || $both; then
      if ! iptables -L -n | grep -q "$PROTOCOL.*dpt:$port"; then
        iptables -A OUTPUT -p tcp --sport "$port" -m statistic --mode random --probability "$decimal" -j DROP
        iptables -A OUTPUT -p udp --sport "$port" -m statistic --mode random --probability "$decimal" -j DROP
        echo "New elixir port detected and added to iptables rules: $port (outgoing)"
      fi
    fi
  done
}

set_iptables_rules() {
  if [ "$1" == "all" ]; then
    if $input || $both; then
      iptables -A INPUT -p tcp -m statistic --mode random --probability "$decimal" -j DROP
      iptables -A INPUT -p udp -m statistic --mode random --probability "$decimal" -j DROP
    fi
    if $output || $both; then
      iptables -A OUTPUT -p tcp -m statistic --mode random --probability "$decimal" -j DROP
      iptables -A OUTPUT -p udp -m statistic --mode random --probability "$decimal" -j DROP
    fi
  else
    # Default ports if none are provided
    ports=("$@")
    if [ ${#ports[@]} -eq 0 ]; then
      ports=(20000 20001)
    fi

    if $elixir; then
      if ! command -v netstat &> /dev/null; then
        read -r -p "netstat is not installed. Do you want to install it via apt? (y/n): " choice
        case "$choice" in
          y|Y ) echo "Installing net-tools..." && sudo apt update &> /dev/null && sudo apt install -y net-tools &> /dev/null;;
          n|N ) echo "netstat is required for elixir mode. Exiting..."; exit 1;;
          * ) echo "Invalid choice. Exiting..."; exit 1;;
        esac
      fi
      IFS=" " read -r -a elixir_ports <<< "$(get_elixir_ports)"
      ports+=("${elixir_ports[@]}")
    fi

    for port in "${ports[@]}"; do
      if $input || $both; then
        iptables -A INPUT -p tcp --dport "$port" -m statistic --mode random --probability "$decimal" -j DROP
        iptables -A INPUT -p udp --dport "$port" -m statistic --mode random --probability "$decimal" -j DROP
      fi
      if $output || $both; then
        # Note: dropping on output --dport will return eperm on send() operations, which might crash
        # some applications. We drop on --sport, meaning all outbound connections *from* port will
        # have potential packet loss, rather than dropping on outbound connections *to* port.
        iptables -A OUTPUT -p tcp --sport "$port" -m statistic --mode random --probability "$decimal" -j DROP
        iptables -A OUTPUT -p udp --sport "$port" -m statistic --mode random --probability "$decimal" -j DROP
      fi
    done
  fi
}

# Main logic
# Parse arguments
if [ -z "$1" ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  print_help
  exit 0
fi

percentage="$1"
if ! [[ "$percentage" =~ ^[0-9]+$ ]] || [ "$percentage" -lt 0 ] || [ "$percentage" -gt 100 ]; then
  echo "Error: Percentage must be a number between 0 and 100."
  exit 1
fi
decimal=$(echo "scale=2; $percentage / 100" | bc)

# Shift to the next argument, options
shift

input=false
output=false
both=true
elixir=false
unsafe=false

while [[ "$1" == -* ]]; do
  case "$1" in
    -i|--input) input=true; both=false ;;
    -o|--output) output=true; both=false ;;
    -e|--elixir) elixir=true ;;
    -u|--unsafe) unsafe=true ;;
    -h|--help) print_help; exit 0 ;;
    -*)
      for (( i=1; i<${#1}; i++ )); do
        case "${1:$i:1}" in
          i) input=true; both=false ;;
          o) output=true; both=false ;;
          e) elixir=true ;;
          u) unsafe=true ;;
          h) print_help; exit 0 ;;
          *) echo "Invalid option: -${1:$i:1}"; print_help; exit 1 ;;
        esac
      done
      ;;
    *) echo "Invalid option: $1"; print_help; exit 1 ;;
  esac
  shift
done

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root. Use sudo."
  echo "Call $0 -h for help."
  exit 1
fi

# Apply iptables rules
trap cleanup EXIT
set_iptables_rules "$@"

if [ "$1" == "all" ]; then
  port_string="all ports"
else
  port_string="${ports[*]}"
fi

if $both || ($input && $output); then
  echo "iptables rules applied to drop $percentage% of packets on ports: ${port_string[*]} (both directions)"
elif $input; then
  echo "iptables rules applied to drop $percentage% of packets on ports: ${port_string[*]} (incoming)"
else
  echo "iptables rules applied to drop $percentage% of packets on ports: ${port_string[*]} (outgoing)"
fi

if ! $unsafe; then
  echo "Safety feature enabled: The script will exit after 15 minutes."
  end_time=$((SECONDS + 900))
  while [ $SECONDS -lt $end_time ]; do
    if $elixir; then
      set_elixir_iptables_rules "$@"
    fi
    sleep 5
  done
  echo "15 minutes have passed. Exiting..."
else
  echo "Unsafe mode enabled: The script will run indefinitely."
  while true; do
    if $elixir; then
      set_elixir_iptables_rules "$@"
    fi
    sleep 5
  done
fi

# shellcheck shell=bash

(return 0 2>/dev/null) && __sourced=1
[ -n "$__sourced" ] && echo "abort: this script cannot be sourced" >&2 && return 1

readonly COL_RED="\e[1m\e[31m"
readonly COL_OFF="\e[0m"


declare -A options
#options[console]='/dev/null'
#options[logfile]='/dev/null'
options[console]='console.log'
options[logfile]='file.log'

println() { printf "%b\n" "$*"; }

function msg {
  ts=$(date +'%s')
  ns=$(date +%s.%N|cut -d '.' -f 2)
  echo -n "[${ts: -4}.${ns:0:4}] $1"
}

function flog {
  println "${COL_RED}(flog)${COL_OFF} $(msg "$1")" >&9
}

function tlog {
  println "${COL_RED}(tlog)${COL_OFF} $(msg "$1")" 1> >(tee -a /dev/tty >&9) 
}

function log {
  println "${COL_RED}( log)${COL_OFF} $(msg "$1")" 1> >(tee -a /proc/self/fd/8 >&9) 
}

function cleanup {
  flog "cleanup:"
  flog "- close logfile"

  exec 7>&- 
  exec 8>&- 
  exec 9>&- 
}

# traps
trap cleanup EXIT

init() 
{
  # init logfile
  exec 8> "${options[console]}"
  exec 9> "${options[logfile]}"
}

log_on () { exec 7>&8; exec 8>&1; }

log_off () { exec 8>&7; }

main()
{
  tlog "terminal log"
  log "hidden log #1"

  log_on
  #exec 7>&8
  #exec 8>&1
  log "visible log #1"
  
  log_off
  #exec 8>&7
  log "hidden log #2"
  
  log_on
  #exec 7>&8
  #exec 8>&1
  log "visible log #2"
  log "visible log #3"
  log "visible log #4"
  log "visible log #5"

  log_off
  #exec 8>&7
  log "hidden log #3"
  
  log_on
  #exec 7>&8
  #exec 8>&1
  log "visible log #6"
  log "visible log #7"
  log "visible log #8"
  log "visible log #9"
}

init
main "$@"

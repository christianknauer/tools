# shellcheck shell=bash

(return 0 2>/dev/null) && __sourced=1
[ -n "$__sourced" ] && echo "abort: this script cannot be sourced" >&2 && return 1

#set -eu

# globals
script=${0##*/}
tempdir=''

typeset -A options
options[console]='/dev/null'
options[logfile]='/dev/null'
options[debug]=0
options[mute]=0

# init & exit code
function startup {
  tempdir=$(mktemp -d -t "tmp.${script}.XXXXXXXXXX") || return 1

  echo "startup: $tempdir"
  return 0
}

function cleanup {
  echo "cleanup:" >&9
  echo "  rm temp dir" >&9
  rm -rf "$tempdir" >&9
  echo "  close logfile" >&9
  exec 9>&- 
  exec 8>&- 
}

# traps
trap cleanup EXIT
trap 'echo "$script: ERR at line $LINENO" >&2' ERR

check_app() { hash "$1" 2>/dev/null || { echo >&2 -e "abort: $1 is required"; return 1; } }
check_apps() { for i in "$@"; do check_app "$i" || return 1; done }

function catch() {
    {
        IFS=$'\n' read -r -d '' "${1}";
        IFS=$'\n' read -r -d '' "${2}";
        (IFS=$'\n' read -r -d '' _ERRNO_; return ${_ERRNO_});
    } < <((printf '\0%s\0%d\0' "$(((({ shift 2; "${@}"; echo "${?}" 1>&3-; } | tr -d '\0' 1>&4-) 4>&2- 2>&1- | tr -d '\0' 1>&4-) 3>&1- | exit "$(cat)") 4>&1-)" "${?}" 1>&2) 2>&1)
}

usage() 
{
  local usage
  read -r -d '' usage <<EOF
  Usage: $script [OPTIONS] <query> 

	--query <query>: Set the initial fzf query to <query>
EOF
  echo -e "$usage" 1>&2
  exit 0
}

parse_options() {

  local opt err ec
  
  catch opt err getopt -o hq: --long DEBUG:,help,LOGFILE:,query: -- "$@"; ec=$?

  [ $ec -eq 1 ] && { echo >&2 "abort: $err"; } && exit 1

  eval set -- "$opt"
  while true; do
    case "$1" in
      -h|--help)
        usage
      ;;
      --LOGFILE)
        shift
        options[logfile]="$1"
      ;;
      --DEBUG)
        shift
        options[debug]="$1"
      ;;
      -q|--query)
        shift
        options[query]="$1"
      ;;
      --)
        shift
        break
      ;;
      *)
        echo >&2 "warning: unknown options provided ($1 $2 ...)"
      ;;
    esac
    shift
  done

  echo "remainder: \"$@\""
}

run() {
  echo "run"
  echo "query = '${options[query]}'"
  exit 0
}

init() 
{
  # init logfile
  exec 9> "${options[logfile]}"
  exec 8> "${options[console]}"
}

main()
{
  echo "main"

  if [ ! "$1" = '++' ]; then
    # first run
    echo "first time"
  else
    shift
  fi

  parse_options "$@"
  typeset -p options
  init
  #echo "++++++++++++LOGMSG+++++++++" 1> >(tee /dev/tty >&9) 
  echo "+++++++++++HIDDEN LOGMSG+++++++++" 1> >(tee /proc/self/fd/8 >&9) 
  exec 8>&1
  echo "++++++++++++VISIBLE LOGMSG+++++++++" 1> >(tee /proc/self/fd/8 >&9) 
  run 
}

check_apps fzf getopt || exit 1
startup "$@" || exit 1

main "$@"

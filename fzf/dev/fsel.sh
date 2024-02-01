# shellcheck shell=bash

(return 0 2>/dev/null) && __sourced=1
[ -n "$__sourced" ] && echo "abort: this script cannot be sourced" >&2 && return 1

#set -eu

# globals
script=${0##*/}
tempdir=''

declare -A options_cnf=( \
  [logfile]='([short]="" [long]="LOGFILE" [arg]=":" [default]="/dev/null" [handler]="")'\
  [debug]='([short]="D" [long]="DEBUG" [arg]=":" [default]="" [handler]="")'
)

function init_options {
  declare -n cnf="$1"
  echo "cnf=$cnf"

  declare -p cnf

  local key
  for key in "${!cnf[@]}"; do
    declare -A entry=${cnf["$key"]}
    so="${cnf[short]}"
    lo="${cnf[long]}"
    de="${cnf[defaut]}"
    hd="${cnf[handler]}"
    echo "so=$so"
    echo "lo=$lo"
    echo "de=$de"
    echo "hd=$hd"
  done
  [ -n "$short" ] && short="-o $short"
  [ -n "$long" ] && long="-long $long"
  [ -n "$long" ] && long="${long::-1}"
  echo "$short $long"
}

declare -A Xoptions_cnf=( \
	[logfile]="-L:|--LOGFILE:|/dev/null" \
	[debug]="-D:|--DEBUG|/dev/null" \
)

function Xinit_options {
  [ "$1" = "cnf" ] || { declare -n cnf; cnf="$1"; }

  local short
  local long
  local def=""

  local pattern='^([^\|]*)\|([^\|]*)\|(.*)$'

  local key
  for key in "${!cnf[@]}"; do
    val="${cnf[$key]}"
    echo "$key=$val"
    if [[ "${val}" =~ ${pattern} ]]; then
    so="${BASH_REMATCH[1]}"
    lo="${BASH_REMATCH[2]}"
    in="${BASH_REMATCH[3]}"
    [ -n "$so" ] && so="${so:1}" && short="${short}$so"
    [ -n "$lo" ] && lo="${lo:2}" && long="$long$lo,"
    echo "so=$so"
    echo "lo=$lo"
    echo "in=$in"
    fi
  done
  [ -n "$short" ] && short="-o $short"
  [ -n "$long" ] && long="-long $long"
  [ -n "$long" ] && long="${long::-1}"
  echo "$short $long"
}


declare -A options
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
  declare -p options
  init
  #echo "++++++++++++LOGMSG+++++++++" 1> >(tee /dev/tty >&9) 
  echo "+++++++++++HIDDEN LOGMSG+++++++++" 1> >(tee /proc/self/fd/8 >&9) 
  exec 8>&1
  echo "++++++++++++VISIBLE LOGMSG+++++++++" 1> >(tee /proc/self/fd/8 >&9) 
  run 
}

check_apps fzf getopt || exit 1
declare -p options_cnf
init_options options_cnf

startup "$@" || exit 1

main "$@"

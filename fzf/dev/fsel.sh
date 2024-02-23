# shellcheck shell=bash

(return 0 2>/dev/null) && __sourced=1
[ -n "$__sourced" ] && echo "abort: this script cannot be sourced" >&2 && return 1

source helpers.lib.sh

#set -eu

# globals
script=${0##*/}
tempdir=''

declare -A options_cfg
options_cfg[logfile]='([short]="L" [long]="LOGFILE" [arg]=":" [default]="/dev/null" [handler]="" [help]="set the name of the logfile to <arg>")'
options_cfg[debug]='([short]="D" [long]="DEBUG" [arg]="::" [default]="0" [handler]="" [help]="set the debug level to <arg>")'
options_cfg[help]='([short]="h" [long]="help" [arg]="" [default]="" [handler]="usage" [help]="show help")'
options_cfg[query]='([short]="" [long]="query" [arg]=":" [default]="" [handler]="" [help]="set the query string to <arg>")'

function init_options {
  [ "$1" = "cfg" ] || { local -n cfg="$1"; }
  [ "$2" = "opts" ] || { local -n opts="$2"; }
  shift; shift

  local -A switch

  local getopt_oargs
  local getopt_largs

  local help_args

  local key
  for key in "${!cfg[@]}"; do
    declare -A entry=${cfg["$key"]}
    local short="${entry[short]}"
    local long="${entry[long]}"
    local arg="${entry[arg]}"
    local default="${entry[default]}"
    local handler="${entry[handler]}"
    local help="${entry[help]}"
#    echo "$key"
#    echo "$short"
#    echo "$long"
#    echo "$arg"
#    echo "$default"
#    echo "$handler"
    [ -n "$short" ] && getopt_oargs="${getopt_oargs}${short}${arg}"
    [ -n "$long" ] && getopt_largs="${getopt_largs}${long}${arg},"

    if [ -n "$help" ]; then
      local help_key
      if [ -n "$short" ]; then 
        help_key="${short,,}"
	help_args="$help_args($help_key)-$short"
	if [ -n "$arg" ]; then
	  help_args="$help_args <arg>"
	  [ "$arg" = '::' ] && help_args="$help_args (optional)"
	fi 
	if [ -n "$long" ]; then
	  help_args="$help_args or --${long}"
          [ -n "$arg" ] && help_args="$help_args <arg>"
	fi
	help_args="$help_args\n    $help\n\n"
      else
        if [ -n "$long" ]; then 
          help_key="${long:0:1}"
          help_key="${help_key,,}"
	  help_args="$help_args($help_key)--${long}"
	  if [ -n "$arg" ]; then
	    help_args="$help_args <arg>"
	    [ "$arg" = '::' ] && help_args="$help_args (optional)"
	  fi 
	  help_args="$help_args\n    $help\n\n"
	fi
      fi
    fi
    # TODO: env vars for init
    [ -n "$default" ] && opts[$key]="$default"

    local -A item
    item[arg]="$arg"
    item[key]="$key"
    item[handler]="$handler"

    local ser_item="$(declare -p item)"
    ser_item="${ser_item#"declare -A item="}"

    [ -n "$short" ] && switch[-$short]="$ser_item"
    [ -n "$long" ] && switch[--$long]="$ser_item"
  done
  echo -e "$help_args"
  [ -n "$getopt_largs" ] && getopt_largs="${getopt_largs::-1}"
  [ -n "$getopt_oargs" ] && getopt_oargs="${getopt_oargs}"
#  echo "$getopt_oargs $getopt_largs"
#  declare -p switch

  local opt err ec
  
#getopt -o ${getopt_oargs} -l ${getopt_largs} -- "$@"
#  catch opt err getopt -o hq: --long DEBUG:,help,LOGFILE:,query: -- "$@"; ec=$?
  catch opt err getopt -o ${getopt_oargs} -l ${getopt_largs} -- "$@"; ec=$?

  [ $ec -eq 1 ] && { echo >&2 "abort: $err"; } && exit 1
#  echo $opt
  eval set -- "$opt"
  echo "$@"
  while true; do
    local opt="$1"
    [ -z "$opt" ] && echo "abort: option parsing error" && exit 1
    shift
    [ "$opt" = '--' ] && break
    [ ! "${switch[$opt]+x}" ] && echo "abort: unknown option $opt" && exit 1
    local -A item="${switch[$opt]}"
    declare -p item
    local key="${item[key]}"
    local handler="${item[handler]}"
    [ -n "$handler" ] && $handler "$key"
    local arg="${item[arg]}"
    [ -n "$arg" ] && opts[$key]="$1" && shift
   done
 

}

declare -A Xoptions_cfg=( \
	[logfile]="-L:|--LOGFILE:|/dev/null" \
	[debug]="-D:|--DEBUG|/dev/null" \
)

function Xinit_options {
  [ "$1" = "cfg" ] || { declare -n cfg; cfg="$1"; }

  local short
  local long
  local def=""

  local pattern='^([^\|]*)\|([^\|]*)\|(.*)$'

  local key
  for key in "${!cfg[@]}"; do
    val="${cfg[$key]}"
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
#options[logfile]='/dev/null'
#options[debug]=0
#options[mute]=0

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

  return

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

init_options options_cfg options "$@" 
declare -p options

startup "$@" || exit 1

main "$@"

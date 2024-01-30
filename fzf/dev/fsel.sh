# shellcheck shell=bash

(return 0 2>/dev/null) && __sourced=1
[ -n "$__sourced" ] && echo "abort: this script cannot be sourced" >&2 && return 1

#set -eu

script=${0##*/}
tempdir=$(mktemp -d -t tmp.XXXXXXXXXX)
function cleanup {
  echo "cleanup: $tempdir"
  rm -rf "$tempdir"
}
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
  
  [ "$1" = "options" ] || { declare -n options; options="$1"; }
  shift

  local ec
  local o

  o=$(getopt -o q: --long toggle-searcher --long query: -- "$@") && ec=$?
  [ $ec -eq 0 ] || { echo >&2 "abort: incorrect options provided"; return 1; }
  eval set -- "$o"
  while true; do
    case "$1" in
      --toggle-searcher)
	echo "toggle-searcher"
      ;;
      --toggle-hidden)
	echo "toggle-hidden"
      ;;
      --query)
        shift
        options[query]="$1"
      ;;
      -q)
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
}

parse_first_run_options() {
  [ "$1" = "options" ] || { declare -n options; options="$1"; }
  shift

  local ec
  local o

  o=$(getopt -o hq: --long help --long query: -- "$@") && ec=$?
  [ $ec -eq 0 ] || { echo >&2 "abort: incorrect options provided"; return 1; }
  eval set -- "$o"
  while true; do
    case "$1" in
      -h)
        usage
      ;;
      --help)
        usage
      ;;
      -q)
        shift
        options[query]="$1"
      ;;
      --query)
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
}

first_run() {
  typeset -A opts
  echo "first run"
  parse_first_run_options opts "$@"
  echo "query = '${opts[query]}'"
  exit 0
}

run() {
  typeset -A opts
  echo "run"
  parse_options opts "$@"
  echo "query = '${opts[query]}'"
  exit 0
}

main()
{
  echo "main"
  check_apps fzf getopt || exit 1

  [ -z "$1" ] && first_run "$@"
  case "$1" in
    ++)
      shift
      run "$@"
    ;;
    *)
      first_run "$@"
    ;;
  esac
}

main "$@"

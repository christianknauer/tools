# shellcheck shell=bash

(return 0 2>/dev/null) && __sourced=1
[ -n "$__sourced" ] && echo "abort: this script cannot be sourced" >&2 && return 1

# helper functions
function catch() {
    {
        IFS=$'\n' read -r -d '' "${1}";
        IFS=$'\n' read -r -d '' "${2}";
        (IFS=$'\n' read -r -d '' _ERRNO_; return ${_ERRNO_});
    } < <((printf '\0%s\0%d\0' "$(((({ shift 2; "${@}"; echo "${?}" 1>&3-; } | tr -d '\0' 1>&4-) 4>&2- 2>&1- | tr -d '\0' 1>&4-) 3>&1- | exit "$(cat)") 4>&1-)" "${?}" 1>&2) 2>&1)
}

#set -eu

# globals
script=${0##*/}

declare -A options_cfg
options_cfg[logfile]='(
  [short]="L" 
  [long]="LOGFILE" 
  [arg]=":" 
  [arg_type]="string" 
  [default]="/dev/null" 
  [handler]="" 
  [help]="set the name of the logfile"
)'
options_cfg[debug]='([short]="D" [long]="DEBUG" [arg]="::" [arg_type]="int" [default]="0" [handler]="" [help]="set the debug level")'
options_cfg[help]='([short]="h" [long]="help" [arg]="" [arg_type]="" [default]="" [handler]="usage" [help]="show help")'
options_cfg[query]='([short]="" [long]="query" [arg]=":" [arg_type]="string"  [default]="" [handler]="" [help]="set the query string")'

usage() 
{
  local usage
  local flags
  [ -n "$usage_flags" ] && flags=" [flags]"

  read -r -d '' usage <<EOF
  Usage: $script$flags <query> 

$usage_flags
EOF
  echo -e "$usage" 1>&2
  exit 0
}

function flags_help {
  [ "$1" = "cfg" ] || { local -n cfg="$1"; }

  local help_args
  local -A flags

  local ctr=0
  local key
  for key in "${!cfg[@]}"; do
    ((ctr++))
    declare -A entry=${cfg["$key"]}
    local short="${entry[short]}"
    local long="${entry[long]}"
    local arg="${entry[arg]}"
    local arg_type="${entry[arg_type]}"
    local default="${entry[default]}"
    local help="${entry[help]}"
          
    [ -z "$arg_type" ] && arg_type="arg"

    local flag 

    if [ -n "$help" ]; then
      local help_key=$(printf "%02d" $ctr)
      if [ -n "$short" ]; then 
        help_key="${short}${help_key}"
	flag="  -$short"
	[ -n "$long" ] && flag="$flag, --${long}"
      else
        if [ -n "$long" ]; then 
          help_key="${long:0:1}${help_key}"
	  flag="      --${long}"
	fi
      fi
      if [ -n "$flag" ]; then 
          [ -n "$arg" ] && flag="$flag <$arg_type>"
	  flag="$flag                                        "
	  flag=${flag:0:38}
	  flag="$flag$help"

	  local remark second
	  second=""
	  remark=""
	  [ -n "$default" ] && remark="default \"$default\""
	  [ "$arg" = '::' ] && remark="$remark, optional"
	  [ -n "$remark" ] && second="                                      ($remark)\n"

	  flag="$flag\n$second"
          help_key="${help_key,,}"
	  flags["$help_key"]="$flag"
      fi
    fi
  done

  #  declare -p flags
  mapfile -d '' sorted < <(printf '%s\0' "${!flags[@]}" | sort -z)
  for k in "${sorted[@]}"; do
    help_args="$help_args$(printf '%s' "${flags[$k]}")"
  done
 
  [ -n "$help_args" ] && help_args="flags:\n$help_args"
  echo "$help_args"
}

parse_options_config () {
  [ "$1" = "cfg" ] || { local -n cfg="$1"; }
  [ "$2" = "switch" ] || { local -n switch="$2"; }

  local getopt_oargs
  local getopt_largs

  local key
  for key in "${!cfg[@]}"; do
    declare -A entry=${cfg["$key"]}
    local short="${entry[short]}"
    local long="${entry[long]}"
    local arg="${entry[arg]}"
    local handler="${entry[handler]}"

    [ -n "$short" ] && getopt_oargs="${getopt_oargs}${short}${arg}"
    [ -n "$long" ] && getopt_largs="${getopt_largs}${long}${arg},"

    local -A item
    item[arg]="$arg"
    item[key]="$key"
    item[handler]="$handler"

    local ser_item="$(declare -p item)"
    ser_item="${ser_item#"declare -A item="}"

    [ -n "$short" ] && switch[-$short]="$ser_item"
    [ -n "$long" ] && switch[--$long]="$ser_item"
  done

  [ -n "$getopt_largs" ] && getopt_largs="${getopt_largs::-1}"

  switch[oargs]="$getopt_oargs"
  switch[largs]="$getopt_largs"
}

parse_options() {

  [ "$1" = "switch" ] || { local -n switch="$1"; }
  [ "$2" = "opts" ] || { local -n opts="$2"; }
  shift; shift

  local getopt_oargs="${switch[oargs]}"
  local getopt_largs="${switch[largs]}"
  local opt err ec
  
  catch opt err getopt -o ${getopt_oargs} -l ${getopt_largs} -- "$@"; ec=$?
  [ $ec -eq 1 ] && { echo >&2 "abort: $err"; } && exit 1
  eval set -- "$opt"

  while true; do
    local opt="$1"
    [ -z "$opt" ] && echo "abort: option parsing error" && exit 1
    shift
    [ "$opt" = '--' ] && break
    [ ! "${switch[$opt]+x}" ] && echo "abort: unknown option $opt" && exit 1
    local -A item="${switch[$opt]}"
    local key="${item[key]}"
    local arg="${item[arg]}"
    local handler="${item[handler]}"
    [ -n "$handler" ] && $handler "$key"
    [ -n "$arg" ] && opts[$key]="$1" && shift
   done
  # rest of argv
  echo "$@"
}

declare -A options
declare -A switch

usage_flags="$(flags_help options_cfg)"

parse_options_config options_cfg switch
declare -p switch
parse_options switch options "$@" 

declare -p options

# EOF

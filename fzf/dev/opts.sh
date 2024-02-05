# shellcheck shell=bash

(return 0 2>/dev/null) && __sourced=1
[ -n "$__sourced" ] && echo "abort: this script cannot be sourced" >&2 && return 1

source debug.lib.sh

usage_flags=''
usage_envvars=''
usage_config=''

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
script_stem="${script%.*}"

declare -A options_cfg
options_cfg[secret]='(
  [description]="secret option only for the ini file"
  [type]="string" 
  [init]="topsecret" 
#  [short]="" 
#  [long]="" 
#  [arg]="" 
#  [handler]="" 
#  [help]=""
)'
options_cfg[logfile]='(
  [description]="name of the logfile"
  [type]="string" 
  [init]="/dev/null" 
  [short]="L" 
  [long]="LOGFILE" 
  [arg]="req" 
#  [handler]="" 
  [help]="specify the name of the logfile"
)'
options_cfg[debug]='(
  [description]="debug level"
  [type]="int" 
  [init]="0" 
  [short]="D" 
  [long]="DEBUG" 
  [arg]="opt:1" 
#  [handler]="" 
  [help]="specify the debug level"
)'
options_cfg[help]='(
#  [description]=""
  [type]="bool"
#  [init]=""
  [short]="h"
  [long]="help"
#  [arg]=""
  [handler]="usage"
  [help]="show help"
)'
options_cfg[query]='(
#  [description]=""
  [type]="string"  
#  [init]="" 
#  [short]="" 
  [long]="query" 
  [arg]="req" 
#  [handler]="" 
  [help]="specify the query string"
)'

usage() 
{
  local usage
  local flags
  [ -n "$usage_flags" ] && flags=" [flags]" && usage_flags="$usage_flags\n"
  [ -n "$usage_envvars" ] && usage_envvars="$usage_envvars\n"

  read -r -d '' usage <<EOF
  Usage: $script$flags <query> 

$usage_flags$usage_envvars$usage_config
EOF
  echo -e "$usage" 1>&2
  exit 0
}

function init_config {
  [ "$1" = "opts_cfg" ] || { local -n opts_cfg="$1"; }
  [ "$2" = "opts" ] || { local -n opts="$2"; }

  local key; for key in "${!opts_cfg[@]}"; do
    declare -A data=${opts_cfg["$key"]}
    local init="${data[init]}"
    [ -n "${init}" ] && opts["$key"]="${data[init]}"
  done
}

function generate_config_help {

  [ "$1" = "opts_cfg" ] || { local -n opts_cfg="$1"; }

  local indent="                                      " 

  local -A entries

  local ctr=0
  local key; for key in "${!opts_cfg[@]}"; do
    ((ctr++))
    declare -A data=${opts_cfg["$key"]}
    local short="${data[short]}"
    local long="${data[long]}"
    local arg="${data[arg]}"
    local type="${data[type]}"
    local init="${data[init]}"
    local help="${data[help]}"
    local description="${data[description]}"
          
    [ -z "$type" ] && type="arg"

    local entry 

    if [ -n "$description" ]; then
      help_key="${key,,}"
      entry="  $key ($type)$indent"
      entry=${entry:0:38}
      entry="$entry$description"

      local remark=""
      [ -n "$init" ] && remark="\n${indent}(default \"$init\")"
      entry="$entry$remark\n"
      
      remark=""
      local plural=""
      if [ -n "$short" ]; then 
	remark="${indent}- -$short"
	[ -n "$long" ] && remark="${remark}, --${long}" && plural="s"
      else
	[ -n "$long" ] && remark="${indent}- --${long}"
      fi
      [ -n "$remark" ] && remark="${remark} flag${plural}\n"

      local envvar="conf_${script_stem}_${key}"
      remark="${remark}${indent}- ${envvar^^} environment variable\n"
      [ -n "$remark" ] && remark="${indent}overridden by:\n${remark}\n"
      entry="$entry$remark"

      help_key="${help_key,,}"
      entries["$help_key"]="$entry"
    fi
  done

  local result
  mapfile -d '' sorted < <(printf '%s\0' "${!entries[@]}" | sort -z)
  for k in "${sorted[@]}"; do
    result="$result$(printf '%s' "${entries[$k]}")"
  done
 
  [ -n "$result" ] && result="config file entries:\n$result"
  echo "$result"
}

function generate_flags_help {
  [ "$1" = "opts_cfg" ] || { local -n opts_cfg="$1"; }

  local -A entries

  local ctr=0
  local key; for key in "${!opts_cfg[@]}"; do
    ((ctr++))
    declare -A data=${opts_cfg["$key"]}
    local short="${data[short]}"
    local long="${data[long]}"
    local arg="${data[arg]}"
    local type="${data[type]}"
    local init="${data[init]}"
    local help="${data[help]}"
          
    [ -z "$type" ] && type="arg"

    local entry 

    if [ -n "$help" ]; then
      local help_key=$(printf "%02d" $ctr)
      if [ -n "$short" ]; then 
        help_key="${short}${help_key}"
	entry="  -$short"
	[ -n "$long" ] && entry="$entry, --${long}"
      else
        if [ -n "$long" ]; then 
          help_key="${long:0:1}${help_key}"
	  entry="      --${long}"
	fi
      fi
      if [ -n "$entry" ]; then 
          [ -n "$arg" ] && entry="$entry <$type>"
	  entry="$entry                                        "
	  entry=${entry:0:38}
	  entry="$entry$help"

	  local remark=""
	  [ -n "$init" ] && remark="default \"$init\""
#	  [ "$arg" = 'opt' ] && remark="$remark, optional"
          [[ "$arg" =~ ^opt:(.*)$ ]] && remark="$remark, optional"
	  [ -n "$remark" ]  && remark="                                      ($remark)\n"
	  entry="$entry\n$remark"

          help_key="${help_key,,}"
	  entries["$help_key"]="$entry"
      fi
    fi
  done

  local result
  mapfile -d '' sorted < <(printf '%s\0' "${!entries[@]}" | sort -z)
  for k in "${sorted[@]}"; do
    result="$result$(printf '%s' "${entries[$k]}")"
  done
 
  [ -n "$result" ] && result="flags:\n$result"
  echo "$result"
}

parse_options_config () {
  [ "$1" = "cfg" ] || { local -n cfg="$1"; }
  if [ -z "$2" ]; then
    local -A option_table
  else
    [ "$2" = "option_table" ] || { local -n option_table="$2"; }
  fi

  local getopt_oargs
  local getopt_largs

  local key
  for key in "${!cfg[@]}"; do
    declare -A data=${cfg["$key"]}
    local short="${data[short]}"
    local long="${data[long]}"
    local arg="${data[arg]}"
    local handler="${data[handler]}"

    local suffix=''
    # [ "$arg" = 'opt' ] && suffix='::'
    [ "$arg" = 'req' ] && suffix=':'
    [[ "$arg" =~ ^opt:(.*)$ ]] && suffix='::'
#    if [[ "$arg" =~ ^opt:(.*)$ ]]; then
#      suffix='::'
#      local def="${BASH_REMATCH[1]}"
#      echo "opt detected $key=$def"
#    fi

    [ -n "$short" ] && getopt_oargs="${getopt_oargs}${short}${suffix}"
    [ -n "$long" ] && getopt_largs="${getopt_largs}${long}${suffix},"

    local -A item
    item[arg]="$arg"
    item[key]="$key"
    item[handler]="$handler"

    local ser_item="$(declare -p item)"
    ser_item="${ser_item#"declare -A item="}"

    [ -n "$short" ] && option_table[-$short]="$ser_item"
    [ -n "$long" ] && option_table[--$long]="$ser_item"
  done

  [ -n "$getopt_largs" ] && getopt_largs="${getopt_largs::-1}"

  option_table[oargs]="$getopt_oargs"
  option_table[largs]="$getopt_largs"

  local retval="$(declare -p option_table)"
  echo "${retval#"declare -A option_table="}"
}

parse_options() {

  [ "$1" = "option_table" ] || { local -n option_table="$1"; }
  [ "$2" = "opts" ] || { local -n opts="$2"; }
  shift; shift

  local getopt_oargs="${option_table[oargs]}"
  local getopt_largs="${option_table[largs]}"
  local opt err ec
  
  catch opt err getopt -o ${getopt_oargs} -l ${getopt_largs} -- "$@"; ec=$?
  if [ $ec -eq 1 ]; then
    err="${err#"getopt: "}"
    echo >&2 "abort: $err"
    exit 1
  fi

  eval set -- "$opt"

  while true; do
    local opt="$1"
    [ -z "$opt" ] && echo "abort: option parsing error" && exit 1
    shift
    [ "$opt" = '--' ] && break
    [ ! "${option_table[$opt]+x}" ] && echo "abort: unknown option $opt" && exit 1
    local -A item="${option_table[$opt]}"
    local key="${item[key]}"
    local arg="${item[arg]}"
    local handler="${item[handler]}"
    [ -n "$handler" ] && $handler "$key"

#   [ -n "$arg" ] && opts[$key]="$1" && shift
    [ "$arg" = 'req' ] && opts[$key]="$1" && shift

    if [[ "$arg" =~ ^opt:(.*)$ ]]; then
       opts[$key]="${BASH_REMATCH[1]}"
       [ -n "$1" ] && opts[$key]="$1"
       shift
    fi

   done
  # rest of argv
  echo "$@"
}

declare -A options

usage_flags="$(generate_flags_help options_cfg)"
usage_config="$(generate_config_help options_cfg)"

# use with reference
#declare -A option_table
#parse_options_config options_cfg option_table

# or use with return value
#parse_options_config options_cfg
declare -A option_table="$(parse_options_config options_cfg)"

#declare -p option_table
# breakpoint

init_config options_cfg options "$@" 
# read_config options $file
# config_from_env options

declare -p options

parse_options option_table options "$@" 
declare -p options

# EOF

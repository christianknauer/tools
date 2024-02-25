#!/bin/env bash
# shellcheck shell=bash

# option handling

[ -n "${OPTS_LIB}" ] && return; OPTS_LIB=0; # pragma once

source helpers.lib.sh

# globals

# private
__opts__script=''
__opts__script_stem=''

# functions

# helpers
opts::create_env_var_name() {
  local key="$1"
  [ -z "$key" ] && echo >&2 "abort: expected a key" && exit 1
  local env="CONF_${__opts__script_stem^^}_${key^^}"
  # sanitize
  echo "${env//-/_}"
}
 
# public
opts::init() {
  [ -z "$1" ] && echo >&2 "abort: expected a name" && exit 1
  __opts__script="${1##*/}"
  __opts__script_stem="${__opts__script%.*}"
}

opts::usage() {
  local usage
  local flags
  [ -n "$usage_flags" ]   && flags=" [flags]" && usage_flags="$usage_flags\n"
  [ -n "$usage_envvars" ] && usage_envvars="$usage_envvars\n"

  read -r -d '' usage <<EOF
  Usage: ${__opts__script}$flags <query> 

$usage_flags$usage_envvars$usage_config
EOF
  echo -e "$usage" 1>&2
  exit 0
}

opts::set_options() {
  [ "$1" = "option_table" ] || { local -n option_table="$1"; }
  [ "$2" = "opts" ] || { local -n opts="$2"; }
  [ "$3" = "cfg_file" ] || { local -n cfg_file="$3"; }
  local mode="$4"
  [ -z "$mode" ] && mode='fe'

  echo >&2 "opts::set_options ($mode) ------------------------------------------ <<<"

  local key; for key in "${!option_table[@]}"; do

    # declare -A data=${option_table["$key"]}
    local val="${option_table[$key]}"
    local pattern='^declare -(.) ([^=]*)='; if [[ "${val}" =~ ${pattern} ]]; then
      local type="${BASH_REMATCH[1]}"
      val="${val#declare -"${type}" *=}"
      local -"${type}" data="${val}"
    else
      echo >&2 "abort: expected a dictionary" && return 1
    fi

    local init="${data[init]}"
    local modes="${data[modes]}"
    # set by ini file
    if [[ "$mode" =~ f && "$modes" =~ f ]]; then
	if [ ! "${cfg_file[$key]+x}" ]; then
	  echo >&2 "key \"$key\" - not in config file"
        else
	  local def="${cfg_file[$key]}"
	  echo >&2 "key \"$key\" - found in config file (\"$def\")"
	  if [ "${opts[$key]+x}" ]; then
	    echo >&2 -n "key \"$key\" currently not empty, overwriting by \"$def\"" 
	  fi
          opts["$key"]="$def" 
	fi
    fi
    # set by environment var
    if [[ "$mode" =~ e && "$modes" =~ e ]]; then
      local env="${data[env]}"
      [ -z "$env" ] && echo >&2 "key \"$key\" error: has e-mode but no env var set" && continue
      [ -z "${!env}" ] && echo >&2 "key \"$key\" - env var $env not set" && continue
      [ "${opts[$key]+x}" ] && echo >&2 -n "key \"$key\" not empty, overwriting by " || echo >&2 -n "key \"$key\" set to " 
      opts["$key"]="${!env}" 
      echo >&2 "env var $env (${!env})"
    fi
    # set default values
    if [[ "$mode" =~ d ]]; then
      # finally an unset key is given the init value (if defined)
      [ -z "$init" ] && echo >&2 "key \"$key\" - does not define an init value" && continue
      [ "${opts[$key]+x}" ] && echo >&2 "key \"$key\" already has a value - unchanged" && continue
      [ -n "$init" ] && opts["$key"]="${data[init]}" && echo >&2 "key \"$key\" - set to default value \"$init\""
    fi
  done

  echo >&2 "opts::set_options ($mode) ========================================== >>>"
}

opts::generate_config_help() {
  [ "$1" = "opts_cfg" ] || { local -n opts_cfg="$1"; }

  local indent="                                      " 

  local -A entries

  local ctr=0
  local key; for key in "${!opts_cfg[@]}"; do
    ((ctr++))
#    declare -A data=${opts_cfg["$key"]}
    local val="${opts_cfg[$key]}"
    local pattern='^declare -(.) ([^=]*)='; if [[ "${val}" =~ ${pattern} ]]; then
      local type="${BASH_REMATCH[1]}"
      val="${val#declare -"${type}" *=}"
      local -"${type}" data="${val}"
    else
      echo >&2 "abort: expected a dictionary" && return 1
    fi

    local short="${data[short]}"
    local long="${data[long]}"
    local type="${data[type]}"
    local init="${data[init]}"
    local env="${data[env]}"
    local modes="${data[modes]}"
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

      if [[ "$modes" =~ e ]]; then
        local envvar="$env"
	[ -z "$envvar" ] && envvar=$(opts::create_env_var_name "$key")
        remark="${remark}${indent}- environment variable ${envvar^^}\n"
      fi
      if [[ "$modes" =~ f ]]; then
	local confvar="configuration file entry \"${key}\""
        remark="${remark}${indent}- ${confvar}\n"
      fi
 
      [ -n "$remark" ] && remark="${indent}specified by:\n${remark}\n"
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

opts::generate_flags_help() {
  [ "$1" = "opts_cfg" ] || { local -n opts_cfg="$1"; }

  local -A entries

  local ctr=0
  local key; for key in "${!opts_cfg[@]}"; do
    ((ctr++))
    local val="${opts_cfg[$key]}"
#    echo >&2 $key
#    echo >&2 $val

    local pattern='^declare -(.) ([^=]*)='; if [[ "${val}" =~ ${pattern} ]]; then
      local type="${BASH_REMATCH[1]}"
      val="${val#declare -"${type}" *=}"
      local -"${type}" data="${val}"
#      declare -p data >&2
    else
      echo >&2 "abort: expected a dictionary" && return 1
    fi
#    data=${opts_cfg["$key"]}
# local -A data
    # get "$key" entry from opts_cfg and add it to data
#    dicts::get_entry_from_dict ${!opts_cfg} data "$key" 
    local short="${data[short]}"
    local long="${data[long]}"
    local arg="${data[arg]}"
    local type="${data[type]}"
    local init="${data[init]}"
    local help="${data[help]}"
          
    [ -z "$type" ] && type="arg"

    local entry 

    local type_descr="<$type>"
    [[ "$arg" =~ ^opt:(.*)$ ]] && type_descr="[$type_descr]"

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
          #[ -n "$arg" ] && entry="$entry <$type>"
          [ -n "$arg" ] && entry="$entry $type_descr"
	  entry="$entry                                        "
	  entry=${entry:0:38}
	  entry="$entry$help"

	  local remark=""
	  [ -n "$init" ] && remark="default \"$init\""
          [[ "$arg" =~ ^opt:(.*)$ ]] && remark="$remark, \"${BASH_REMATCH[1]}\" if no value given"
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

opts::parse_options_config_for_env () {
  [ "$1" = "opts_cfg" ] || { local -n opts_cfg="$1"; }
  local -A option_table

  local key; for key in "${!opts_cfg[@]}"; do

    #declare -A data=${cfg["$key"]}
    local val="${opts_cfg[$key]}"
    local pattern='^declare -(.) ([^=]*)='; if [[ "${val}" =~ ${pattern} ]]; then
      local type="${BASH_REMATCH[1]}"
      val="${val#declare -"${type}" *=}"
      local -"${type}" data="${val}"
    else
      echo >&2 "abort: expected a dictionary" && return 1
    fi

    local env="${data[env]}"
    local modes="${data[modes]}"
    local init="${data[init]}"

    #[[ "$modes" =~ e ]] && [ -z "$env" ] && env="CONF_${__opts__script_stem^^}_${key^^}" && echo >&2 "key \"$key\": no env var name given, computed as $env" 
    if [[ "$modes" =~ e ]] && [ -z "$env" ]; then
      env=$(opts::create_env_var_name "$key")
      echo >&2 "key \"$key\": no env var name given, computed as $env" 
    fi

    [[ ! "$modes" =~ f ]] && [[ ! "$modes" =~ e ]] && [ -z "$init" ] && echo >&2 "key \"$key\": no env var setting, no file setting, no init value, skipping" && continue

    local -A item
    unset item[env]
    unset item[init]
    unset item[modes]
    [ -n "$env" ]  && item[env]="$env"
    [ -n "$init" ] && item[init]="$init"
    item[modes]="$modes"

    dicts::add_entry_to_dict option_table "$key" item  

#    local ser_item="$(declare -p item)"
#    ser_item="${ser_item#"declare -A item="}"
#    option_table["$key"]="$ser_item"
  done

  local retval="$(declare -p option_table)"
  echo "${retval#"declare -A option_table="}"
}

opts::parse_options_config () {
  [ "$1" = "opts_cfg" ] || { local -n opts_cfg="$1"; }

  local -A option_table

  local getopt_oargs
  local getopt_largs

  local key; for key in "${!opts_cfg[@]}"; do
#    declare -A data=${opts_cfg["$key"]}
    local val="${opts_cfg[$key]}"
    local pattern='^declare -(.) ([^=]*)='; if [[ "${val}" =~ ${pattern} ]]; then
      local type="${BASH_REMATCH[1]}"
      val="${val#declare -"${type}" *=}"
      local -"${type}" data="${val}"
    else
      echo >&2 "abort: expected a dictionary" && return 1
    fi

    local short="${data[short]}"
    local long="${data[long]}"
    local arg="${data[arg]}"
    local action="${data[action]}"

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
    [ -n "$long" ]  && getopt_largs="${getopt_largs}${long}${suffix},"

    local -A item
    unset item[key]
    unset item[arg]
    unset item[action]
    unset item["$short"]
    unset item["$long"]

    item[key]="$key"
    [ -n "$arg" ]    && item[arg]="$arg"
    [ -n "$action" ] && item[action]="$action"
    [ -n "$short" ]  && dicts::add_entry_to_dict option_table "-$short" item  
    [ -n "$long" ]   && dicts::add_entry_to_dict option_table "--$long" item  

#    local ser_item="$(declare -p item)"
#    ser_item="${ser_item#"declare -A item="}"
#
#    [ -n "$short" ] && option_table[-$short]="$ser_item"
#    [ -n "$long" ] && option_table[--$long]="$ser_item"
  done

  [ -n "$getopt_largs" ] && getopt_largs="${getopt_largs::-1}"

  option_table[oargs]="$getopt_oargs"
  option_table[largs]="$getopt_largs"

  local retval="$(declare -p option_table)"
  echo "${retval#"declare -A option_table="}"
}

opts::parse_options() {
  [ "$1" = "option_table" ] || { local -n option_table="$1"; }
  [ "$2" = "opts" ] || { local -n opts="$2"; }
  [ "$3" = "remainder" ] || { local -n remainder="$3"; }
  shift; shift; shift

  local getopt_oargs="${option_table[oargs]}"
  local getopt_largs="${option_table[largs]}"
  local opt err ec
  
  helpers::catch opt err getopt -o ${getopt_oargs} -l ${getopt_largs} -- "$@"; ec=$?
  if [ $ec -eq 1 ]; then
    err="${err#"getopt: "}"
    echo >&2 "abort: $err"
    exit 1
  fi

  eval set -- "$opt"

  while true; do
    local opt="$1"
    [ -z "$opt" ] && echo >&2 "abort: option parsing error" && return 1
    shift
    [ "$opt" = '--' ] && break
    [ ! "${option_table[$opt]+x}" ] && echo >&2 "unknown option $opt" && continue
#    local -A item="${option_table[$opt]}"
    local val="${option_table[$opt]}"
    local pattern='^declare -(.) ([^=]*)='; if [[ "${val}" =~ ${pattern} ]]; then
      local type="${BASH_REMATCH[1]}"
      val="${val#declare -"${type}" *=}"
      local -"${type}" item="${val}"
    else
      echo >&2 "abort: expected a dictionary" && return 1
    fi
    local key="${item[key]}"
    local arg="${item[arg]}"
    local action="${item[action]}"
    [ -n "$action" ] && $action "$key" && continue

#   [ -n "$arg" ] && opts[$key]="$1" && shift
#    [ "$arg" = 'req' ] && opts[$key]="$1" && shift
    if [ "$arg" = 'req' ]; then
      [ "${opts[$key]+x}" ] && echo >&2 "option \"$key\" overridden"
      opts[$key]="$1" 
      shift
    elif [[ "$arg" =~ ^opt:(.*)$ ]]; then
      [ "${opts[$key]+x}" ] && echo >&2 "option \"$key\" overridden"
      opts[$key]="${BASH_REMATCH[1]}"
      [ -n "$1" ] && opts[$key]="$1"
      shift
    elif [ -z "$arg" ]; then
      :
    else
      echo >&2 "unknown flag mode \"$arg\" for \"$key\"" && continue
    fi

  done
  # rest of argv
  remainder="$@"
}

# EOF

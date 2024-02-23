# shellcheck shell=bash

# package ini
#
# read/write dicts from/to ini-files

source helpers.lib.sh

ini::ini_to_dict() {
  [ "$1" = "arr" ] || { declare -n arr; arr="$1"; }
  local ini_file="$2"

  #local sec=""

  while IFS="\n" read -r kv; do

    kv_tmp="${kv//\\\"/_}"
    kv_tmp="${kv_tmp//\\=/_}"

    local sec_pattern='^\[(.+)\]$'
    local cmt_pattern='^#(.*)$|^\s*$'
    local kv_pattern='^"([^="]+)"="([^="]*)"$'

    if [[ "${kv}" =~ ${sec_pattern} ]]; then
      # no function currently
      #sec="${BASH_REMATCH[1]}"
      :
    elif [[ "${kv}" =~ ${cmt_pattern} ]]; then
      :
      # read a comment line - skipping
    elif [[ "${kv_tmp}" =~ ${kv_pattern} ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
    
      keyi=${kv_tmp%%$key*}
      vali=${kv_tmp%%$value*}

      kv_raw="${kv//\\\"/\"}"
      kv_raw="${kv_raw//\\=/=}"
      key="${kv_raw:${#keyi}:${#key}}"
      value="${kv_raw:${#vali}:${#value}}"

      [ "${arr[$key]+x}" ] && echo "$key duplicate detected"
      arr["$key"]="$value"
    else
      echo "info: ignoring malformed line $kv" 
    fi

  done < <(cat "$ini_file")
}

# EOF

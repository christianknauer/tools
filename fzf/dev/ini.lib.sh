# shellcheck shell=bash

# package ini
#
# read/write arrays from/to ini-files

# recursion with namerefs is tricky
# we need to make sure that the local name
# does not collide with a name higher up the
# call chain.

ini::serialize_array_to_string2() {

#   local _name="_name_$$$RANDOM"
#   while [ "$1" = "$$$_name" ]; do
#     _name="_name_$$$RANDOM"
#   done
#   declare -n arr="$_name"
#   local -A ${!arr}="$1"
#   declare -p ${!arr}

  ##WORKS
  [ "$1" = "arr" ] || { local -n arr; arr="$1"; }
  declare -p ${!arr}

  local depth=$2
  [ -z "$depth" ] && depth=0
 
  local indent="                                    "
  indent=${indent:0:((depth*2))}
  ((depth++))

  local res=""
  local key; for key in "${!arr[@]}"; do
    local val="${arr[$key]}"
    local pkey="${key//\"/\\\\\"}"
    pkey="${pkey//=/\\\\=}"
    local pval="${val//\"/\\\\\"}"
    pval="${pval//=/\\\\=}"
#    echo "\n$key/$pkey  --  $val/$pval"
#    declare -p ${!arr}
    if [[ "$val" =~ ^\((.*)\)$ ]]; then
      res+="${indent}[$pkey]\n"

      declare -n data="data$$$depth$RANDOM"
      local -A ${!data}="${val}"
#      declare -p ${!data}
      res+="$(ini::serialize_array_to_string2 ${!data} $depth)"

      res+="${indent}[/$pkey]\n"
    else
      res+="$indent\"$pkey\"=\"$pval\"\n"
    fi
  done
  echo "$res"
}

ini::serialize_array_to_string() {
  [ "$1" = "arr" ] || { declare -n arr; arr="$1"; }

  local res=""
  local key; for key in "${!arr[@]}"; do
    val="${arr[$key]}"
    pkey="${key//\"/\\\\\"}"
    pkey="${pkey//=/\\\\=}"
    pval="${val//\"/\\\\\"}"
    pval="${pval//=/\\\\=}"
    res+="\"$pkey\"=\"$pval\"\n"
  done
  echo "$res"
}

ini::read_array_from_file() {
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

# shellcheck shell=bash

# package ini
#
# read/write arrays from/to ini-files

# recursion with namerefs is tricky
# we need to make sure that the local name
# does not collide with a name higher up the
# call chain.

ini::create_argname() {
   local avoid="$1"
   local base="$2"; [ -z "$base" ] && base="a${RANDOM}"
   base="${base}_${#FUNCNAME[@]}_$$_"
   local argname="${base}${RANDOM}"
   while [ "$avoid" = "$argname" ]; do
     argname="${base}${RANDOM}"
   done
   echo "$argname"
}

ini::get_dict_from_dict() {
  [ "$1" = "dict" ] || { local -n dict; dict="$1"; }
  [ "$2" = "out" ] || { local -n out; out="$2"; }
  local key="$3"
  local -A res=${dict["$key"]}
  # adding the elements one-by-one
  # there should be a nicer way to do that ...
  local k; for k in "${!res[@]}"; do
    out["$k"]="${res[$k]}"
  done
  return
}

ini::add_dict_to_dict() {
  [ "$1" = "dict" ] || { local -n dict; dict="$1"; }
  local key="$2"
  [ "$3" = "val" ] || { local -n val; val="$3"; }
 
  local serialized="$(declare -p "${!val}")"
  serialized="${serialized#declare -A *=}"
  dict["$key"]="$serialized"
}

# works 
ini::serialize_array_to_string() {
  [ "$1" = "arr" ] || { local -n arr; arr="$1"; }

  local depth=$2
  [ -z "$depth" ] && depth=0
 
  local indent="                                    "
  indent=${indent:0:((depth*4))}
  ((depth++))

  local res=""
  local key; for key in "${!arr[@]}"; do
    local val="${arr[$key]}"
    local pkey="${key//\"/\\\\\"}"
    pkey="${pkey//=/\\\\=}"
    local pval="${val//\"/\\\\\"}"
    pval="${pval//=/\\\\=}"
#    echo >&2 -e -n "\n$indent$key ------------ "
#    echo >&2 $(declare -p ${!arr})
#    echo >&2 -e "$indent]\n"
    if [[ "$val" =~ ^\((.*)\)$ ]]; then
      res+="${indent}[$pkey]\n"

      #declare -n data="data$$$depth$RANDOM"
      local -n data="$(ini::create_argname)"
      local -A ${!data}="${val}"
#      echo >&2 -e -n "\n$indent ------------ "
#      echo >&2 $(declare -p ${!data})
      res+="$(ini::serialize_array_to_string ${!data} $depth)"
      res+="${indent}[/$pkey]\n"
      unset -n data
      unset "${!data}"
    else
      res+="$indent\"$pkey\"=\"$pval\"\n"
    fi
  done
  echo "$res"
}

ini::serialize_array_to_string_old() {
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

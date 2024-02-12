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

# https://stackoverflow.com/questions/14525296/how-do-i-check-if-variable-is-an-array

ini::array_test() {
    # no argument passed
    [[ $# -ne 1 ]] && echo 'Supply a variable name as an argument'>&2 && return 2
    local var=$1
    # use a variable to avoid having to escape spaces
    local regex="^declare -[aA] ${var}(=|$)"
    [[ $(declare -p "$var" 2> /dev/null) =~ $regex ]] && return 0
}

ini::serialize() {
  local var=$(declare -p "$1" 2>/dev/null)
  local reg='^declare -n [^=]+=\"([^\"]+)\"$'
  while [[ $var =~ $reg ]]; do
    var=$(declare -p "${BASH_REMATCH[1]}")
  done
  echo "${var}"
}


ini::get_type() {
    local var=$(declare -p "$1" 2>/dev/null)
    local reg='^declare -n [^=]+=\"([^\"]+)\"$'
    while [[ $var =~ $reg ]]; do
            var=$(declare -p "${BASH_REMATCH[1]}")
    done
    var="${var#declare -}"
    echo "${var:0:1}"
}

ini::get_entry_from_dict() {
  [ "$1" = "dict" ] || { local -n dict; dict="$1"; }
  [ "$2" = "out" ] || { local -n out; out="$2"; }
  local key="$3"

  local data=${dict["$key"]}
 
  local pattern='^declare -(.) ([^=]*)='
  if [[ "${data}" =~ ${pattern} ]]; then
    local type="${BASH_REMATCH[1]}"

    data="${data#declare -"${type}" *=}"
    local -"${type}" res="${data}"
    # adding the elements one-by-one
    # there should be a nicer way to do that ...
    local k; for k in "${!res[@]}"; do
      out["$k"]="${res[$k]}"
    done
  else
    out="$data"
  fi
  return
}

ini::add_entry_to_dict() {
  [ "$1" = "dict" ] || { local -n dict; dict="$1"; }
  local key="$2"
  [ "$3" = "val" ] || { local -n val; val="$3"; }

  local serialized="$(declare -p "${!val}" 2> /dev/null)" 
  local pattern='^declare -(.) ([^=]*)='

  if [[ "${serialized}" =~ ${pattern} ]]; then
    local type="${BASH_REMATCH[1]}"
    local name="${BASH_REMATCH[2]}"
    serialized="${serialized#declare -"${type}" *=}"
    serialized="declare -${type} value=${serialized}"
    dict["$key"]="$serialized"
    #echo >&2 "adding $key=$serialized ($key)"
#    echo >&2 "adding $key ($type $name)"
  else
#    echo >&2 "adding $key=${!val}"
    dict["$key"]="${!val}"
  fi
}

ini::add_array_to_dict() {
  [ "$1" = "dict" ] || { local -n dict; dict="$1"; }
  local key="$2"
  [ "$3" = "val" ] || { local -n val; val="$3"; }

  local var=$(declare -p ${!val} 2>/dev/null)
  local reg='^declare -n [^=]+=\"([^\"]+)\"$'
  while [[ $var =~ $reg ]]; do
    var=$(declare -p "${BASH_REMATCH[1]}")
  done

  local serialized="$(declare -p "${!val}" 2> /dev/null)" 
  local pattern='^declare -([a|A]) ([^=]*)='

  if [[ "${serialized}" =~ ${pattern} ]]; then
    local type="${BASH_REMATCH[1]}"
    local name="${BASH_REMATCH[2]}"
    serialized="${serialized#declare -"${type}" *=}"
    serialized="declare -${type} value=${serialized}"
#    echo >&2 "adding $key:$type $serialized"
    dict["$key"]="$serialized"
  else
#    echo >&2 "adding $key=${!val}"
    dict["$key"]="${!val}"
  fi
}

# works 
ini::json_to_array() {
  [ "$1" = "arr" ] || { declare -n arr; arr="$1"; }
  [ "$2" = "suffix" ] || { declare -n suffix; suffix="$2"; }
  [ "$3" = "lineno" ] || { declare -n lineno; lineno="$3"; }
  local rest="$4"
  local line="$5"
  local state="$6"
  local depth="$7"

  [ -z "$depth" ] && depth=0
  [ -z "$state" ] && state='start'

  [ -n "$line" ] && echo -n "${lineno}(${depth}):" >&2 
#  ini::serialize arr  >&2  
  local nl=$'\n'

  local cmt_pattern="\s*#[^${nl}]*(.*)"

  local dict_root_pattern='^\{(.*)'
  local dict_start_pattern='(\s*)"([^:]+)": \{(.*)'
  local dict_end_pattern='(\s*)\},*(.*)'
  local dict_entry_pattern='(\s*)"([^:]+)": "([^"]+)",*(.*)'

  local arr_root_pattern='^\[(.*)'
  local arr_start_pattern='(\s*)"([^:]+)": \[(.*)'
  local arr_end_pattern='(\s*)\],*(.*)'
  local arr_entry_pattern='(\s*)"([^"]+)",*(.*)'

  #echo >&2 "line=\"$line\""
  if [[ "${line}" =~ ${dict_root_pattern} ]]; then
    # no function currently
    line="${BASH_REMATCH[2]}"

    echo >&2 "dict root symbol detected"

    ini::json_to_array arr suffix lineno "$rest" "$line" "dict" "$depth"
  elif [[ "${line}" =~ ${arr_root_pattern} ]]; then
    # no function currently
    line="${BASH_REMATCH[2]}"

    echo >&2 "array root symbol detected"

    ini::json_to_array arr suffix lineno "$rest" "$line" "array" "$depth"
  elif [[ "${line}" =~ ${cmt_pattern} ]]; then
    # read a comment line - discard line
    line="${BASH_REMATCH[1]}"

    echo >&2 "read a comment line - discard line"

    ini::json_to_array arr suffix lineno "$rest" "$line" "$state" "$depth"
  elif [[ "${line}" =~ ${dict_end_pattern} ]]; then
    local indent="${BASH_REMATCH[1]}"
    line="${BASH_REMATCH[2]}"

    [ ! $state = "dict" ] && echo >&2 "ERROR: ending a dict without starting it" && exit 1

    echo >&2 "read a dict end (indent=${#indent}, rest=$line)"

    suffix="$line$rest"
    return
  elif [[ "${line}" =~ ${dict_start_pattern} ]]; then
    # read a dict start line
    local indent="${BASH_REMATCH[1]}"
    local key="${BASH_REMATCH[2]}"
    line="${BASH_REMATCH[3]}"

    echo >&2 "read a dict start (indent=${#indent}, key=$key, rest=$line)"

    local -n data="$(ini::create_argname)"
    local -A "${!data}"
    ini::json_to_array "${!data}" suffix lineno "$rest" "$line" "dict" "$((depth+1))"
    ini::add_array_to_dict arr "$key" "${!data}"
 
#    local -A data
#    ini::json_to_array data suffix "$rest" "$line" "dict" "$((depth+1))"
#    ini::add_array_to_dict arr "$key" data

    ini::json_to_array arr suffix lineno "$suffix" "" "$state" "$depth"
  elif [[ "${line}" =~ ${dict_entry_pattern} ]]; then
    # read a key value assignment
    local indent="${BASH_REMATCH[1]}"
    local key="${BASH_REMATCH[2]}"
    local val="${BASH_REMATCH[3]}"
    line="${BASH_REMATCH[4]}"

    [ ! $state = "dict" ] && echo >&2 "ERROR: need a dict to add a key value pair" && exit 1

    echo >&2 "read a key value assignment (indent=${#indent}, key=$key, val=$val, rest=$line)"

    [ "${arr[$key]+___x}" ] && echo >&2 "$key duplicate detected"
    arr["$key"]="$val"

    ini::json_to_array arr suffix lineno "$rest" "$line" "$state" "$depth"
  elif [[ "${line}" =~ ${arr_end_pattern} ]]; then
    local indent="${BASH_REMATCH[1]}"
    line="${BASH_REMATCH[2]}"

    [ ! $state = "array" ] && echo >&2 "ERROR: ending an array without start" && exit 1

    echo >&2 "read a array end (indent=${#indent}, rest=$line)"

    suffix="$line$rest"
    return
  elif [[ "${line}" =~ ${arr_start_pattern} ]]; then
    # read an array start line
    local indent="${BASH_REMATCH[1]}"
    local key="${BASH_REMATCH[2]}"
    line="${BASH_REMATCH[3]}"

    echo >&2 "read a array start (indent=${#indent}, key=$key, rest=$line)"

    local -n data="$(ini::create_argname)"
    local -a "${!data}"
    ini::json_to_array "${!data}" suffix lineno "$rest" "$line" "array" "$((depth+1))" 
    ini::add_array_to_dict arr "$key" "${!data}"

#     local -a data
#    ini::json_to_array data suffix "$rest" "$line" "array" "$((depth+1))"
#    ini::add_array_to_dict arr "$key" data

    ini::json_to_array arr suffix lineno "$suffix" "" "$state" "$depth" 
   elif [[ "${line}" =~ ${arr_entry_pattern} ]]; then
    # read an array entry assignment
    local indent="${BASH_REMATCH[1]}"
    local val="${BASH_REMATCH[2]}"
    line="${BASH_REMATCH[3]}"

    [ ! $state = "array" ] && echo >&2 "ERROR: need an array to add a keyless value" && exit 1

    echo >&2 "read an array entry assignment (indent=${#indent}, val=$val, rest=$line)"

    arr+=("$val")
    
    ini::json_to_array arr suffix lineno "$rest" "" "$state" "$depth" 
  else
    # the line read so far is not telling us what to do
    # we try to read one more line from the rest and 
    # start over
    local nl_pattern="^([^${nl}]*)[${nl}]+(.*)$"
    if [[ "${rest}" =~ ${nl_pattern} ]]; then
      line="${line}${BASH_REMATCH[1]}"
      rest="${BASH_REMATCH[2]}"
      ((lineno++))
      ini::json_to_array arr suffix lineno "$rest" "$line" "$state" "$depth" 
    else
      line="$line$rest"
      ((lineno++))
      [ -n "$line" ] && ini::json_to_array arr suffix lineno "" "$line" "$state" "$depth" && return
      [ ! $state = "start" ] && echo >&2 "ERROR: premature end of data, not all arrays closed properly" && exit 1
#      echo >&2 "string processed fully"
    fi
  fi
}

ini::array_to_json() {
  [ "$1" = "arr" ] || { local -n arr; arr="$1"; }

  local arr_type=$(ini::get_type "${!arr}")

  local depth=$2
  [ -z "$depth" ] && depth=0
 
  local res=""
  local _indent="                                    "
  indent=${_indent:0:((depth*4))}

  #[ "$arr_type" = "a" ] && res+="${indent}[\n" || res+="${indent}{\n"
  [ "$arr_type" = "a" ] && res+="[\n" || res+="{\n"
  ((depth++))
  indent=${_indent:0:((depth*4))}

  #local key; for key in "${!arr[@]}"; do
  local keys
  mapfile -d '' keys < <(printf '%s\0' "${!arr[@]}" | sort -z)
  local key; for key in "${keys[@]}"; do
    local val="${arr[$key]}"
    local pkey="${key//\"/\\\\\"}"
    pkey="${pkey//=/\\\\=}"
    local pval="${val//\"/\\\\\"}"
    pval="${pval//=/\\\\=}"
#    echo >&2 -e -n "\n$indent$key ------------ "
#    echo >&2 $(declare -p ${!arr})
#    echo >&2 -e "$indent]\n"
    local pattern='^declare -(.) ([^=]*)='
    if [[ "${val}" =~ ${pattern} ]]; then
      local type="${BASH_REMATCH[1]}"

      res+="${indent}\"$pkey\": " 
#      [ "$type" = "a" ] && res+="${indent}\"$pkey\": [\n" || res+="${indent}\"$pkey\": {\n"

      #declare -n data="data$$$depth$RANDOM"
      val="${val#declare -"${type}" *=}"
      local -n data="$(ini::create_argname)"
      local -"${type}" ${!data}="${val}"
#      echo >&2 -e -n "\n$indent ------------ "
#      echo >&2 $(declare -p ${!data})
      res+="$(ini::array_to_json ${!data} $depth)"
      
#      res="${res::-3}\n"
#      [ "$type" = "a" ] && res+="${indent}]\n" || res+="${indent}}\n"
      unset -n data
      unset "${!data}"
    else
      [ "$arr_type" = "a" ] && res+="$indent\"$pval\",\n" || res+="$indent\"$pkey\": \"$pval\",\n"
    fi
  done
  res="${res::-3}\n"

  ((depth--))
  indent=${_indent:0:((depth*4))}
  [ "$arr_type" = "a" ] && res+="$indent],\n" || res+="$indent},\n"
  [ $depth -eq 0 ] && res="${res::-3}\n"

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

# https://unix.stackexchange.com/questions/413878/json-array-to-bash-variables-using-jq

cat <<EOF > file.ini
# header bla
"pi"="3.14"

[main]
"U\"R\=L"="exam\"ple.com"
"CREATED"="10/22/2017"
"MY_OPTION_"="  10/22/2017"

# help bla
[help]
"x"="17"
"y"="12"

"pi"="3.14"
# EOF
EOF

serialize_array_to_ini_string()
{
  [ "$1" = "arr" ] || { declare -n arr; arr="$1"; }

  local res=""
  local key
  for key in "${!arr[@]}"; do
    val="${arr[$key]}"
    pkey="${key//\"/\\\\\"}"
    pkey="${pkey//=/\\\\=}"
    pval="${val//\"/\\\\\"}"
    pval="${pval//=/\\\\=}"
    res+="\"$pkey\"=\"$pval\"\n"
  done
  echo "$res"
}

read_array_from_ini_file()
{
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

unset myarray
typeset -A myarray

read_array_from_ini_file myarray file.ini
# show the array definition
typeset -p myarray

# make use of the array variables
echo "URL = '${myarray[U\"R=L]}'"
echo "CREATED = '${myarray[CREATED]}'"
echo "pi = '${myarray[pi]}'"

copy="$(serialize_array_to_ini_string myarray)"
echo -e "$copy" > copy.ini

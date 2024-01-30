# https://unix.stackexchange.com/questions/413878/json-array-to-bash-variables-using-jq

cat <<EOF > file.json
{
  "SITE_DATA": {
    "URL": "example.com",
    "AUTHOR": "John Doe",
    "CREATED": "10/22/2017"
  },
  "OTHER_DATA": {
    "URL": "other_example.com",
    "AUTHOR": "other_John Doe",
    "CREATED": "other_10/22/2017"
  }
}
EOF

serialize_array_to_string()
{
  [ "$1" = "arr" ] || { declare -n arr; arr="$1"; }
  local id="$2"

  local res="  \"$id\": {\n"
  local key
  for key in "${!arr[@]}"; do
    res+="    \"$key\": \"${arr[$key]}\",\n"
  done
  res="${res:0:-3}"
  res+="\n  }"
  printf "$res"
}

read_array_from_json_file()
{
  [ "$1" = "arr" ] || { declare -n arr; arr="$1"; }
  local id="$2"
  local json_file="$3"

  local jqr=".$id"; jqr+=' | to_entries | .[] | .key + "=" + .value '

  while IFS="=" read -r key value; do
    arr["$key"]="$value"
  done < <(jq -r "$jqr" "$json_file")
  #done < <(jq -r '.SITE_DATA | to_entries | .[] | .key + "=" + .value ' "$json_file")
}

typeset -A myarray

read_array_from_json_file myarray SITE_DATA file.json 
# show the array definition
typeset -p myarray

copy='{\n'
copy+="$(serialize_array_to_string myarray COPY_SITE_DATA_A)" 
copy+=',\n'

read_array_from_json_file myarray OTHER_DATA file.json 
# show the array definition
typeset -p myarray

copy+="$(serialize_array_to_string myarray COPY_SITE_DATA_B)" 
copy+='\n'
copy+='}'
printf "$copy" > copy.json

typeset -A ax
read_array_from_json_file ax COPY_SITE_DATA_A copy.json 
typeset -p ax
read_array_from_json_file ax COPY_SITE_DATA_B copy.json 
typeset -p ax

# make use of the array variables
echo "URL = '${myarray[URL]}'"
echo "CREATED = '${myarray[CREATED]}'"
echo "AUTHOR = '${myarray[URL]}'"


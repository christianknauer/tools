#!/usr/bin/env bash
# shellcheck shell=bash

(return 0 2>/dev/null) && __sourced=1
[ -n "$__sourced" ] && echo >&2 "abort: this script cannot be sourced" >&2 && return 1

source ini.lib.sh || exit 1

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

unset myarray
typeset -A myarray

ini::read_array_from_file myarray file.ini
# show the array definition
typeset -p myarray

# make use of the array variables
echo "URL = '${myarray[U\"R=L]}'"
echo "CREATED = '${myarray[CREATED]}'"
echo "pi = '${myarray[pi]}'"

copy="$(ini::serialize_array_to_string myarray)"
echo -e "$copy" > copy.ini

declare -A options_cfg
options_cfg[just a key]='i am just a value'
options_cfg[secret]='([description]="secret option only for the ini file" [type]="string" [init]="topsecret" [modes]="([dumb]="ass" [top]="bottom" [deeper]="single" [x]=\"( [y]=\"1\" )\" )" [one more]="meaningless")'
options_cfg[envonly]='([description]="option only for env vars file" [type]="int" [init]="" [modes]="e")'
declare -p options_cfg
echo -e "$(ini::serialize_array_to_string2 options_cfg)"


#!/usr/bin/env bash
# shellcheck shell=bash

(return 0 2>/dev/null) && __sourced=1
[ -n "$__sourced" ] && echo >&2 "abort: this script cannot be sourced" >&2 && return 1

source dicts.lib.sh || exit 1
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

ini::ini_to_dict myarray file.ini
# show the array definition
typeset -p myarray

# make use of the array variables
echo "URL = '${myarray[U\"R=L]}'"
echo "CREATED = '${myarray[CREATED]}'"
echo "pi = '${myarray[pi]}'"

echo -e -n "$(dicts::dict_to_json myarray)" 
#echo -e -n "$(ini::serialize_array_to_string options_cfg)"

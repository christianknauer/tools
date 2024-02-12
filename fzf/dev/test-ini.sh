#!/usr/bin/env bash
# shellcheck shell=bash

(return 0 2>/dev/null) && __sourced=1
[ -n "$__sourced" ] && echo >&2 "abort: this script cannot be sourced" >&2 && return 1

source ini.lib.sh || exit 1

declare -A dall

declare -A dict1; dict1[a1]="a1"; dict1[b1]="b1"
declare -A dict2; dict2[a2]="a2"; dict2[b2]="b2"
declare -A dict3; dict3[a3]="a3"; dict3[b3]="b3"
ini::add_entry_to_dict dict2 'c2' dict3
ini::add_entry_to_dict dict1 'c1' dict2

declare -A fdict
fdict[a]="a"
fdict[b]="b"

declare -A sdict
sdict[x]="x"
sdict[y]="y"

declare -a arr 
arr+=('1st')
arr+=('2nd')

ini::add_entry_to_dict sdict 'xxx' dict1
ini::add_entry_to_dict sdict 'xxx2' dict1
ini::add_entry_to_dict sdict 'arr' arr

ini::add_entry_to_dict fdict '2nd' sdict

ini::add_entry_to_dict fdict 'normal' 'seppl'

ini::add_entry_to_dict dall 'first' fdict

declare -p fdict

declare -A resu

# get 'first' entry from dall and add it to resu
ini::get_entry_from_dict dall resu 'first' 
declare -p resu
echo -e -n "$(ini::array_to_json resu)"

# get 'arr' entry from sdict and add it to resu
ini::get_entry_from_dict sdict resu 'arr' 
declare -p resu
echo -e -n "$(ini::array_to_json resu)" > resu.json
resu_string=$(cat resu.json)

declare -A resu2
suffix=""
ini::json_to_array resu2 suffix "${resu_string}"
echo -e -n "$(ini::array_to_json resu2)" 
#rm resu.json


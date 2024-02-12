#!/usr/bin/env bash
# shellcheck shell=bash

(return 0 2>/dev/null) && __sourced=1
[ -n "$__sourced" ] && echo >&2 "abort: this script cannot be sourced" >&2 && return 1

source ini.lib.sh || exit 1

declare -A result
suffix=''
lineno=0

ini::json_to_array result suffix lineno "$(cat "$1")"

echo -e -n "$(ini::array_to_json result)" 

# EOF

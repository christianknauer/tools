#!/bin/env bash
# shellcheck shell=bash

# helper functions

[ -n "${HELPERS_LIB}" ] && return; HELPERS_LIB=0; # pragma once

# capture stdout, stderr & exit code of a command
#
# helpers::catch out err CMD; ec=$?
# runs CMD and stores the output in out, 
# stderr in err and the exit code in ec.

helpers::catch() {
    {
        IFS=$'\n' read -r -d '' "${1}";
        IFS=$'\n' read -r -d '' "${2}";
        (IFS=$'\n' read -r -d '' _ERRNO_; return ${_ERRNO_});
    } < <((printf '\0%s\0%d\0' "$(((({ shift 2; "${@}"; echo "${?}" 1>&3-; } | tr -d '\0' 1>&4-) 4>&2- 2>&1- | tr -d '\0' 1>&4-) 3>&1- | exit "$(cat)") 4>&1-)" "${?}" 1>&2) 2>&1)
}

# recursion with namerefs is tricky
# we need to make sure that the local name
# does not collide with a name higher up the
# call chain.

helpers::create_argname() {
   local avoid="$1"
   local base="$2"; [ -z "$base" ] && base="a${RANDOM}"
   base="${base}_${#FUNCNAME[@]}_$$_"
   local argname="${base}${RANDOM}"
   while [ "$avoid" = "$argname" ]; do
     argname="${base}${RANDOM}"
   done
   echo "$argname"
}

# EOF

#!/usr/bin/env bash

# file: sa-decrypt.sh

# decrypt files with ssh agent

# initialize 

script_path_in_package=$(readlink -f -- "$0")
script_directory=${script_path_in_package%/*}
source "${script_directory}/sa-crypt.inc.sh"

# handle command options
USAGE="[-i INFILE -o OUTFILE -k PUBKEYFILE -d LOGGING_DEBUG_LEVEL ]"
Options.ParseOptions "${USAGE}" ${@}

DebugLoggingConfig 9

# check binaries
sacrypt_CheckBinaries

# create temporary directory
sacrypt_CreateTempDir

# main

[ "${INFILE}" == "" ] && INFILE="/dev/stdin"
if [[ "${INFILE}" == *.sae ]]; then
	OUTNAME=${INFILE%".sae"}
	[ ! -f "${OUTNAME}" ] && [ "${OUTFILE}" == "" ] && OUTFILE="${OUTNAME}"
fi
[ ! "${INFILE}" == "/dev/stdin" ] && [ "${OUTFILE}" == "" ] && OUTFILE="$INFILE.dec"

DebugMsg 1 "reading from \"$INFILE\", writing to \"$OUTFILE\""

[ ! -e "$INFILE" ] && ErrorMsg "input file \"$INFILE\" cannot be opened" && exit 1

DECFILE=$(mktemp -p $TEMPD)
[ ! -e "$DECFILE" ] && ErrorMsg "failed to create temporary dec file" && exit 1

DebugMsg 1 "using \"$DECFILE\" as temp dec file"

ssh-add -L > /dev/null ; ec=$?  
case $ec in
    0) DebugMsg 3 "ssh-agent provides key(s)";;
    1) ErrorMsg "ssh-agent has no identities ($ec)"; exit 1;;
    2) ErrorMsg "ssh-agent is not running ($ec)"; exit 2;;
    *) ErrorMsg "ssh-agent gives unknown exit code ($ec)"; exit 2;;
esac

cat "${INFILE}" | ${DECRYPT} > "${DECFILE}" ; ec=$?  
case $ec in
    0) DebugMsg 1 "decryption successful";;
    1) ErrorMsg "decryption failed (key not in agent? not an sae file?)"; exit 1;;
    *) ErrorMsg "decrypt gives unknown exit code ($ec)"; exit 2;;
esac

if [ "${OUTFILE}" == "" ]; then
    cat "${DECFILE}" 
    DebugMsg 1 "output sent to STDOUT"
else
    mv "${DECFILE}" "${OUTFILE}"
    DebugMsg 1 "output written to \"${OUTFILE}\""
fi

exit 0

# EOF

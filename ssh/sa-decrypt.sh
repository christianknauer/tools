#!/usr/bin/env bash

# file: sa-decrypt.sh

# decrypt files with ssh agent

# initialize 

script_path_in_package=$(readlink -f -- "$0")
script_directory=${script_path_in_package%/*}
source "${script_directory}/sa-crypt.inc.sh"

# handle command options
USAGE="[-i INFILE -o OUTFILE -k PUBKEYFILE -c CHKFILE -d LOGGING_DEBUG_LEVEL ]"
Options.ParseOptions "${USAGE}" ${@}

DebugLoggingConfig 9

# check binaries
sacrypt_CheckBinaries

# create temporary directory
sacrypt_CreateTempDir

# main

[ "${INFILE}" == "" ] && INFILE="/dev/stdin"
if [[ "${INFILE}" == *.${SA_CRYPT_ENC_EXT} ]]; then
	OUTNAME=${INFILE%".${SA_CRYPT_ENC_EXT}"}
	[ ! -f "${OUTNAME}" ] && [ "${OUTFILE}" == "" ] && OUTFILE="${OUTNAME}"
	[ "${CHKFILE}" == "" ] && CHKFILE="${OUTNAME}.${SA_CRYPT_CHK_EXT}"
fi
[ ! "${INFILE}" == "/dev/stdin" ] && [ "${OUTFILE}" == "" ] && OUTFILE="$INFILE.${SA_CRYPT_DEC_EXT}"
[ "${CHKFILE}" == "" ] && CHKFILE="message.${SA_CRYPT_CHK_EXT}"
[ ! -f "${CHKFILE}" ] && CHKFILE=""

DebugMsg 3 "reading encrypted input data from \"$INFILE\""
DebugMsg 3 "writing raw data to \"$OUTFILE\""
DebugMsg 3 "reading checksum from \"$CHKFILE\""

[ ! -e "$INFILE" ] && ErrorMsg "input file \"$INFILE\" cannot be opened" && exit 1

DECFILE=$(mktemp -p $TEMPD)
TMDFILE=$(mktemp -p $TEMPD)
[ ! -e "$DECFILE" ] && ErrorMsg "failed to create temp dec file" && exit 1
[ ! -e "$TMDFILE" ] && ErrorMsg "failed to create temp chk file" && exit 1
DebugMsg 3 "using \"$DECFILE\" as temp dec file"
DebugMsg 3 "using \"$TMDFILE\" as temp chk file"

ssh-add -L > /dev/null 2> /dev/null; ec=$?  
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
    cp "${DECFILE}" "${OUTFILE}"
    DebugMsg 1 "output written to \"${OUTFILE}\""
fi

if [ "${CHKFILE}" == "" ]; then
    DebugMsg 1 "no checksum data available, verification skipped"
else
    sacrypt_ComputeHashOfFile "${DECFILE}" > "${TMDFILE}"
    cmp -s "${CHKFILE}" "${TMDFILE}" ; ec=$?  
    case $ec in
        0) DebugMsg 1 "checksum verification passed";;
        *) ErrorMsg "checksum verification failed" && exit 1;;
    esac
fi

exit 0

# EOF

#!/usr/bin/env bash

# file: sa-decrypt.sh

# decrypt files with ssh agent

# initialize 

script_path_in_package=$(readlink -f -- "$0")
script_directory=${script_path_in_package%/*}
source "${script_directory}/sa-crypt.inc.sh"

# handle command options

USAGE="[-i INFILE -o OUTFILE -k PUBKEYFILE -c CHKFILE -p PASSWORD -d LOGGING_DEBUG_LEVEL ]"
Options.ParseOptions "${USAGE}" ${@}

DebugLoggingConfig 9

# check binaries
sacrypt_CheckBinaries

# create temporary directory
CreateTempDir; ec=$?; TEMPD=$retval
[ ! $ec -eq 0 ] &&  ErrorMsg "$retval" && exit $ec

DebugMsg 1 "created temporary directory \"${TEMPD}\""

# init
sacrypt_Init 

# main

[ "${INFILE}" == "" ] && INFILE="/dev/stdin"
if [[ "${INFILE}" == *.${SA_CRYPT_ENC_EXT} ]]; then
	OUTNAME=${INFILE%".${SA_CRYPT_ENC_EXT}"}
	[ ! -f "${OUTNAME}" ] && [ "${OUTFILE}" == "" ] && OUTFILE="${OUTNAME}"
#	[ "${CHKFILE}" == "" ] && CHKFILE="${OUTNAME}.${SA_CRYPT_CHK_EXT}"
#        [ "${PUBKEYFILE}" == "" ] && PUBKEYFILE="${OUTNAME}.${SA_CRYPT_KEY_EXT}"
fi
[ ! "${INFILE}" == "/dev/stdin" ] && [ "${OUTFILE}" == "" ] && OUTFILE="$INFILE.${SA_CRYPT_DEC_EXT}"
[ "${CHKFILE}" == "" ] && CHKFILE="message.${SA_CRYPT_CHK_EXT}"
[ ! -f "${CHKFILE}" ] && CHKFILE=""

DebugMsg 3 "reading encrypted input data from \"$INFILE\""
DebugMsg 3 "writing raw data to \"$OUTFILE\""
DebugMsg 3 "reading checksum from \"$CHKFILE\""

DECFILE=$(mktemp -p $TEMPD)
[ ! -e "$DECFILE" ] && ErrorMsg "failed to create temp dec file" && exit 1
DebugMsg 3 "using \"$DECFILE\" as temp dec file"

# determine password
sacrypt_DeterminePassword "${PASSWORD}" "${TEMPD}"; ec=$?; PASSWORD=$retval
[ ! $ec -eq 0 ] &&  ErrorMsg "$retval" && exit $ec
 
# determine encryption key specification
sacrypt_DetermineKeyHash "${PUBKEYFILE}"; ec=$?; KEYSPEC=$retval
[ ! $ec -eq 0 ] &&  ErrorMsg "$retval" && exit $ec
DebugMsg 1 "key spec is ${KEYSPEC}"

if [ ! "${KEYSPEC}" == "" ]; then
    # find the encryption key in the agent 
    sacrypt_FindKeyInAgent ${KEYSPEC} "${TEMPD}"; ec=$?  
    [ ! $ec -eq 0 ] && ErrorMsg "$retval" && exit $ec
    KEYINDEX=$retval
    KEYHASH=$retval1
    DebugMsg 1 "key ${KEYHASH} found in agent (#${KEYINDEX})"
else
    DebugMsg 1 "no key specified, agent not asked"
fi

# decrypt the file
sacrypt_DecryptFile "${INFILE}" "${DECFILE}" "${KEYSPEC}" "${TEMPD}" "${PASSWORD}"; ec=$?
[ ! $ec -eq 0 ] && ErrorMsg "$retval" && exit $ec
DebugMsg 1 "decryption ok"

# verify decryption
if [ "${CHKFILE}" == "" ]; then
    DebugMsg 1 "no checksum data available, verification skipped"
else
    DebugMsg 1 "reading checksum from \"${CHKFILE}\""
    sacrypt_VerifyFileChecksum "${DECFILE}" "${CHKFILE}" "${TEMPD}"; ec=$?
    [ ! $ec -eq 0 ] && ErrorMsg "$retval" && exit $ec
    DebugMsg 1 "checksum verification passed"
fi

# create output
if [ "${OUTFILE}" == "" ]; then
    cat "${DECFILE}" 
    DebugMsg 1 "output sent to STDOUT"
else
    cp "${DECFILE}" "${OUTFILE}"
    DebugMsg 1 "output written to \"${OUTFILE}\""
fi

exit 0

# EOF

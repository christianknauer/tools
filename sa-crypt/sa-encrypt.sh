#!/usr/bin/env bash

# file: sa-encrypt.sh

# encrypt files with ssh agent

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
[ ! "${INFILE}" == "/dev/stdin" ] && [ "${OUTFILE}" == "" ] && OUTFILE="$INFILE.${SA_CRYPT_ENC_EXT}"
[ ! "${INFILE}" == "/dev/stdin" ] && [ "${CHKFILE}" == "" ] && CHKFILE="$INFILE.${SA_CRYPT_CHK_EXT}"
[ ! "${INFILE}" == "/dev/stdin" ] && [ "${PKHFILE}" == "" ] && PKHFILE="$INFILE.${SA_CRYPT_KEY_EXT}"
[ "${CHKFILE}" == "" ] && CHKFILE="message.${SA_CRYPT_CHK_EXT}"
[ "${PKHFILE}" == "" ] && PKHFILE="message.${SA_CRYPT_KEY_EXT}"

DebugMsg 3 "reading raw data from \"$INFILE\""
DebugMsg 3 "writing encrypted data to \"$OUTFILE\""
DebugMsg 3 "writing checksum to \"$CHKFILE\""
DebugMsg 3 "writing public key hash to \"$PKHFILE\""

# create temp files

RAWFILE=$(mktemp -p $TEMPD)
[ ! -e "$RAWFILE" ] && ErrorMsg "failed to create temp raw file" && exit 1
DebugMsg 3 "using \"$RAWFILE\" as temp raw file"

ENCFILE=$(mktemp -p $TEMPD)
[ ! -e "$ENCFILE" ] && ErrorMsg "failed to create temp enc file" && exit 1
DebugMsg 3 "using \"$ENCFILE\" as temp enc file"

# determine encryption key specification

if sacrypt_DetermineKeyHash "${PUBKEYFILE}"; then
    KEYSPEC=$retval
    DebugMsg 1 "key specification is ${KEYSPEC}"
else
    ErrorMsg "incorrect key specification"; exit 1
fi

# read input file 
[ ! -e "$INFILE" ] && ErrorMsg "input file \"$INFILE\" cannot be opened" && exit 1
cat "${INFILE}" > "${RAWFILE}"

# encrypt the file
sacrypt_EncryptFile "${RAWFILE}" "${ENCFILE}" "${KEYSPEC}" "${TEMPD}"; ec=$?
KEYHASH=$retval
if [ $ec -eq 0 ] 
then 
  DebugMsg 1 "encryption ok"
else 
  ErrorMsg "encryption failed"; exit $ec
fi

# create output
if [ "${OUTFILE}" == "" ]; then
    cat "${ENCFILE}" 
    DebugMsg 1 "output sent to STDOUT"
else
    cp "${ENCFILE}" "${OUTFILE}"
    DebugMsg 1 "output written to \"${OUTFILE}\""
fi

# create checksum file
sacrypt_ComputeHashOfFile "${RAWFILE}" > "${CHKFILE}"
DebugMsg 1 "checksum written to \"${CHKFILE}\""

# create key file
echo -n "${KEYHASH}" > "${PKHFILE}"
DebugMsg 1 "key hash written to \"${PKHFILE}\""

exit 0

# EOF

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

VERFILE=$(mktemp -p $TEMPD)
[ ! -e "$VERFILE" ] && ErrorMsg "failed to create temp ver file" && exit 1
DebugMsg 3 "using \"$VERFILE\" as temp ver file"

# determine encryption key specification

if sacrypt_DetermineKeyHash "${PUBKEYFILE}"; then
    DESTKEYHASH=$retval
    DebugMsg 1 "key specification is ${DESTKEYHASH}"
else
    ErrorMsg "incorrect key specification"; exit 1
fi

# find the encryption key in the agent 

if sacrypt_FindKeyInAgent ${DESTKEYHASH}; then
    KEYINDEX=$retval
    KEYHASH=$retval1
    DebugMsg 1 "key ${KEYHASH} found in agent (#${KEYINDEX})"
else
    ErrorMsg "key ${DESTKEYHASH} not found in agent (#$retval)"; exit 1
fi

# read input file 
[ ! -e "$INFILE" ] && ErrorMsg "input file \"$INFILE\" cannot be opened" && exit 1
cat "${INFILE}" > "${RAWFILE}"

# encrypt with all keys in agent
cat "${RAWFILE}" | ${ENCRYPT} > "${ENCFILE}"

# split encrypted file line by line
Counter=0
while IFS='' read -r LinefromFile || [[ -n "${LinefromFile}" ]]; do
    ((Counter++))
    echo "${LinefromFile}" > "${ENCFILE}.${Counter}"
done < "${ENCFILE}"

# extract the correct file
EncOutputFile="${TEMPD}/decoded.$$.${KEYHASH}"
mv "${ENCFILE}.${Counter}" "${EncOutputFile}"
[ ! -e "$EncOutputFile" ] && ErrorMsg "failed to create output file \"${EncOutputFile}\"" && exit 1
chmod go-rwx "${EncOutputFile}"
KeyFile="${TEMPD}/key.$$.${KEYHASH}"
echo -n "${KEYHASH}" > "${KeyFile}"
	
# verify encryption
DebugMsg 3 "verifying encryption"
cat "${EncOutputFile}" | ${DECRYPT} > "${VERFILE}"
cmp -s "${RAWFILE}" "${VERFILE}" ; ec=$?  
case $ec in
   0) DebugMsg 1 "verification passed";;
   *) ErrorMsg "verification failed" && exit 1;;
esac

# create output
if [ "${OUTFILE}" == "" ]; then
    cat "$EncOutputFile" 
    DebugMsg 1 "output sent to STDOUT"
else
    mv "${EncOutputFile}" "${OUTFILE}"
    DebugMsg 1 "output written to \"${OUTFILE}\""
fi

# create checksum
sacrypt_ComputeHashOfFile "${RAWFILE}" > "${CHKFILE}"
DebugMsg 1 "checksum written to \"${CHKFILE}\""

# create key file
cp "${KeyFile}" "${PKHFILE}"
DebugMsg 1 "key hash written to \"${PKHFILE}\""

exit 0

# EOF

#!/usr/bin/env bash

# file: sa-encrypt.sh

# encrypt files with ssh agent

# initialize 

script_path_in_package=$(readlink -f -- "$0")
script_directory=${script_path_in_package%/*}
source "${script_directory}/sa-crypt.inc.sh"

# handle command options
USAGE="[-i INFILE -o OUTFILE -k PUBKEYFILE -c CHKFILE -p PASSWORD -I INITFILE -d LOGGING_DEBUG_LEVEL ]"
Options.ParseOptions "${USAGE}" ${@}

DebugLoggingConfig 9

# check binaries
sacrypt_CheckBinaries

# create temporary directory
CreateTempDir; ec=$?; TEMPD=$retval
[ ! $ec -eq 0 ] &&  ErrorMsg "$retval" && exit $ec

DebugMsg 1 "created temporary directory \"${TEMPD}\""

# init
sacrypt_Init $INITFILE $TEMP

SA_CRYPT_AES_KEY_HASH=$(sacrypt_ComputeHashOfString $SA_CRYPT_AES_KEY)
DebugMsg 1 "Default AES key hash is ${SA_CRYPT_AES_KEY_HASH}"


# main

[ "${INFILE}" == "" ] && INFILE="/dev/stdin"
[ ! "${INFILE}" == "/dev/stdin" ] && [ "${OUTFILE}" == "" ] && OUTFILE="$INFILE.${SA_CRYPT_ENC_EXT}"
[ ! "${INFILE}" == "/dev/stdin" ] && [ "${CHKFILE}" == "" ] && CHKFILE="$INFILE.${SA_CRYPT_CHK_EXT}"
[ ! "${INFILE}" == "/dev/stdin" ] && [ "${PKHFILE}" == "" ] && PKHFILE="$INFILE.${SA_CRYPT_KEY_EXT}"
[ ! "${INFILE}" == "/dev/stdin" ] && [ "${AESHFILE}" == "" ] && AESHFILE="$INFILE.${SA_CRYPT_AES_EXT}"
[ ! "${INFILE}" == "/dev/stdin" ] && [ "${PKGFILE}" == "" ] && PKGFILE="$INFILE.${SA_CRYPT_PKG_EXT}"
[ "${CHKFILE}" == "" ] && CHKFILE="message.${SA_CRYPT_CHK_EXT}"
[ "${PKHFILE}" == "" ] && PKHFILE="message.${SA_CRYPT_KEY_EXT}"
[ "${PKGFILE}" == "" ] && PKGFILE="message.${SA_CRYPT_PKG_EXT}"

DebugMsg 3 "reading raw data from \"$INFILE\""
DebugMsg 3 "writing encrypted data to \"$OUTFILE\""
DebugMsg 3 "writing checksum to \"$CHKFILE\""
DebugMsg 3 "writing public key hash to \"$PKHFILE\""
DebugMsg 3 "writing aes hash to \"$AESHFILE\""
DebugMsg 3 "writing package to \"$PKGFILE\""

# create temp files

RAWFILE=$(mktemp -p $TEMPD)
[ ! -e "$RAWFILE" ] && ErrorMsg "failed to create temp raw file" && exit 1
DebugMsg 3 "using \"$RAWFILE\" as temp raw file"

ENCFILE=$(mktemp -p $TEMPD)
[ ! -e "$ENCFILE" ] && ErrorMsg "failed to create temp enc file" && exit 1
DebugMsg 3 "using \"$ENCFILE\" as temp enc file"

# determine password
sacrypt_DeterminePassword "${PASSWORD}" "${TEMPD}"; ec=$?; PASSWORD=$retval
[ ! $ec -eq 0 ] &&  ErrorMsg "$retval" && exit $ec
 
# determine encryption key specification
sacrypt_DetermineKeyHash "${PUBKEYFILE}"; ec=$?; KEYSPEC=$retval
[ ! $ec -eq 0 ] &&  ErrorMsg "$retval" && exit $ec

# read input file 
[ ! -e "$INFILE" ] && ErrorMsg "input file \"$INFILE\" cannot be opened" && exit 1
cat "${INFILE}" > "${RAWFILE}"

# encrypt the file
sacrypt_EncryptFile "${RAWFILE}" "${ENCFILE}" "${KEYSPEC}" "${TEMPD}" "${PASSWORD}"; ec=$?; KEYHASH=$retval; AESHASH=$retval1
[ ! $ec -eq 0 ] && ErrorMsg "$retval" && exit $ec

DebugMsg 1 "encryption ok"

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

# create key file
echo -n "${AESHASH}" > "${AESHFILE}"
DebugMsg 1 "aes hash written to \"${AESHFILE}\""

# create package file
SA_CRYPT_PKG_SIGNATURE="f0hOgBYHER8fyninUB81ebdg9CNkjXFKVqBxVFq3JuqhLSRrcT8tqt3aBYlD4GQL"
echo $SA_CRYPT_PKG_SIGNATURE > package-signature.sam
tar cvfz "${PKGFILE}" package-signature.sam "${OUTFILE}" "${CHKFILE}" "${PKHFILE}" "${AESHFILE}" >/dev/null
DebugMsg 1 "sae package written to \"${PKGFILE}\""

exit 0

# EOF

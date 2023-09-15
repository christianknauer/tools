#!/usr/bin/env bash

# file: sage-decrypt.sh

# decrypt files with ssh agent + age

# initialize 

script_path_in_package=$(readlink -f -- "$0")
script_directory=${script_path_in_package%/*}
source "${script_directory}/sage-crypt.inc.sh"

# handle command options
USAGE="[-i INFILE -o OUTFILE -p PASSWORD -d LOGGING_DEBUG_LEVEL -D LIB_LOGGING_DEBUG_LEVEL ]"
Options.ParseOptions "${USAGE}" ${@}

DebugLoggingConfig 9
LIB_LOGGING_DEBUG_LEVEL="${LIB_LOGGING_DEBUG_LEVEL:=0}"

# check binaries
sagecrypt_CheckBinaries

# create temporary directory
sagecrypt_CreateTempDir

# main

[ "${INFILE}" == "" ] && ErrorMsg "no input specified" &&  exit 1

EMBEDPWD="yes"
# if a password is given we will not include it in the output
[ ! "${PASSWORD}" == "" ] && EMBEDPWD="no"
# if no password is given we will create a random one and embed in the output
# if the password is embedded we need a second key

# if no output is given we will use the default
[ "${OUTFILE}" == "" ] && OUTFILE="$INFILE.out"

DebugMsg 3 "reading data from \"$INFILE\""
DebugMsg 3 "writing encrypted data to \"$OUTFILE\""

# create temp files

sagecrypt_CreateTempDir; SAGE_CRYPT_TEMPD="$retval"

cp "${INFILE}" "${SAGE_CRYPT_TEMPD}/package.tgz"
pushd "${SAGE_CRYPT_TEMPD}" >/dev/null
tar xvfz package.tgz > /dev/null
popd >/dev/null

SAGE_CRYPT_ASSEMLYD="${SAGE_CRYPT_TEMPD}/package"

[ ! -e "$SAGE_CRYPT_ASSEMLYD" ] && ErrorMsg "failed to create temp assembly directory" && exit 1
DebugMsg 3 "using \"${SAGE_CRYPT_ASSEMLYD}\" as assembly directory"

SAGE_CRYPT_AGE_SKEY_CLEAR="${SAGE_CRYPT_ASSEMLYD}/key.sec"
SAGE_CRYPT_AGE_SKEY="${SAGE_CRYPT_ASSEMLYD}/key.sec.aes"
SAGE_CRYPT_AGE_SKEY_PW="${SAGE_CRYPT_ASSEMLYD}/key.pw"
SAGE_CRYPT_AGE_PAYLOAD="${SAGE_CRYPT_ASSEMLYD}/payload"

DebugMsg 1 "key is $(cat ${SAGE_CRYPT_AGE_SKEY}.sak)"
sa-decrypt.sh -i "${SAGE_CRYPT_AGE_SKEY}.sae" -d $LIB_LOGGING_DEBUG_LEVEL

if [ -f "${SAGE_CRYPT_AGE_SKEY_PW}.sae" ]; then

    DebugMsg 1 "secret key pw embedded in payload"
    DebugMsg 1 "pw key is $(cat ${SAGE_CRYPT_AGE_SKEY_PW}.sak)"
    sa-decrypt.sh -i "${SAGE_CRYPT_AGE_SKEY_PW}.sae" -d $LIB_LOGGING_DEBUG_LEVEL

    PASSWORD=$(cat "${SAGE_CRYPT_AGE_SKEY_PW}")
fi

cat "${SAGE_CRYPT_AGE_SKEY}" | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 10000 -salt -pass pass:${PASSWORD} > "${SAGE_CRYPT_AGE_SKEY_CLEAR}" 

age -d -i "${SAGE_CRYPT_AGE_SKEY_CLEAR}" "${SAGE_CRYPT_AGE_PAYLOAD}" > "${OUTFILE}"

exit 0

sa-decrypt.sh -i key.sec.aes.sae
sa-decrypt.sh -i key.pw.sae
cat key.sec.aes | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 10000 -salt -pass pass:$(cat key.pw) > key.sec
age -d -i key.sec payload

# EOF

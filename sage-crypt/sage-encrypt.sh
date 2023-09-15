#!/usr/bin/env bash

# file: sage-encrypt.sh

# encrypt files with ssh agent + age

# initialize 

script_path_in_package=$(readlink -f -- "$0")
script_directory=${script_path_in_package%/*}
source "${script_directory}/sage-crypt.inc.sh"

# handle command options
USAGE="[-i INFILE -o OUTFILE -k KEYSPEC -P PWKEYSPEC -p PASSWORD -d LOGGING_DEBUG_LEVEL -D LIB_LOGGING_DEBUG_LEVEL ]"
Options.ParseOptions "${USAGE}" ${@}

DebugLoggingConfig 9
LIB_LOGGING_DEBUG_LEVEL="${LIB_LOGGING_DEBUG_LEVEL:=0}"

# check binaries
sagecrypt_CheckBinaries

# create temporary directory
sagecrypt_CreateTempDir

# main

[ "${INFILE}" == "" ] && ErrorMsg "no input specified" &&  exit 1
[ "${KEYSPEC}" == "" ] && ErrorMsg "no key specified" &&  exit 1

EMBEDPWD="yes"
# if a password is given we will not include it in the output
[ ! "${PASSWORD}" == "" ] && EMBEDPWD="no"
# if no password is given we will create a random one and embed in the output
[ "${PASSWORD}" == "" ] && PASSWORD=$(cat /dev/urandom | tr -dc '[:alnum:]' | head -c 64)
# if the password is embedded we need a second key
[ "${EMBEDPWD}" == "yes" ] && [ "${PWKEYSPEC}" == "" ] && ErrorMsg "no pw key specified" &&  exit 1

# if no output is given we will use the default
[ "${OUTFILE}" == "" ] && OUTFILE="$INFILE.${SAGE_CRYPT_ENC_EXT}"

DebugMsg 3 "reading data from \"$INFILE\""
DebugMsg 3 "writing encrypted data to \"$OUTFILE\""

# create temp files

sagecrypt_CreateTempDir; SAGE_CRYPT_TEMPD="$retval"

mkdir "${SAGE_CRYPT_TEMPD}/package"
SAGE_CRYPT_ASSEMLYD="${SAGE_CRYPT_TEMPD}/package"
[ ! -e "$SAGE_CRYPT_ASSEMLYD" ] && ErrorMsg "failed to create temp assembly directory" && exit 1
DebugMsg 3 "using \"${SAGE_CRYPT_ASSEMLYD}\" as assembly directory"

SAGE_CRYPT_AGE_PKEY="${SAGE_CRYPT_ASSEMLYD}/key.pub"
SAGE_CRYPT_AGE_SKEY_CLEAR="${SAGE_CRYPT_ASSEMLYD}/key.sec"
SAGE_CRYPT_AGE_SKEY="${SAGE_CRYPT_ASSEMLYD}/key.sec.aes"
SAGE_CRYPT_AGE_SKEY_PW="${SAGE_CRYPT_ASSEMLYD}/key.pw"
SAGE_CRYPT_AGE_PAYLOAD="${SAGE_CRYPT_ASSEMLYD}/payload"

age-keygen -o "${SAGE_CRYPT_AGE_SKEY_CLEAR}" 2> "${SAGE_CRYPT_AGE_PKEY}"

cat "${SAGE_CRYPT_AGE_SKEY_CLEAR}" | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 10000 -salt -pass pass:${PASSWORD} > "${SAGE_CRYPT_AGE_SKEY}" 
rm "${SAGE_CRYPT_AGE_SKEY_CLEAR}"

DebugCat 5 "age secret key" "${SAGE_CRYPT_AGE_SKEY}"

sa-encrypt.sh -i "${SAGE_CRYPT_AGE_SKEY}" -k ${KEYSPEC} -d $LIB_LOGGING_DEBUG_LEVEL
DebugMsg 1 "key is $(cat ${SAGE_CRYPT_AGE_SKEY}.sak)"
rm "${SAGE_CRYPT_AGE_SKEY}"

if [ "${EMBEDPWD}" == "yes" ]; then
    DebugMsg 1 "embedding secret key pw"
    echo -n "${PASSWORD}" > "${SAGE_CRYPT_AGE_SKEY_PW}" 
    DebugCat 5 "age secret key pw" "${SAGE_CRYPT_AGE_SKEY_PW}"
    sa-encrypt.sh -i "${SAGE_CRYPT_AGE_SKEY_PW}" -k ${PWKEYSPEC} -d $LIB_LOGGING_DEBUG_LEVEL
    rm "${SAGE_CRYPT_AGE_SKEY_PW}"
    DebugMsg 1 "pw key is $(cat ${SAGE_CRYPT_AGE_SKEY_PW}.sak)"
fi

SAGE_CRYPT_PK=$(cat "${SAGE_CRYPT_AGE_PKEY}" | cut -f 3 -d " ")
rm "${SAGE_CRYPT_AGE_PKEY}"
DebugMsg 1 "age public key ${SAGE_CRYPT_PK}"

age -r "${SAGE_CRYPT_PK}" -o "${SAGE_CRYPT_AGE_PAYLOAD}" "${INFILE}"

pushd "${SAGE_CRYPT_TEMPD}" >/dev/null
tar cvfz package.tgz package/* > /dev/null
popd >/dev/null

mv "${SAGE_CRYPT_TEMPD}/package.tgz" "${OUTFILE}"

exit 0

# EOF

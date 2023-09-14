#!/usr/bin/env bash

# file: sa-encrypt.sh

# encrypt files with ssh agent

# initialize 

script_path_in_package=$(readlink -f -- "$0")
script_directory=${script_path_in_package%/*}
source "${script_directory}/sa-crypt.inc.sh"

# handle command options
USAGE="[-i INFILE -o OUTFILE -k PUBKEYFILE -m MD5FILE -d LOGGING_DEBUG_LEVEL ]"
Options.ParseOptions "${USAGE}" ${@}

DebugLoggingConfig 9

# check binaries
sacrypt_CheckBinaries

# create temporary directory
sacrypt_CreateTempDir

# main

[ "${INFILE}" == "" ] && INFILE="/dev/stdin"
[ ! "${INFILE}" == "/dev/stdin" ] && [ "${OUTFILE}" == "" ] && OUTFILE="$INFILE.sae"
[ ! "${INFILE}" == "/dev/stdin" ] && [ "${MD5FILE}" == "" ] && MD5FILE="$INFILE.sam"
[ "${MD5FILE}" == "" ] && MD5FILE="message.sam"

DebugMsg 3 "reading raw data from \"$INFILE\""
DebugMsg 3 "writing encrypted data to \"$OUTFILE\""
DebugMsg 3 "writing checksum to \"$MD5FILE\""

DESTKEY="unspecified"
if [ ! "${PUBKEYFILE}" == "" ]; then
	[ ! -e "$PUBKEYFILE" ] && ErrorMsg "public key file \"$PUBKEYFILE\" cannot be opened" && exit 1
	DebugMsg 1 "reading public key from \"$PUBKEYFILE\""
	# read first line of file
	read KeyType RestOfLine < ${PUBKEYFILE} 
        PublicKey=${RestOfLine%% *}
        KeyIDShort=${PublicKey: -8:8}
        if [[ $KeyType = ssh-rsa ]]; then
	    DebugMsg 3 "using public key $KeyIDShort"
	    DESTKEY=$PublicKey
        else 
	    ErrorMsg "public key ($KeyIDShort) from \"$PUBKEYFILE\" is not an RSA key" && exit 1
        fi
fi

[ ! -e "$INFILE" ] && ErrorMsg "input file \"$INFILE\" cannot be opened" && exit 1

RAWFILE=$(mktemp -p $TEMPD)
KEYFILE=$(mktemp -p $TEMPD)
ENCFILE=$(mktemp -p $TEMPD)
VERFILE=$(mktemp -p $TEMPD)
[ ! -e "$RAWFILE" ] && ErrorMsg "failed to create temp raw file" && exit 1
[ ! -e "$KEYFILE" ] && ErrorMsg "failed to create temp key file" && exit 1
[ ! -e "$ENCFILE" ] && ErrorMsg "failed to create temp enc file" && exit 1
[ ! -e "$VERFILE" ] && ErrorMsg "failed to create temp ver file" && exit 1
DebugMsg 3 "using \"$RAWFILE\" as temp raw file"
DebugMsg 3 "using \"$KEYFILE\" as temp key file"
DebugMsg 3 "using \"$ENCFILE\" as temp enc file"
DebugMsg 3 "using \"$VERFILE\" as temp ver file"
 
ssh-add -L > ${KEYFILE} ; ec=$?  # grab the exit code into a variable so that it can
                                 # be reused later, without the fear of being overwritten

NROFKEYS=$(cat ${KEYFILE} | wc -l)

case $ec in
    0) DebugMsg 3 "agent provides ${NROFKEYS} key(s)";;
    1) ErrorMsg "ssh-agent has no identities ($ec)"; exit 1;;
    2) ErrorMsg "ssh-agent is not running ($ec)"; exit 2;;
    *) ErrorMsg "ssh-agent gives unknown exit code ($ec)"; exit 2;;
esac

cat "${INFILE}" > "${RAWFILE}"
cat "${RAWFILE}" | ${ENCRYPT} > "${ENCFILE}"

Counter=0

# split encrypted file line by line
while IFS='' read -r LinefromFile || [[ -n "${LinefromFile}" ]]; do
    ((Counter++))
    echo "${LinefromFile}" > "${ENCFILE}.${Counter}"
done < "${ENCFILE}"

EncOutputFile=""
Counter=0
RSACounter=0

while IFS='' read -r LinefromFile || [[ -n "${LinefromFile}" ]]; do

    ((Counter++))

    KeyType=${LinefromFile%% *}
    RestOfLine=${LinefromFile#* }
    PublicKey=${RestOfLine%% *}
    KeyIDShort=${PublicKey: -8:8}

    DebugMsg 3 "Found $KeyType key ($KeyIDShort)"
    if [[ $KeyType = ssh-rsa ]]; then
            if [[ ${DESTKEY} == "unspecified" || ${PublicKey} = ${DESTKEY} ]]; then
                ((RSACounter++))
		EncOutputFile="${TEMPD}/decoded.$$.${KeyIDShort}"
		DebugMsg 1 "secret key found in agent"
		DebugMsg 3 "key #$Counter ($KeyIDShort) is accepted, result written to \"$EncOutputFile\")" #: ${LinefromFile}"
	        mv "${ENCFILE}.${Counter}" "$EncOutputFile"
	        [ ! -e "$EncOutputFile" ] && ErrorMsg "failed to create output file \"$EncOutputFile\"" && exit 1
	        chmod go-rwx "${EncOutputFile}"
		break
	    else
	        DebugMsg 3 "key #$Counter ($KeyIDShort) is rejected (not the destination key)" 
	    fi
    else 
	DebugMsg 2 "key #$Counter ($KeyIDShort) is ignored (no RSA key)" #: ${LinefromFile}"
    fi
done < "${KEYFILE}"

# verify encryption
DebugMsg 3 "verifying encryption"
cat "${EncOutputFile}" | ${DECRYPT} > "${VERFILE}"
cmp -s "${RAWFILE}" "${VERFILE}" ; ec=$?  
case $ec in
   0) DebugMsg 1 "verification passed";;
   *) ErrorMsg "verification failed" && exit 1;;
esac

if (( $RSACounter > 0 )); then
    DebugMsg 3 "accepted $RSACounter key(s)"
    if (( $RSACounter  == 1 )); then
	if [ "${OUTFILE}" == "" ]; then
	    cat "$EncOutputFile" 
	    DebugMsg 1 "output sent to STDOUT"
	else
	    mv "${EncOutputFile}" "${OUTFILE}"
	    DebugMsg 1 "output written to \"${OUTFILE}\""
	fi
    else
	ErrorMsg "only one key should be accepted"; exit 1
    fi
else
    DebugMsg 2 "no keys accepted"
    exit 1
fi 

md5sum "${RAWFILE}" | cut -f 1 -d ' ' > "${MD5FILE}"
DebugMsg 1 "checksum written to \"${MD5FILE}\""

exit 0

# EOF

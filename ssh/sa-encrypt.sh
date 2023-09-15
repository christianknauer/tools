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

DESTKEY="unspecified"
DESTKEYHASH="*"
if [ ! "${PUBKEYFILE}" == "" ]; then
	[ ! -e "$PUBKEYFILE" ] && ErrorMsg "public key file \"$PUBKEYFILE\" cannot be opened" && exit 1
	DebugMsg 1 "reading public key from \"$PUBKEYFILE\""
	# read first line of file
	read KeyType RestOfLine < ${PUBKEYFILE} 
        PublicKey=${RestOfLine%% *}
        PublicKeyHash=$(sacrypt_ComputeHashOfString $PublicKey)
        #KeyIDShort=${PublicKey: -8:8}
        if [[ $KeyType = ssh-rsa ]]; then
	    DebugMsg 3 "using public key $PublicKeyHash"
	    DESTKEY=$PublicKey
	    DESTKEYHASH=$PublicKeyHash
        else 
	    ErrorMsg "public key ($PublicKeyHash) from \"$PUBKEYFILE\" is not an RSA key" && exit 1
        fi
fi

RAWFILE=$(mktemp -p $TEMPD)
ENCFILE=$(mktemp -p $TEMPD)
VERFILE=$(mktemp -p $TEMPD)
[ ! -e "$RAWFILE" ] && ErrorMsg "failed to create temp raw file" && exit 1
[ ! -e "$ENCFILE" ] && ErrorMsg "failed to create temp enc file" && exit 1
[ ! -e "$VERFILE" ] && ErrorMsg "failed to create temp ver file" && exit 1
DebugMsg 3 "using \"$RAWFILE\" as temp raw file"
DebugMsg 3 "using \"$ENCFILE\" as temp enc file"
DebugMsg 3 "using \"$VERFILE\" as temp ver file"
 
if sacrypt_FindKeyInAgent ${DESTKEYHASH}; then
    KEYINDEX=$retval
    DebugMsg 1 "key ${DESTKEYHASH} found in agent (#${KEYINDEX})"
else
    ErrorMsg "key ${DESTKEYHASH} not found in agent (#$retval)"; exit 1
fi

# read file 
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
EncOutputFile="${TEMPD}/decoded.$$.${DESTKEYHASH}"
mv "${ENCFILE}.${Counter}" "${EncOutputFile}"
[ ! -e "$EncOutputFile" ] && ErrorMsg "failed to create output file \"${EncOutputFile}\"" && exit 1
chmod go-rwx "${EncOutputFile}"
KeyFile="${TEMPD}/key.$$.${DESTKEYHASH}"
echo -n "${DESTKEYHASH}" > "${KeyFile}"
	
#ssh-add -L > ${KEYFILE} 2> /dev/null; ec=$?  # grab the exit code into a variable so that it can
#                                 # be reused later, without the fear of being overwritten
#
#NROFKEYS=$(cat ${KEYFILE} | wc -l)
#
#case $ec in
#    0) DebugMsg 3 "agent provides ${NROFKEYS} key(s)";;
#    1) ErrorMsg "ssh-agent has no identities ($ec)"; exit 1;;
#    2) ErrorMsg "ssh-agent is not running ($ec)"; exit 2;;
#    *) ErrorMsg "ssh-agent gives unknown exit code ($ec)"; exit 2;;
#esac
#
#EncOutputFile=""
#KeyFile=""
#Counter=0
#RSACounter=0

#while IFS='' read -r LinefromFile || [[ -n "${LinefromFile}" ]]; do
#
#    ((Counter++))
#
#    KeyType=${LinefromFile%% *}
#    RestOfLine=${LinefromFile#* }
#    PublicKey=${RestOfLine%% *}
#    PublicKeyHash=$(sacrypt_ComputeHashOfString $PublicKey)
#    # KeyIDShort=${PublicKeyHash:0:8}
#
#    DebugMsg 3 "Found $KeyType key (${PublicKeyHash})"
#    if [[ $KeyType = ssh-rsa ]]; then
#            #if [[ ${DESTKEY} == "unspecified" || ${PublicKey} = ${DESTKEY} ]]; then
#            if [[ ${DESTKEY} == "unspecified" || ${PublicKeyHash} = ${DESTKEYHASH} ]]; then
#                ((RSACounter++))
#		EncOutputFile="${TEMPD}/decoded.$$.${PublicKeyHash}"
#		KeyFile="${TEMPD}/key.$$.${PublicKeyHash}"
#		DebugMsg 1 "secret key found in agent"
#		DebugMsg 3 "key #$Counter ($PublicKeyHash) is accepted, result written to \"$EncOutputFile\")" #: ${LinefromFile}"
#	        mv "${ENCFILE}.${Counter}" "$EncOutputFile"
#	        [ ! -e "$EncOutputFile" ] && ErrorMsg "failed to create output file \"$EncOutputFile\"" && exit 1
#	        chmod go-rwx "${EncOutputFile}"
#		echo -n "${PublicKeyHash}" > "${KeyFile}"
#		break
#	    else
#	        DebugMsg 3 "key #$Counter ($PublicKeyHash) is rejected (not the destination key)" 
#	    fi
#    else 
#	DebugMsg 2 "key #$Counter ($PublicKeyHash) is ignored (no RSA key)" #: ${LinefromFile}"
#    fi
#done < "${KEYFILE}"

#if (( $RSACounter > 0 )); then
#    DebugMsg 3 "accepted $RSACounter key(s)"
#    # verify encryption
#    DebugMsg 3 "verifying encryption"
#    cat "${EncOutputFile}" | ${DECRYPT} > "${VERFILE}"
#    cmp -s "${RAWFILE}" "${VERFILE}" ; ec=$?  
#    case $ec in
#       0) DebugMsg 1 "verification passed";;
#       *) ErrorMsg "verification failed" && exit 1;;
#    esac
#
#    if (( $RSACounter  == 1 )); then
#	if [ "${OUTFILE}" == "" ]; then
#	    cat "$EncOutputFile" 
#	    DebugMsg 1 "output sent to STDOUT"
#	else
#	    mv "${EncOutputFile}" "${OUTFILE}"
#	    DebugMsg 1 "output written to \"${OUTFILE}\""
#	fi
#    else
#	ErrorMsg "only one key should be accepted"; exit 1
#    fi
#    sacrypt_ComputeHashOfFile "${RAWFILE}" > "${CHKFILE}"
#    DebugMsg 1 "checksum written to \"${CHKFILE}\""
#
#    cp "${KeyFile}" "${PKHFILE}"
#    DebugMsg 1 "key has written to \"${PKHFILE}\""
#
#    exit 0
#else
#    ErrorMsg "key ${DESTKEYHASH} not found"; exit 1
#fi 

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

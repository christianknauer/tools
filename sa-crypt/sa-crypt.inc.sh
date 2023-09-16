# file: sa-crypt.inc.sh

# de-/encrypt files with ssh agent
# common code

# initialize library
SA_CRYPT_MODULE_DIR=$(dirname "$BASH_SOURCE")
LIB_DIRECTORY="${SA_CRYPT_MODULE_DIR}/../lib/bash"

# load logging module (use global namespace)
LOGGING_NAMESPACE="."; source ${LIB_DIRECTORY}/logging.inc.sh
# load options module (use default namespace "Options.")
source ${LIB_DIRECTORY}/options.inc.sh
# load temp module (use global namespace)
TEMP_NAMESPACE="."; source ${LIB_DIRECTORY}/temp.inc.sh

# constants

# file extensions
SA_CRYPT_DEC_EXT="dec" # decrypted data
SA_CRYPT_ENC_EXT="sad" # encrypted data
SA_CRYPT_KEY_EXT="sak" # public key hash
SA_CRYPT_CHK_EXT="sac" # raw data hash

# compute hashes

sacrypt_ComputeHashOfString () {
    echo -n "$1" | openssl dgst -sha256 | cut -f 2 -d ' '
}

sacrypt_ComputeHashOfFile () {
    openssl dgst -sha256 < "$1" | cut -f 2 -d ' '
}

sacrypt_DetermineKeyHash () {
    retval=""
    local KEYSPEC=$1

    # no key specified 
    [ "${KEYSPEC}" == "" ] && return 0

    # key specified is a hash
    if [ ! -e "${KEYSPEC}" ]; then
        DebugMsg 1 "key spec \"${KEYSPEC}\" is not a file"
	retval=$KEYSPEC
	return 0
    fi

    # key specified is a file
    DebugMsg 3 "reading key from \"${KEYSPEC}\""

    # file contains hash of key
    if [[ "${KEYSPEC}" == *.${SA_CRYPT_KEY_EXT} ]]; then
	DebugMsg 3 "using hash file format"
	retval=$(cat ${KEYSPEC})
	return 0
    fi

    # file contains key
    DebugMsg 3 "using ssh file format"

    # read first line of file
    local KeyType 
    local RestOfLine 
    read KeyType RestOfLine < ${PUBKEYFILE} 
    local PublicKey=${RestOfLine%% *}
    local PublicKeyHash=$(sacrypt_ComputeHashOfString $PublicKey)
    if [[ $KeyType = ssh-rsa ]]; then
        DebugMsg 3 "using ssh-rsa public key $PublicKeyHash"
        retval=$PublicKeyHash
	return 0
    else 
        retval="key ($PublicKeyHash) is not an RSA key" 
	return 1
    fi
}

# decrypt a file 

sacrypt_DecryptFile () {

    local INFILE=$1
    local OUTFILE=$2
    local KEYSPEC=$3
    local TEMPD=$4
    local CHKFILE=$5

    [ ! -d "${TEMPD}" ] && retval="temp dir \"${TEMPD}\" not found" && return 1

    local DECFILE=$(mktemp -p $TEMPD)
    [ ! -e "$DECFILE" ] && retval="failed to create temp dec file" && return 1
    DebugMsg 3 "using \"$DECFILE\" as temp dec file"

    local TMDFILE=$(mktemp -p $TEMPD)
    [ ! -e "$TMDFILE" ] && retval="failed to create temp chk file" && return 1
    DebugMsg 3 "using \"$TMDFILE\" as temp chk file"

    # find the encryption key in the agent 
    sacrypt_FindKeyInAgent ${KEYSPEC} "${TEMPD}"; local ec=$?  
    [ ! $ec -eq 0 ] && return $ec
    local KEYINDEX=$retval
    local KEYHASH=$retval1
    #if sacrypt_FindKeyInAgent ${KEYSPEC} "${TEMPD}"; then
    #    local KEYINDEX=$retval
    #    local KEYHASH=$retval1
    #    DebugMsg 1 "key ${KEYHASH} found in agent (#${KEYINDEX})"
    #else
    #    ErrorMsg "key ${KEYSPEC} not found in agent (#$retval)"; return 1
    #fi
    DebugMsg 1 "key ${KEYHASH} found in agent (#${KEYINDEX})"

    retval=""

    [ ! -e "${INFILE}" ] && retval="input file \"${INFILE}\" not found" && return 1
    cat "${INFILE}" | ${DECRYPT} > "${DECFILE}"; ec=$?  
    case $ec in
        0) DebugMsg 1 "decryption successful";;
        1) retval="decryption failed (key not in agent? not an sae file?)"; return 1;;
        *) retval="decrypt gives unknown exit code ($ec)"; return $ec;;
    esac

    [ ! -e "${DECFILE}" ] && retval="decrypted file \"${DECFILE}\" not found" && return 1

    if [ "${CHKFILE}" == "" ]; then
        DebugMsg 1 "no checksum data available, verification skipped"
    else
        sacrypt_ComputeHashOfFile "${DECFILE}" > "${TMDFILE}"
        cmp -s "${CHKFILE}" "${TMDFILE}" ; ec=$?  
        [ ! $ec -eq 0 ] && retval="checksum verification failed ($ec)" && return $ec
        DebugMsg 1 "checksum verification passed"
    fi

    cp "${DECFILE}" "${OUTFILE}"
    [ ! -e "${OUTFILE}" ] && retval="failed to create output file \"${OUTFILE}\"" && return 1
    chmod go-rwx "${OUTFILE}"

    return 0
}

# encrypt a file 

sacrypt_EncryptFile () {

    local INFILE=$1
    local OUTFILE=$2
    local KEYSPEC=$3
    local TEMPD=$4

    [ ! -d "${TEMPD}" ] && retval="temp dir \"${TEMPD}\" not found" && return 1

    local VERFILE=$(mktemp -p $TEMPD)
    [ ! -e "${VERFILE}" ] && retval="failed to create temp ver file" && return 1
    DebugMsg 3 "using \"${VERFILE}\" as temp ver file"

    local ENCFILE=$(mktemp -p $TEMPD)
    [ ! -e "${ENCFILE}" ] && retval="failed to create temp enc file" && return 1
    DebugMsg 3 "using \"${ENCFILE}\" as temp enc file"

    sacrypt_FindKeyInAgent ${KEYSPEC} "${TEMPD}"; local ec=$?  
    [ ! $ec -eq 0 ] && return $ec
    local KEYINDEX=$retval
    local KEYHASH=$retval1
    #if sacrypt_FindKeyInAgent ${KEYSPEC} "${TEMPD}"; then
    #    local KEYINDEX=$retval
    #    local KEYHASH=$retval1
    #    DebugMsg 1 "key ${KEYHASH} found in agent (#${KEYINDEX})"
    #else
    #    retval="key ${KEYSPEC} not found in agent (#$retval)"; return 1
    #fi

    retval=""

    # encrypt with all keys in agent
    [ ! -e "${INFILE}" ] && retval="input file \"${INFILE}\" not found" && return 1
    cat "${INFILE}" | ${ENCRYPT} > "${ENCFILE}"; ec=$?  
    [ ! $ec -eq 0 ] && retval="encryption failed ($ec)" && return $ec
#    case $ec in
#        0) DebugMsg 1 "encryption ok";;
#	*) retval="encryption failed ($ec)"; return $ec;;
#    esac

    # split encrypted file line by line
    local Counter=0
    while IFS='' read -r LinefromFile || [[ -n "${LinefromFile}" ]]; do
        ((Counter++))
        echo "${LinefromFile}" > "${ENCFILE}.${Counter}"
    done < "${ENCFILE}"

    # extract the correct file
    local ANSWER="${ENCFILE}.${KEYINDEX}"
    [ ! -e "${ANSWER}" ] && retval="file \"${ANSWER}\" not found" && return 1

    # verify encryption
    DebugMsg 3 "verifying encryption"
    cat "${ANSWER}" | ${DECRYPT} > "${VERFILE}"
    cmp -s "${INFILE}" "${VERFILE}" ; ec=$?  
    case $ec in
        0) DebugMsg 1 "verification ok";;
	*) retval="verification failed ($ec)" && return $ec;;
    esac

    # create output
    cp "${ANSWER}" "${OUTFILE}"
    [ ! -e "${OUTFILE}" ] && retval="failed to create output file \"${OUTFILE}\"" && return 1
    chmod go-rwx "${OUTFILE}"

    retval=${KEYHASH}
    return 0
}

# find key in agent

sacrypt_FindKeyInAgent () {

    retval="0"
    retval1=""

    local KeyHashSpec=$1
    local TEMPD=$2

    local KEYFILE=$(mktemp -p $TEMPD)
    [ ! -e "$KEYFILE" ] && retval="failed to create temp key file" && return 1
    DebugMsg 3 "using \"$KEYFILE\" as temp key file"
 
    ssh-add -L > ${KEYFILE} 2> /dev/null; local ec=$? 

    local NROFKEYS=$(cat ${KEYFILE} | wc -l)
    case $ec in
        0) DebugMsg 3 "agent provides ${NROFKEYS} key(s)";;
        1) retval="ssh-agent has no identities"; return 1;;
        2) retval="ssh-agent is not running"; return 2;;
        *) retval="ssh-agent gives unknown exit code ($ec)"; return $ec;;
    esac

    local Counter=0
    while IFS='' read -r LinefromFile || [[ -n "${LinefromFile}" ]]; do

        ((Counter++))

        local KeyType=${LinefromFile%% *}
        local RestOfLine=${LinefromFile#* }
        local PublicKey=${RestOfLine%% *}
        local PublicKeyHash=$(sacrypt_ComputeHashOfString $PublicKey)

        DebugMsg 3 "Found $KeyType key (${PublicKeyHash})"
        if [[ $KeyType = ssh-rsa ]]; then
            if [[ ${PublicKeyHash} = ${KeyHashSpec}* ]]; then
		DebugMsg 3 "key ${PublicKeyHash} (${KeyHashSpec}*) found in agent (#$Counter)"
	        retval=$Counter	
	        retval1=${PublicKeyHash}	
		# key found
    		return 0
		break
	    else
	        DebugMsg 3 "key #$Counter ($PublicKeyHash) is rejected (not the destination key)" 
	    fi
        else 
	    DebugMsg 2 "key #$Counter ($PublicKeyHash) is ignored (no RSA key)"
        fi

    done < "${KEYFILE}"

    # key not found
    retval="key ${KeyHashSpec} not found in agent"; return 1
}

# check binaries
# result stored in globals ENCRYPT, DECRYPT

sacrypt_CheckBinaries () {
    if hash openssl 2>/dev/null; then
        DebugMsg 3 "openssl found"
    else
        ErrorMsg "openssl not found" && exit 1
    fi
    local ARCH=$(uname -m)
    local CODE_DIR="$(dirname $0)/exec/${ARCH}"
    ENCRYPT="${CODE_DIR}/sshcrypt-agent-encrypt"
    DECRYPT="${CODE_DIR}/sshcrypt-agent-decrypt"
    [ ! -e "$ENCRYPT" ] && ErrorMsg "exec file \"${ENCRYPT}\" does not exist" && exit 1
    [ ! -e "$DECRYPT" ] && ErrorMsg "exec file \"${DECRYPT}\" does not exist" && exit 1
    DebugMsg 3 "using exec files \"${ENCRYPT}\", \"${DECRYPT}\""
}

# EOF

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

# constants

# file extensions
SA_CRYPT_DEC_EXT="dec" # encrypted data
SA_CRYPT_ENC_EXT="sae" # encrypted data
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

    # no key specified (via -k), use "" as hash pattern
    [ "${KEYSPEC}" == "" ] && return 0

    # key specified is a hash
    if [ ! -e "$KEYSPEC" ]; then
        DebugMsg 1 "key spec \"$KEYSPEC\" is not a file"
	retval=$KEYSPEC
	return 0
    fi

    # key specified is a file
    
    DebugMsg 3 "reading key from \"$KEYSPEC\""

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
        DebugMsg 3 "using public key $PublicKeyHash"
        retval=$PublicKeyHash
	return 0
    else 
        ErrorMsg "key ($PublicKeyHash) is not an RSA key"
	return 1
    fi
}

# find key in agent

sacrypt_FindKeyInAgent () {

    retval="0"

    local KeyHashSpec=$1

    local KEYFILE=$(mktemp -p $TEMPD)
    [ ! -e "$KEYFILE" ] && ErrorMsg "failed to create temp key file" && exit 1
    DebugMsg 3 "using \"$KEYFILE\" as temp key file"
 
    ssh-add -L > ${KEYFILE} 2> /dev/null; local ec=$? 

    local NROFKEYS=$(cat ${KEYFILE} | wc -l)
    case $ec in
        0) DebugMsg 3 "agent provides ${NROFKEYS} key(s)";;
        1) ErrorMsg "ssh-agent has no identities ($ec)"; exit 1;;
        2) ErrorMsg "ssh-agent is not running ($ec)"; exit 2;;
        *) ErrorMsg "ssh-agent gives unknown exit code ($ec)"; exit 2;;
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
            #if [[ ${DESTKEY} == "unspecified" || ${PublicKeyHash} = ${KeyHashSpec} ]]; then
            ##if [[ ${KeyHashSpec} == "" || ${PublicKeyHash} = ${KeyHashSpec}* ]]; then
            if [[ ${PublicKeyHash} = ${KeyHashSpec}* ]]; then
		DebugMsg 3 "key ${PublicKeyHash} (${KeyHashSpec}*) found in agent (#$Counter)"
	        retval=$Counter	
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
    return 1
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

# create temporary directory 
# name stored in global TEMPD

sacrypt_CreateTempDir() {
    # create temporary directory and store its name in a variable.
    TEMPD=$(mktemp -d)

    # check if the temp directory was created successfully.
    [ ! -e "${TEMPD}" ] && ErrorMsg "failed to create temporary directory" && exit 1
    DebugMsg 3 "created temporary directory \"${TEMPD}\""

    # make sure the temp directory gets removed on script exit.
    trap "exit 1" HUP INT PIPE QUIT TERM
    trap 'sacrypt_CleanupTempOnExit'  EXIT

    # make sure the temp directory is in /tmp.
    [[ ! "${TEMPD}" = /tmp/* ]] && ErrorMsg "temporary directory not in /tmp" && exit 1
}

sacrypt_CleanupTempOnExit () {
    DebugMsg 3 "removing temporary directory \"${TEMPD}\""; rm -rf "${TEMPD}"
}

# EOF

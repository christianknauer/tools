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

# find key in agent

sacrypt_FindKeyInAgent () {

    retval="0"

    local DESTKEYHASH=$1

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

    local KeyType
    local RestOfLine
    local PublicKey
    local PublicKeyHash

    local Counter=0
    while IFS='' read -r LinefromFile || [[ -n "${LinefromFile}" ]]; do

        ((Counter++))

        KeyType=${LinefromFile%% *}
        RestOfLine=${LinefromFile#* }
        PublicKey=${RestOfLine%% *}
        PublicKeyHash=$(sacrypt_ComputeHashOfString $PublicKey)

        DebugMsg 3 "Found $KeyType key (${PublicKeyHash})"
        if [[ $KeyType = ssh-rsa ]]; then
            if [[ ${DESTKEY} == "unspecified" || ${PublicKeyHash} = ${DESTKEYHASH} ]]; then
		DebugMsg 1 "secret key $DESTKEYHASH found in agent"
		DebugMsg 3 "key #$Counter ($PublicKeyHash) is accepted"
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

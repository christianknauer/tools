# file: sage-crypt.inc.sh

# de-/encrypt files with ssh agent + age (common code)

# initialize library
SAGE_CRYPT_MODULE_DIR=$(dirname "$BASH_SOURCE")
LIB_DIRECTORY="${SAGE_CRYPT_MODULE_DIR}/../lib/bash"

# load logging module (use global namespace)
LOGGING_NAMESPACE="."; source ${LIB_DIRECTORY}/logging.inc.sh
# load options module (use default namespace "Options.")
source ${LIB_DIRECTORY}/options.inc.sh

# constants

# file extensions
SAGE_CRYPT_ENC_EXT="sage" # encrypted data

# compute hashes

sagecrypt_CheckBinaries () {
    if hash sa-encrypt.sh 2>/dev/null; then
        DebugMsg 3 "sa-encrypt.sh found"
    else
        ErrorMsg "sa-encrypt.sh not found" && exit 1
    fi
    if hash sa-decrypt.sh 2>/dev/null; then
        DebugMsg 3 "sa-decrypt.sh found"
    else
        ErrorMsg "sa-decrypt.sh not found" && exit 1
    fi
    if hash age 2>/dev/null; then
        DebugMsg 3 "age found"
    else
        ErrorMsg "age not found" && exit 1
    fi
}

# create temporary directory 
# name stored in global TEMPD

sagecrypt_CreateTempDir() {
    # create temporary directory and store its name in a variable.
    retval=$(mktemp -d)

    # check if the temp directory was created successfully.
    [ ! -e "${retval}" ] && ErrorMsg "failed to create temporary directory" && exit 1
    DebugMsg 3 "created temporary directory \"${retval}\""

    # make sure the temp directory gets removed on script exit.
    trap "exit 1" HUP INT PIPE QUIT TERM
    trap "sagecrypt_CleanupTempOnExit \"${retval}\""  EXIT

    # make sure the temp directory is in /tmp.
    [[ ! "${retval}" = /tmp/* ]] && ErrorMsg "temporary directory not in /tmp" && exit 1
}

sagecrypt_CleanupTempOnExit () {
    local TEMPD=$1
    DebugMsg 3 "removing temporary directory \"${TEMPD}\""; rm -rf "${TEMPD}"
}

# EOF

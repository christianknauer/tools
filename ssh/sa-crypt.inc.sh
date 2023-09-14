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

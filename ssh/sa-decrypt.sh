#!/usr/bin/env bash

# file: sa-decrypt.sh

# decrypt files with ssh agent

# initialize library
source lib.inc.sh
[ -z "$LIB_DIRECTORY" ] && echo "ERROR: LIB_DIRECTORY not defined, terminating." && exit 1

# load logging module (use global namespace)
LOGGING_NAMESPACE="."; source ${LIB_DIRECTORY}/logging.inc.sh
# load options module (use default namespace "Options.")
source ${LIB_DIRECTORY}/options.inc.sh

# handle command options

USAGE="[-i INFILE -o OUTFILE -k PUBKEYFILE -d LOGGING_DEBUG_LEVEL ]"
Options.ParseOptions "${USAGE}" ${@}

DebugLoggingConfig 9

# check binaries
ARCH=$(uname -p)
CODE_DIR="$(dirname $0)/exec/${ARCH}"
DECRYPT="${CODE_DIR}/sshcrypt-agent-decrypt"
[ ! -e "$DECRYPT" ] && ErrorMsg "exec file \"${DECRYPT}\" does not exist" && exit 1
DebugMsg 1 "using exec file \"${DECRYPT}\""

# main

# un-comment to see what's going on when you run the script
#set -x 

# create safe working directory
HOMED=$(pwd)

# create temporary directory and store its name in a variable.
TEMPD=$(mktemp -d)

# check if the temp directory was created successfully.
[ ! -e "$TEMPD" ] && ErrorMsg "failed to create temporary directory" && exit 1
DebugMsg 2 "created temporary directory $TEMPD"

# make sure the temp directory gets removed on script exit.
trap "exit 1" HUP INT PIPE QUIT TERM
trap 'DebugMsg 2 "removing temporary directory $TEMPD"; rm -rf "$TEMPD"'  EXIT

# make sure the temp directory is in /tmp.
[[ ! "$TEMPD" = /tmp/* ]] && ErrorMsg "temporary directory not in /tmp" && exit 1

[ "${INFILE}" == "" ] && INFILE="/dev/stdin"
[ "${INFILE}" == "/dev/stdin" ] && OUTFILE="fromstdin.$$.dec"
[ "${OUTFILE}" == "" ] && OUTFILE="$INFILE.dec"

DebugMsg 1 "reading from \"$INFILE\", writing to \"$OUTFILE\""

[ ! -e "$INFILE" ] && ErrorMsg "input file \"$INFILE\" cannot be opened" && exit 1

DECFILE=$(mktemp -p $TEMPD)
[ ! -e "$DECFILE" ] && ErrorMsg "failed to create temporary dec file" && exit 1

DebugMsg 1 "using \"$DECFILE\" as temp dec file"

ssh-add -L > /dev/null ; ec=$?  # grab the exit code into a variable so that it can
                                 # be reused later, without the fear of being overwritten
case $ec in
    0) DebugMsg 1 "ssh-agent provides key(s)";;
    1) ErrorMsg "ssh-agent has no identities ($ec)"; exit 1;;
    2) ErrorMsg "ssh-agent is not running ($ec)"; exit 2;;
    *) ErrorMsg "ssh-agent gives unknown exit code ($ec)"; exit 2;;
esac

#cat "${INFILE}" | ${DECRYPT} > "${OUTFILE}"
cat "${INFILE}" | ${DECRYPT} > "${DECFILE}" ; ec=$?  
case $ec in
    0) InfoMsg  "decryption successful"; mv "${DECFILE}" "${OUTFILE}";;
    1) ErrorMsg "decryption failed (key not in agent?)"; exit 1;;
    *) ErrorMsg "decrypt gives unknown exit code ($ec)"; exit 2;;
esac



exit 0

# EOF

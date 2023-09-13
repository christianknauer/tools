#!/usr/bin/env bash

# file: ssh-agent-enc.sh

# encode files with ssh public keys

# initialize library
source lib.inc.sh
[ -z "$LIB_DIRECTORY" ] && echo "ERROR: LIB_DIRECTORY not defined, terminating." && exit 1


# load logging module (use global namespace)
LOGGING_NAMESPACE="."; source ${LIB_DIRECTORY}/logging.inc.sh
# load options module (use default namespace "Options.")
source ${LIB_DIRECTORY}/options.inc.sh

# functions

ParseOptions () {
    USAGE="[-i INFILE -o OUTFILE -k DESTKEY -d LOGGING_DEBUG_LEVEL ]"
    Options.ParseOptions "${USAGE}" ${@}
}

ParseOptions ${@}
DebugLoggingConfig 9

# main
# un-comment to see what's going on when you run the script
#set -x 

# Safe working directory
HOMED=$(pwd)

# Create a temporary directory and store its name in a variable.
TEMPD=$(mktemp -d)

# Exit if the temp directory wasn't created successfully.
[ ! -e "$TEMPD" ] && ErrorMsg "failed to create temporary directory" && exit 1
DebugMsg 2 "created temporary directory $TEMPD"

# Make sure the temp directory gets removed on script exit.
trap "exit 1" HUP INT PIPE QUIT TERM
trap 'DebugMsg 2 "removing temporary directory $TEMPD"; rm -rf "$TEMPD"'  EXIT

# Make sure the temp directory is in /tmp.
[[ ! "$TEMPD" = /tmp/* ]] && ErrorMsg "temporary directory not in /tmp" && exit 1

[ "${INFILE}" == "" ] && INFILE="/dev/stdin"
[ "${DESTKEY}" == "" ] && DESTKEY="unspecified"
[ "${INFILE}" == "/dev/stdin" ] && OUTFILE="fromstdin.$$.txt"
[ "${OUTFILE}" == "" ] && OUTFILE="$INFILE"

DebugMsg 1 "reading from \"$INFILE\", writing to \"$OUTFILE.*\", key=$DESTKEY"

[ ! -e "$INFILE" ] && ErrorMsg "input file \"$INFILE\" cannot be opened" && exit 1

KEYFILE=$(mktemp -p $TEMPD)
ENCFILE=$(mktemp -p $TEMPD)
[ ! -e "$KEYFILE" ] && ErrorMsg "failed to create temporary key file" && exit 1
[ ! -e "$ENCFILE" ] && ErrorMsg "failed to create temporary enc file" && exit 1

DebugMsg 1 "using \"$KEYFILE\" as temp key file, \"$ENCFILE\" as temp enc file"

ssh-add -l > ${KEYFILE} ; ec=$?  # grab the exit code into a variable so that it can
                                 # be reused later, without the fear of being overwritten

NROFKEYS=$(cat ${KEYFILE} | wc -l)

case $ec in
    0) DebugMsg 1 "agent provides ${NROFKEYS} key(s)"; cat ${INFILE} | sshcrypt-agent-encrypt > ${ENCFILE};;
    1) ErrorMsg "ssh-agent has no identities ($ec)"; exit 1;;
    2) ErrorMsg "ssh-agent is not running ($ec)"; exit 2;;
    *) ErrorMsg "ssh-agent gives unknown exit code ($ec)"; exit 2;;
esac

Counter=0

# split encrypted file line by line
while IFS='' read -r LinefromFile || [[ -n "${LinefromFile}" ]]; do
    ((Counter++))
    echo "${LinefromFile}" > "${ENCFILE}.${Counter}"
done < "${ENCFILE}"

Counter=0
RSACounter=0

while IFS='' read -r LinefromFile || [[ -n "${LinefromFile}" ]]; do

    ((Counter++))

    LineArray=($LinefromFile)
    KeyID=${LineArray[1]}
    KeyIDClean=$(echo "${KeyID}" | sed -e 's/[\\/:\*\?"<>\|\x01-\x1F\x7F]/-/g' -e 's/^\(nul\|prn\|con\|lpt[0-9]\|com[0-9]\|aux\)\(\.\|$\)/-/i' -e 's/^\.*$/-/' -e 's/^$/NONAME/')
    KeyIDClean=${KeyIDClean:7}
    KeyIDShort=${KeyIDClean:35}
    if [[ ${LinefromFile} = *RSA* ]]; then
        if [[ ${LinefromFile} = *SHA256* ]]; then
            if [[ ${DESTKEY} == "unspecified" || ${LinefromFile} = *${DESTKEY}* ]]; then
                ((RSACounter++))
		InfoMsg "key #$Counter ($KeyIDShort) is accepted (result written to \"${OUTFILE}.${KeyIDShort})" #: ${LinefromFile}"
	        mv "${ENCFILE}.${Counter}" "${OUTFILE}.${KeyIDShort}"
	[ ! -e "${OUTFILE}.${KeyIDShort}" ] && ErrorMsg "failed to create output file \"${OUTFILE}.${KeyIDShort}\"" && exit 1
	        chmod go-rwx "${OUTFILE}.${KeyIDShort}"
	    else
	        DebugMsg 1 "key #$Counter ($KeyIDShort) is rejected (wrong fingerprint)" #: ${LinefromFile}"
	    fi
        else
	    WarnMsg "key #$Counter ($KeyIDShort) is ignored (RSA key but no SHA256 fingerprint)" #: ${LinefromFile}"
	fi
    else 
	WarnMsg "key #$Counter ($KeyIDShort) is ignored (no RSA key)" #: ${LinefromFile}"
    fi
done < "${KEYFILE}"

if (( $RSACounter > 0 )); then
    DebugMsg 1 "accepted $RSACounter key(s)"
    exit 0
else
    WarnMsg "no keys accepted"
    exit 1
fi 

exit 0

# EOF

#!/usr/bin/env bash

# file: sa-encrypt.sh

# encrypt files with ssh agent

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
ARCH=$(uname -m)
CODE_DIR="$(dirname $0)/exec/${ARCH}"
ENCRYPT="${CODE_DIR}/sshcrypt-agent-encrypt"
DECRYPT="${CODE_DIR}/sshcrypt-agent-decrypt"
[ ! -e "$ENCRYPT" ] && ErrorMsg "exec file \"${ENCRYPT}\" does not exist" && exit 1
[ ! -e "$DECRYPT" ] && ErrorMsg "exec file \"${DECRYPT}\" does not exist" && exit 1
DebugMsg 3 "using exec files \"${ENCRYPT}\", \"${DECRYPT}\""

# main

# un-comment to see what's going on when you run the script
#set -x 

# create safe working directory
HOMED=$(pwd)

# create temporary directory and store its name in a variable.
TEMPD=$(mktemp -d)

# check if the temp directory was created successfully.
[ ! -e "$TEMPD" ] && ErrorMsg "failed to create temporary directory" && exit 1
DebugMsg 3 "created temporary directory $TEMPD"

# make sure the temp directory gets removed on script exit.
trap "exit 1" HUP INT PIPE QUIT TERM
trap 'DebugMsg 3 "removing temporary directory $TEMPD"; rm -rf "$TEMPD"'  EXIT

# make sure the temp directory is in /tmp.
[[ ! "$TEMPD" = /tmp/* ]] && ErrorMsg "temporary directory not in /tmp" && exit 1

[ "${INFILE}" == "" ] && INFILE="/dev/stdin"
[ "${INFILE}" == "/dev/stdin" ] && OUTFILE="fromstdin.$$.sae"
[ "${OUTFILE}" == "" ] && OUTFILE="$INFILE.sae"

DESTKEY="unspecified"
if [ ! "${PUBKEYFILE}" == "" ]; then
	[ ! -e "$PUBKEYFILE" ] && ErrorMsg "public key file \"$PUBKEYFILE\" cannot be opened" && exit 1
	DebugMsg 3 "reading public key from \"$PUBKEYFILE\""
	# read first line of file
	read KeyType RestOfLine < ${PUBKEYFILE} 
        PublicKey=${RestOfLine%% *}
        KeyIDShort=${PublicKey: -8:8}
        if [[ $KeyType = ssh-rsa ]]; then
	    DebugMsg 1 "reading public key from \"$PUBKEYFILE\""
	    DebugMsg 3 "using public key $KeyIDShort"
	    DESTKEY=$PublicKey
        else 
	    ErrorMsg "public key ($KeyIDShort) from \"$PUBKEYFILE\" is not an RSA key" && exit 1
        fi
fi

DebugMsg 3 "reading from \"$INFILE\", writing to \"$OUTFILE.*\""

[ ! -e "$INFILE" ] && ErrorMsg "input file \"$INFILE\" cannot be opened" && exit 1

KEYFILE=$(mktemp -p $TEMPD)
ENCFILE=$(mktemp -p $TEMPD)
[ ! -e "$KEYFILE" ] && ErrorMsg "failed to create temporary key file" && exit 1
[ ! -e "$ENCFILE" ] && ErrorMsg "failed to create temporary enc file" && exit 1

DebugMsg 3 "using \"$KEYFILE\" as temp key file, \"$ENCFILE\" as temp enc file"

ssh-add -L > ${KEYFILE} ; ec=$?  # grab the exit code into a variable so that it can
                                 # be reused later, without the fear of being overwritten

NROFKEYS=$(cat ${KEYFILE} | wc -l)

case $ec in
    0) DebugMsg 3 "agent provides ${NROFKEYS} key(s)"; cat ${INFILE} | ${ENCRYPT} > ${ENCFILE};;
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
		EncOutputFile="${TEMPD}/${OUTFILE}.${KeyIDShort}"
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
if [ ! "${INFILE}" == "/dev/stdin" ]; then
    VERFILE=$(mktemp -p $TEMPD)
    [ ! -e "$VERFILE" ] && ErrorMsg "failed to create temporary verification file" && exit 1
    DebugMsg 3 "verifying encryption (temp file is \"$VERFILE\")"
    cat "${EncOutputFile}" | ${DECRYPT} > "${VERFILE}"
    cmp -s "$INFILE" "${VERFILE}" ; ec=$?  
    case $ec in
       0) DebugMsg 1 "verification passed";;
       *) ErrorMsg "verification failed" && exit 1;;
    esac
else
    DebugMsg 2 "reading from stdin - verification skipped"
fi

if (( $RSACounter > 0 )); then
    DebugMsg 3 "accepted $RSACounter key(s)"
    if (( $RSACounter  == 1 )); then
	if [ "${INFILE}" == "/dev/stdin" ]; then
	    cat "$EncOutputFile" 
	    DebugMsg 1 "output sent to STDOUT"
	else
	    mv "$EncOutputFile" "$OUTFILE"
	    DebugMsg 1 "output written to \"${OUTFILE}\""
	fi
    else
	ErrorMsg "only one key should be accepted"; exit 1
    fi
    exit 0
else
    DebugMsg 2 "no keys accepted"
    exit 1
fi 

exit 0

# EOF

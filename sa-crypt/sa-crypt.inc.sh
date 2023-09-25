# file: sa-crypt.inc.sh

# de-/encrypt files with ssh agent
# common code

# initialize library
SA_CRYPT_MODULE_DIR=$(dirname "$BASH_SOURCE")

LIB_DIRECTORY="${SA_CRYPT_MODULE_DIR}/../lib/bash"
LIB_DIRECTORY=$(readlink -f -- "${LIB_DIRECTORY}")
[ ! -e "${LIB_DIRECTORY}" ] && echo "$0 (sa-crypt lib) ERROR: lib directory \"${LIB_DIRECTORY}\" does not exist" && exit 1

# load logging module (use global namespace)
LOGGING_LIB_DIRECTORY="${LIB_DIRECTORY}/logging"
[ ! -e "${LOGGING_LIB_DIRECTORY}" ] && echo "$0: ERROR: logging lib directory \"${LOGGING_LIB_DIRECTORY}\" does not exist" && exit 1
LOGGING_NAMESPACE="." source "${LOGGING_LIB_DIRECTORY}/logging.sh"; ec=$?
[ ! $ec -eq 0 ] &&  echo "$0: ERROR: failed to initialize logging lib" && exit $ec

# load options module (use default namespace "Options.")
source "${LIB_DIRECTORY}/options.sh"

## load logging module (use global namespace)
#LOGGING_NAMESPACE="."; source ${LIB_DIRECTORY}/logging.inc.sh
## load options module (use default namespace "Options.")
#source ${LIB_DIRECTORY}/options.inc.sh
## load temp module (use global namespace)
#TEMP_NAMESPACE="."; source ${LIB_DIRECTORY}/temp.inc.sh

# constants

# file extensions
SA_CRYPT_DEC_EXT="dec" # decrypted data
SA_CRYPT_ENC_EXT="sae" # encrypted data
SA_CRYPT_KEY_EXT="sak" # public key hash
SA_CRYPT_AES_EXT="saa" # AES key hash
SA_CRYPT_CHK_EXT="sac" # raw data hash
SA_CRYPT_PKG_EXT="sat" # sae package

SA_CRYPT_AES_KEY="${SA_CRYPT_AES_KEY:=jTx8I33DeeSuwIbwizOvXzwep7hZu8Fq4qR1eSnLgiUXPHPwnmxMPiouFi8ey0sXsap}"
SA_CRYPT_HEADER_KEY="${SA_CRYPT_HEADER_KEY:=JktNcY8VuYDseLDaOKfd7hhMKuCuKsfbX20NLcxPAkbofCmTEu69cVAy2JUtkYba}"

# filename.${SA_CRYPT_ENC_EXT}::KEYSPEC::PASS describes an sa-encrypted
# file filename.${SA_CRYPT_ENC_EXT} with the key specified by ${KEYSPEC} 
# and aes-password ${PASS}; KEYSPEC and PASS can be empty

# returns 1 if 
# - $FILESPEC does not match the required pattern
# - if the file filename.${SA_CRYPT_ENC_EXT} does not exist
#
# returns 0 otherwise; in that case
# - retval=filename.${SA_CRYPT_ENC_EXT}
# - retval1=KEYSPEC
# - retval2=PASS

sacrypt_Init () {

    local InitFileSpec=$1

    [ ! -d "${TEMPD}" ] && retval="temp dir \"${TEMPD}\" not found" && return 1

    # no init file specified 
    [ "${InitFileSpec}" == "" ] && return 0

    sacrypt_ParseSAEFileSpec "${InitFileSpec}"; ec=$?

    if [ $ec -eq 0 ]; then
        local InitFileName=$retval
	local InitFileKeySpec=$retval1
        local InitFilePassword=$retval2

	DebugMsg 3 "reading init from ${SA_CRYPT_ENC_EXT}-file \"${InitFileName}\" with keyspec \"${InitFileKeySpec}\" and password \"${InitFilePassword}\""

        local INITFILE=$(mktemp -p $TEMPD)
        [ ! -e "${INITFILE}" ] && retval="failed to create temp init file" && return 1
        DebugMsg 3 "using \"${INITFILE}\" as temp init file"

	# decrypt 
        sacrypt_DecryptFile "${InitFileName}" "${INITFILE}" "${InitFileKeySpec}" "${TEMPD}" "${InitFilePassword}"; ec=$?
        [ ! $ec -eq 0 ] && ErrorMsg "$retval" && exit $ec
	DebugMsg 3 "init file decryption ok"
    
	[ ! -e "${INITFILE}" ] && retval="init file \"${INITFILE}\"does not exist" && return 1
        source ${INITFILE}
    else 
        WarnMsg "init file specification \"${InitFileSpec}\" malformed" && return 1
    fi

    return 0
}

sacrypt_ParseSAEFileSpec () {

    local FILESPEC=$1

    local FileName
    local KeySpec
    local Password

    retval=""; retval1=""; retval2=""

    if [[ "${FILESPEC}" =~ ^([^:]*${SA_CRYPT_ENC_EXT})(::)?([^:]*)(::)?([^:]*).*$ ]]; then
        FileName="${BASH_REMATCH[1]}"
        KeySpec="${BASH_REMATCH[3]}"
        Password="${BASH_REMATCH[5]}"

        [ ! -e "${FileName}" ] && WarnMsg "file specification refers to non-existent ${SA_CRYPT_ENC_EXT}-file \"$FileName}\"" && return 1
	    
	DebugMsg 3 "${SA_CRYPT_ENC_EXT}-file \"${FileName}\" specified with key spec \"${KeySpec}\" and password \"${Password}\""

	retval=$FileName
	retval1=$KeySpec
	retval2=$Password
	return 0
    fi

    return 1
}

# crypto
sacrypt_DeterminePassword () {
    retval=""
    local PWSPEC=$1
    local TEMPD=$2

    [ ! -d "${TEMPD}" ] && retval="temp dir \"${TEMPD}\" not found" && return 1

    # no pw specified 
    [ "${PWSPEC}" == "" ] && return 0

    DebugMsg 1 "parsing pw spec"

    sacrypt_ParseSAEFileSpec "${PWSPEC}"; ec=$?

    if [ $ec -eq 0 ]; then
        local PWFileName=$retval
	local PWFileKeySpec=$retval1
        local PWFilePassword=$retval2

	DebugMsg 3 "reading password from ${SA_CRYPT_ENC_EXT}-file \"${PWFileName}\" with keyspec \"${PWFileKeySpec}\" and password \"${PWFilePassword}\""

        local DECKFILE=$(mktemp -p $TEMPD)
        [ ! -e "${DECKFILE}" ] && retval="failed to create temp password file" && return 1
        DebugMsg 3 "using \"${DECKFILE}\" as temp password file"

	# decrypt the keyfile 
        sacrypt_DecryptFile "${PWFileName}" "${DECKFILE}" "${PWFileKeySpec}" "${TEMPD}" "${PWFilePassword}"; ec=$?
        [ ! $ec -eq 0 ] && ErrorMsg "$retval" && exit $ec
        DebugMsg 3 "password decryption ok"
    
	[ ! -e "${DECKFILE}" ] && retval="key file \"${DECKFILE}\"does not exist" && return 1
	retval=$(cat ${DECKFILE})
	return 0
    fi

    # pw specified is a string
    if [ ! -e "${PWSPEC}" ]; then
        DebugMsg 1 "pw spec is not a file, using spec as pw"
	retval=${PWSPEC}
	return 0
    fi

    # pw spec designates a file
    DebugMsg 3 "reading pw from \"${PWSPEC}\" (clear text)"
    retval=$(cat ${PWSPEC})

    return 0
}


sacrypt_AES_EncryptFile () {
    local INFILE=$1
    local PASSWORD=$2
    local TEMP=$3
    local FILTER=$4

    # use compression by default
    # (specify "tee" as filter to disable)
    FILTER="${FILTER:=gzip}"

    retval=""

    [ ! -e "${INFILE}" ] && retval="input \"${INFILE}\" file does not exist" && return 1

    local OUTFILE=$(mktemp -p $TEMPD)
    [ ! -e "${OUTFILE}" ] && retval="failed to create temp aes enc file" && return 1
    DebugMsg 3 "using \"${OUTFILE}\" as temp aes enc file (${FILTER} filter)"

    cat "${INFILE}" | ${FILTER} | \
	    openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600000 -salt \
	                -pass pass:${PASSWORD} > "${OUTFILE}" 2> /dev/null; local ec=$?
    [ ! $ec -eq 0 ] && retval="AES encryption failed ($ec)" && return $ec
    [ ! -e "${OUTFILE}" ] && retval="AES encryption file \"${OUTFILE}\" could not be created" && return 1

    retval="${OUTFILE}"
    return 0
}

sacrypt_AES_DecryptFile () {
    local INFILE=$1
    local PASSWORD=$2
    local TEMPD=$3
    local FILTER=$4

    # use compression by default 
    # (specify "tee" as filter to disable)
    FILTER="${FILTER:=gunzip}"

    retval=""

    [ ! -e "${INFILE}" ] && retval="input file does not exist" && return 1

    local OUTFILE=$(mktemp -p $TEMPD)
    [ ! -e "${OUTFILE}" ] && retval="failed to create temp aes dec file" && return 1
    DebugMsg 3 "using \"${OUTFILE}\" as temp aes dec file (${FILTER} filter)"

    cat "${INFILE}" | \
	    openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 600000 -salt \
	                -pass pass:${PASSWORD} 2> /dev/null | ${FILTER} > "${OUTFILE}" 2> /dev/null; local ec=$?
    [ ! $ec -eq 0 ] && retval="AES decryption failed, check password ($ec)" && return $ec
    [ ! -e "${OUTFILE}" ] && retval="AES decryption file \"${OUTFILE}\" could not be created" && return 1

    retval="${OUTFILE}"
    return 0
}

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

# checksums

sacrypt_VerifyFileChecksum () {
    local INFILE=$1
    local CHKFILE=$2
    local TEMPD=$3

    retval="checksum verification passed"

    [ ! -d "${TEMPD}" ] && retval="temp dir \"${TEMPD}\" not found" && return 1

    [ ! -e "$INFILE" ] && retval="input file \"${INFILE}\"does not exist" && return 1
    [ ! -e "$CHKFILE" ] && retval="checksum file \"${CHKFILE}\"does not exist" && return 1

    local TMDFILE=$(mktemp -p $TEMPD)
    [ ! -e "$TMDFILE" ] && retval="failed to create temp chk file" && return 1
    DebugMsg 3 "using \"$TMDFILE\" as temp chk file"

    sacrypt_ComputeHashOfFile "${INFILE}" > "${TMDFILE}"
    cmp -s "${CHKFILE}" "${TMDFILE}"; local ec=$?  
    [ ! $ec -eq 0 ] && retval="checksum verification failed ($ec)" && return $ec

    return 0
}

# decrypt a file 

sacrypt_DecryptFile () {

    local INFILE=$1
    local OUTFILE=$2
    local KEYSPEC=$3
    local TEMPD=$4
    local PASSWORD=$5

    PASSWORD="${PASSWORD:=${SA_CRYPT_AES_KEY}}"

    retval=""

    [ ! -d "${TEMPD}" ] && retval="temp dir \"${TEMPD}\" not found" && return 1

    local DECFILE=$(mktemp -p $TEMPD)
    [ ! -e "$DECFILE" ] && retval="failed to create temp ssh dec file" && return 1
    DebugMsg 3 "using \"$DECFILE\" as temp ssh dec file"

    # decrypt with header key
    sacrypt_AES_DecryptFile ${INFILE} ${SA_CRYPT_HEADER_KEY} ${TEMPD}; local ec=$?  
    [ ! $ec -eq 0 ] && return $ec
    #INFILE="${retval}" 

    # decrypt with agent
    #cat "${INFILE}" | ${DECRYPT} > "${DECFILE}"; ec=$?  
    cat "${retval}" | ${DECRYPT} > "${DECFILE}"; ec=$?  
    case $ec in
        0) DebugMsg 1 "ssh decryption successful";;
        1) retval="ssh decryption failed (key not in agent? input not an sae file?)"; return 1;;
        *) retval="ssh decryption gives unknown exit code ($ec)"; return $ec;;
    esac

    [ ! -e "${DECFILE}" ] && retval="ssh decrypted file \"${DECFILE}\" not found" && return 1

    # decrypt with password
    sacrypt_AES_DecryptFile ${DECFILE} ${PASSWORD} ${TEMPD}; local ec=$?  
    [ ! $ec -eq 0 ] && return $ec

    # copy to output
    cp "${retval}" "${OUTFILE}"
    [ ! -e "${OUTFILE}" ] && retval="failed to create output file \"${OUTFILE}\"" && return 1
    chmod go-rwx "${OUTFILE}"
    DebugMsg 3 "output written to file \"${OUTFILE}\""

    return 0
}

# encrypt a file 

sacrypt_EncryptFile () {

    local INFILE=$1
    local OUTFILE=$2
    local KEYSPEC=$3
    local TEMPD=$4
    local PASSWORD=$5

    PASSWORD="${PASSWORD:=${SA_CRYPT_AES_KEY}}"

    [ ! -e "${INFILE}" ] && retval="input file \"${INFILE}\" not found" && return 1
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
    DebugMsg 1 "key ${KEYHASH} found in agent (#${KEYINDEX})"

    retval=""; retval1=""

    # encrypt with password
    sacrypt_AES_EncryptFile ${INFILE} ${PASSWORD} ${TEMPD}; local ec=$?  
    [ ! $ec -eq 0 ] && return $ec
    INFILE="${retval}" 

    # encrypt with all keys in agent
    cat "${INFILE}" | ${ENCRYPT} > "${ENCFILE}"; ec=$?  
    [ ! $ec -eq 0 ] && retval="encryption failed ($ec)" && return $ec

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

    # encrypt with header key
    sacrypt_AES_EncryptFile ${ANSWER} ${SA_CRYPT_HEADER_KEY} ${TEMPD}; local ec=$?  
    [ ! $ec -eq 0 ] && return $ec

    # create output
    cp "${retval}" "${OUTFILE}"
    [ ! -e "${OUTFILE}" ] && retval="failed to create output file \"${OUTFILE}\"" && return 1

    chmod go-rwx "${OUTFILE}"

    DebugMsg 3 "encrypted data written to \"${OUTFILE}\""

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

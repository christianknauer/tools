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
SA_CRYPT_AES_EXT="aes" # decrypted data
SA_CRYPT_ENC_EXT="sae" # encrypted data
SA_CRYPT_KEY_EXT="sak" # public key hash
SA_CRYPT_CHK_EXT="sac" # raw data hash
SA_CRYPT_PKG_EXT="sap" # package (enc + pk hash + data hash)

SA_CRYPT_AES_KEY="jTx8I33DeeSuwIbwizOvXzwep7hZu8Fq4qR1eSnLgiUXPHPwnmxMPiouFi8ey0sXsap" 

# crypto
sacrypt_DeterminePassword () {
    retval=""
    local PWSPEC=$1
    local PWPW=$2
    local TEMPD=$3

    [ ! -d "${TEMPD}" ] && retval="temp dir \"${TEMPD}\" not found" && return 1

    # no pw specified 
    [ "${PWSPEC}" == "" ] && return 0

    # pw specified is a string
    if [ ! -e "${PWSPEC}" ]; then
        DebugMsg 1 "pw spec is not a file, using spec as pw"
	retval=${PWSPEC}
	return 0
    fi

    # pw spec designates a file
    DebugMsg 3 "reading pw from \"${PWSPEC}\""

    # file contains hash of key
    if [[ "${PWSPEC}" == *.${SA_CRYPT_ENC_EXT} ]]; then
	DebugMsg 3 "using ${SA_CRYPT_ENC_EXT} format"

        local DECKFILE=$(mktemp -p $TEMPD)
        [ ! -e "${DECKFILE}" ] && retval="failed to create temp dec key file" && return 1
        DebugMsg 3 "using \"${DECKFILE}\" as temp dec key file"

	# decrypt the keyfile (empty keyspec)
        sacrypt_DecryptFile "${PWSPEC}" "${DECKFILE}" "" "${TEMPD}" "${PWPW}"; ec=$?
        [ ! $ec -eq 0 ] && ErrorMsg "$retval" && exit $ec
        DebugMsg 3 "key decryption ok"
    
	[ ! -e "${DECKFILE}" ] && retval="key file \"${DECKFILE}\"does not exist" && return 1

	retval=$(cat ${DECKFILE})
    else
	DebugMsg 3 "using clear format"
	retval=$(cat ${PWSPEC})
    fi
    return 0
}


sacrypt_AES_EncryptFile () {
    local INFILE=$1
    local OUTFILE=$2
    local PASSWORD=$3
    retval=""
    cat "${INFILE}" | gzip | \
	    openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600000 -salt \
	                -pass pass:${PASSWORD} > "${OUTFILE}" 2> /dev/null; local ec=$?
    [ ! $ec -eq 0 ] && retval="AES encryption failed ($ec)" && return $ec
    return 0
}

sacrypt_AES_DecryptFile () {
    local INFILE=$1
    local OUTFILE=$2
    local PASSWORD=$3
    retval=""
    cat "${INFILE}" | \
	    openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 600000 -salt \
	                -pass pass:${PASSWORD} 2> /dev/null | gunzip > "${OUTFILE}" 2> /dev/null; local ec=$?
    [ ! $ec -eq 0 ] && retval="AES decryption failed, check password ($ec)" && return $ec
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
#    local CHKFILE=$5

    [ ! -d "${TEMPD}" ] && retval="temp dir \"${TEMPD}\" not found" && return 1

    local DECFILE=$(mktemp -p $TEMPD)
    [ ! -e "$DECFILE" ] && retval="failed to create temp dec file" && return 1
    DebugMsg 3 "using \"$DECFILE\" as temp dec file"

##    # find the encryption key in the agent 
#    sacrypt_FindKeyInAgent ${KEYSPEC} "${TEMPD}"; local ec=$?  
#    [ ! $ec -eq 0 ] && return $ec
#    local KEYINDEX=$retval
#    local KEYHASH=$retval1
#    DebugMsg 1 "key ${KEYHASH} found in agent (#${KEYINDEX})"

    retval=""

    [ ! -e "${INFILE}" ] && retval="input file \"${INFILE}\" not found" && return 1
    cat "${INFILE}" | ${DECRYPT} > "${DECFILE}"; ec=$?  
    case $ec in
        0) DebugMsg 1 "decryption successful";;
        1) retval="decryption failed (key not in agent? input not an sae file?)"; return 1;;
        *) retval="decrypt gives unknown exit code ($ec)"; return $ec;;
    esac

    [ ! -e "${DECFILE}" ] && retval="decrypted file \"${DECFILE}\" not found" && return 1

#    if [ "${CHKFILE}" == "" ]; then
#        DebugMsg 1 "no checksum data available, verification skipped"
#    else
#        sacrypt_ComputeHashOfFile "${DECFILE}" > "${TMDFILE}"
#        cmp -s "${CHKFILE}" "${TMDFILE}" ; ec=$?  
#        [ ! $ec -eq 0 ] && retval="checksum verification failed ($ec)" && return $ec
#        DebugMsg 1 "checksum verification passed"
#    fi
    if [ "${PASSWORD}" == "" ]; then
        DebugMsg 1 "no password specified, using default"
        PASSWORD=$SA_CRYPT_AES_KEY
    fi
    DebugMsg 1 "aes decryption"

    local DECFILEAES=$(mktemp -p $TEMPD)
    [ ! -e "${DECFILEAES}" ] && retval="failed to create temp aes file" && return 1
    DebugMsg 3 "using \"${DECFILEAES}\" as temp aes file"

    sacrypt_AES_DecryptFile ${DECFILE} ${DECFILEAES} ${PASSWORD}; local ec=$?  
    [ ! $ec -eq 0 ] && return $ec

    [ ! -e "${DECFILEAES}" ] && retval="file \"${DECFILEAES}\" not found" && return 1
    DECFILE="${DECFILEAES}" 

    cp "${DECFILE}" "${OUTFILE}"
    [ ! -e "${OUTFILE}" ] && retval="failed to create output file \"${OUTFILE}\"" && return 1
    chmod go-rwx "${OUTFILE}"
    DebugMsg 3 "output written to file \"${OUTFILE}\""

    return 0
}

# encrypt a file to package

sacrypt_EncryptFileToPackage () {

    local INFILE=$1
    local KEYSPEC=$2
    local TEMPD=$3

    [ ! -d "${TEMPD}" ] && retval="temp dir \"${TEMPD}\" not found" && return 1

    local OUTFILE="${INFILE}.${SA_CRYPT_PKG_EXT}"

    local PACKAGED="${TEMPD}/${INFILE}.pkg"
    local PKGENCFILE="${PACKAGED}/${INFILE}.${SA_CRYPT_ENC_EXT}"
    local PKGCHKFILE="${PACKAGED}/${INFILE}.${SA_CRYPT_CHK_EXT}"
    local PKGKEYFILE="${PACKAGED}/${INFILE}.${SA_CRYPT_KEY_EXT}"

    [ -e "${PACKAGED}" ] && retval="temp package directory already exists" && return 1
    mkdir -p "${PACKAGED}"
    [ ! -e "${PACKAGED}" ] && retval="failed to create temp package directory" && return 1
    
    DebugMsg 3 "using \"${PACKAGED}\" as package directory"

    # encrypt the file
    sacrypt_EncryptFile "${INFILE}" "${PKGENCFILE}" "${KEYSPEC}" "${TEMPD}"; local ec=$?; KEYHASH=$retval
    [ ! $ec -eq 0 ] && ErrorMsg "$retval" && exit $ec
    # create checksum file
    sacrypt_ComputeHashOfFile "${INFILE}" > "${PKGCHKFILE}"
    # create key file
    echo -n "${KEYHASH}" > "${PKGKEYFILE}"

    pushd "${TEMPD}" >/dev/null
    tar cvfz "${INFILE}.pkg.tgz" "${INFILE}.pkg"/* > /dev/null; ec=$?
    popd >/dev/null
    [ ! $ec -eq 0 ] && retval="tar failed ($ec)" && exit $ec

    cp "${TEMPD}/${INFILE}.pkg.tgz" "${OUTFILE}"
    [ ! -e "${OUTFILE}" ] && retval="failed to create output file \"${OUTFILE}\"" && return 1
    chmod go-rwx "${OUTFILE}"

    retval="${OUTFILE}"
    return 0

}

# encrypt a file 

sacrypt_EncryptFile () {

    local INFILE=$1
    local OUTFILE=$2
    local KEYSPEC=$3
    local TEMPD=$4
    local PASSWORD=$5

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

    retval=""

    [ ! -e "${INFILE}" ] && retval="input file \"${INFILE}\" not found" && return 1

    if [ "${PASSWORD}" == "" ]; then
        DebugMsg 1 "no password specified, using default"
        PASSWORD=$SA_CRYPT_AES_KEY
    fi
    DebugMsg 1 "aes encryption"

    local INFILEAES=$(mktemp -p $TEMPD)
    [ ! -e "${INFILEAES}" ] && retval="failed to create temp aes file" && return 1
    DebugMsg 3 "using \"${INFILEAES}\" as temp aes file"

    sacrypt_AES_EncryptFile ${INFILE} ${INFILEAES} ${PASSWORD}; local ec=$?  
    [ ! $ec -eq 0 ] && return $ec

    [ ! -e "${INFILEAES}" ] && retval="file \"${INFILEAES}\" not found" && return 1
    INFILE="${INFILEAES}" 

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

   # create output
    cp "${ANSWER}" "${OUTFILE}"
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

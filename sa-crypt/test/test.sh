#!/bin/env bash

export PATH=${PATH}:..

# -----------------------------------------------------------------

set -x 
debug="-d 3"
logfile="-L test.log"
export LOGGING_TIMESTAMP=echo
#debug=""

# -----------------------------------------------------------------
CreateTestData () {
    local PREFIX=$1
    local LEN=$2
    cat /dev/urandom | tr -dc '[:alnum:]' | head -c $LEN > "${PREFIX}${LEN}.txt"
}

# -----------------------------------------------------------------
RunTests () {
    local LEN=$1
    local KEYFILE=$2

    local filename="data${LEN}.txt"

    # no password
    sa-encrypt.sh ${debug} ${logfile} -i ${filename} -k ${KEYFILE} 
    sa-decrypt.sh ${debug} ${logfile} -i ${filename}.sae 
    diff ${filename} ${filename}.sae.dec

    # password
    sa-encrypt.sh ${debug} ${logfile} -i ${filename} -k ${KEYFILE} -p ${passwrd}
    sa-decrypt.sh ${debug} ${logfile} -i ${filename}.sae -p ${passwrd}
    diff ${filename} ${filename}.sae.dec
 
    # raw password file
    sa-encrypt.sh ${debug} ${logfile} -i ${filename} -k ${KEYFILE} -p ${passfile}
    sa-decrypt.sh ${debug} ${logfile} -i ${filename}.sae -p ${passfile}
    diff ${filename} ${filename}.sae.dec

    # sae password file
    sa-encrypt.sh ${debug} ${logfile} -i ${filename} -k ${KEYFILE} -p ${encpassfile}
    sa-decrypt.sh ${debug} ${logfile} -i ${filename}.sae -p ${encpassfile}
    diff ${filename} ${filename}.sae.dec

    # sae password file
    sa-encrypt.sh ${debug} ${logfile} -i ${filename} -k ${KEYFILE} -p ${encpassfile}:
    sa-decrypt.sh ${debug} ${logfile} -i ${filename}.sae -p ${encpassfile}::${keyssh}
    diff ${filename} ${filename}.sae.dec

    # sae password file
    sa-encrypt.sh ${debug} ${logfile} -i ${filename} -k ${KEYFILE} -p $(cat $passfile)
    sa-decrypt.sh ${debug} ${logfile} -i ${filename}.sae -p ${encpassfilewithpw}::::${passwrd}
    diff ${filename} ${filename}.sae.dec

}

# -----------------------------------------------------------------

CreateTestData pw   64

CreateTestData data 64
CreateTestData data 128
CreateTestData data 256 
CreateTestData data 1024
#CreateTestData data 8192

keyssh="key.ssh"
keyhash="key.sak"
#keyfile=$keyssh
passwrd="12345"

passfile="pw64.txt"
encpassfile="${passfile}.sae"
encpassfilewithpw="${passfile}-with-pw.sae"

sa-encrypt.sh ${debug} ${logfile} -i ${passfile} -k ${keyssh}
sa-decrypt.sh ${debug} ${logfile} -i ${encpassfile}
diff ${passfile} ${encpassfile}.dec

sa-encrypt.sh ${debug} ${logfile} -i ${passfile} -o ${encpassfilewithpw} -k ${keyssh} -p ${passwrd}
sa-decrypt.sh ${debug} ${logfile} -i ${encpassfilewithpw} -o ${encpassfilewithpw}.dec  -p ${passwrd}
diff ${passfile} ${encpassfilewithpw}.dec

# -----------------------------------------------------------------


# -----------------------------------------------------------------

RunTests 64 $keyssh
RunTests 64 $keyhash

RunTests 128 $keyssh
RunTests 128 $keyhash

RunTests 256 $keyssh
RunTests 256 $keyhash

RunTests 1024 $keyssh
RunTests 1024 $keyhash

rm -f data*.* ${passfile}*

exit 0

# EOF

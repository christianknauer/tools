# generate keys

# -----------------------------------------------------------
OUTDIR="keys"
DBNAME="keys"
DBFILE="${DBNAME}.kdbx"
# -----------------------------------------------------------

generatePassword() {
  local LEN=$1
  [ -z "${LEN}" ] && LEN="32"
  echo "$(cat /dev/urandom | tr -dc '[:alnum:]' | head -c "${LEN}")"
}

generateKeyPair() {
  local KEYNAME=$1
  local KEYPASS=$2
  ssh-keygen -t ed25519 -C "${KEYNAME}" -f "${KEYNAME}" -P "${KEYPASS}"
}

writePasswordFileOBSOLETE() {
  local KEYNAME=$1
  local KEYPASS=$2

  local PASSFILE="${KEYNAME}.pw"
  [ -z "${KEYPASS}" ] && return 0
  cat <<EOF | tee -a ${PASSFILE}
${KEYPASS}
EOF
}

writeChezmoiSshPubKeyFile() {
  local KEYNAME=$1

  local CMPKFILE="${KEYNAME}.pub.tmpl"
  cat <<EOF | tee -a ${CMPKFILE}
{{- if (contains (lower .chezmoi.hostname) "air2,air4,tpp51,btn6m5") -}}
{{- include "__secrets/ssh/${KEYNAME}.pub" -}}
{{- end -}}}
EOF
}

writeAuthorizedKeysFile() {
  local KEYNAME=$1
  local KEYCOMD=$2
  local USERNAME=$3
  local HOSTNAME=$4
  local COMMENT=$5

  local AUTHFILE="authorized_keys-${USERNAME}@${HOSTNAME}"
  local PUBLIKEY=$(cat "${KEYNAME}.pub" | cut -d ' ' -f 1-2)
  cat <<EOF | tee -a ${AUTHFILE}
# ${KEYNAME} ${COMMENT}
restrict,command="${KEYCOMD}",no-pty,no-agent-forwarding,no-port-forwarding ${PUBLIKEY}
EOF
}

writeSshConfigFileEntry() {
  local ENTRYNAME=$1
  local COMMENT=$2
  local USERNAME=$3
  local HOSTNAME=$4
  local PORTNR=$5
  local KEYNAME=$6
  local KEYCMD=$7

  [ -z "${PORTNR}" ]    && PORTNR="22"
  [ -z "${ENTRYNAME}" ] && ENTRYNAME="${KEYNAME}"

  local SSHFILE="dotssh_config"
  cat <<EOF | tee -a ${SSHFILE}
# ${COMMENT}
# ${KEYCMD}
Host ${ENTRYNAME}
  User ${USERNAME}
  Hostname ${HOSTNAME}
  Port ${PORTNR}
  IdentityFile ~/.ssh/ids/${KEYNAME}

EOF
}

addKdbxEntry() {
  local KEYNAME="$1"
  local PASSWRD="$2"
  local USRNAME="$3"
  local URL="$4"

  cat <<EOF | ph --no-password --no-cache --database ${DBFILE} add ${KEYNAME}
${USRNAME}
${PASSWRD}
${PASSWRD}
${URL}
EOF
  ph --no-password --no-cache --database ${DBFILE} show ${KEYNAME}
}

createKeyNameOBSOLETE() {
  local KEYUSER=$1
  local KEYSUBU=$2
  local KEYSPEC=$3
  local KEYHOST=$4

  local SEP1="_"
  local SEP2="-"
  local SEP3="@"
  [ -z "${KEYSPEC}" ] && SEP1=""
  [ -z "${KEYSUBU}" ] && SEP2=""

  local PREFIX="${KEYSPEC}${SEP1}${KEYUSER}${SEP2}${KEYSUBU}"
  [ -z "${PREFIX}" ] && SEP3=""

  echo "${PREFIX}${SEP3}${KEYHOST}"
}

createKeyName() {
  local KEYUSER=$1
  local KEYSUBU=$2
  local KEYSPEC=$3
  local KEYHOST=$4

  local USEP="-"
  [ -z "${KEYSUBU}" ] && USEP=""
  local USER="${KEYUSER}${USEP}${KEYSUBU}"

  local HUSEP="."
  [ -z "${USER}" ] && HUSEP=""
  local HOSUSR="${KEYHOST}${HUSEP}${USER}"

  local HUSSEP="."
  [ -z "${KEYSPEC}" ] && HUSSEP=""

  echo "${HOSUSR}${HUSSEP}${KEYSPEC}"
}

# -----------------------------------------------------------
rm -rf ${OUTDIR}
mkdir -p ${OUTDIR}
pushd ${OUTDIR}
ph --config ${DBNAME}.ini --no-password --no-cache init --name ${DBNAME} --database ${DBFILE}
# -----------------------------------------------------------

# -----------------------------------------------------------
# -----------------------------------------------------------
# Hetzner storage box 
# -----------------------------------------------------------
# -----------------------------------------------------------

KEYPASS=""
KEYUSER="sub1"
KEYSUBU=""
KEYSPEC="restic-ao"
KEYHOST="hsb"
KEYCOMD="rclone serve restic --stdio --config=/dev/null --append-only ./restic"

KEYNAME="$(createKeyName "${KEYUSER}" "${KEYSUBU}" "${KEYSPEC}" "${KEYHOST}")"
generateKeyPair "${KEYNAME}" "${KEYPASS}"
#writePasswordFile "${KEYNAME}" "${KEYPASS}"
addKdbxEntry "${KEYNAME}" "${KEYPASS}" "${USERNAME}" "${HOSTNAME}"

USERNAME="u343693-sub1"
HOSTNAME="u343693.your-storagebox.de"

writeAuthorizedKeysFile "${KEYNAME}" "${KEYCOMD}" "${USERNAME}" "${HOSTNAME}" "(no password)"
writeSshConfigFileEntry "" "restic append-only" "${USERNAME}" "${HOSTNAME}" "23" "${KEYNAME}" "${KEYCOMD}" 
writeChezmoiSshPubKeyFile "${KEYNAME}"

# -----------------------------------------------------------
# -----------------------------------------------------------
# QNAP NAS
# -----------------------------------------------------------
# -----------------------------------------------------------
USERNAME="backup"
HOSTNAME="nas.christianknauer.de"
KEYUSER="${USERNAME}"
KEYHOST="nas"
# -----------------------------------------------------------
KEYSUBU="ck"
KEYSPEC="sftp-ro"
KEYCOMD="sftp-server -R -d ./${KEYSUBU}/restic"
KEYPASS=""

KEYNAME="$(createKeyName "${KEYUSER}" "${KEYSUBU}" "${KEYSPEC}" "${KEYHOST}")"

generateKeyPair "${KEYNAME}" "${KEYPASS}"
#writePasswordFile "${KEYNAME}" "${KEYPASS}"
addKdbxEntry "${KEYNAME}" "${KEYPASS}" "${USERNAME}" "${HOSTNAME}"
writeAuthorizedKeysFile "${KEYNAME}" "${KEYCOMD}" "${USERNAME}" "${HOSTNAME}" "(no password)"
writeSshConfigFileEntry "" "sftp read-only" "${USERNAME}" "${HOSTNAME}" "" "${KEYNAME}" "${KEYCOMD}" 
writeChezmoiSshPubKeyFile "${KEYNAME}"
# -----------------------------------------------------------
KEYSUBU="ck"
KEYSPEC="restic-ao"
KEYCOMD="rclone serve restic --stdio --config=/dev/null --append-only ./${KEYSUBU}/restic"
KEYPASS=""

KEYNAME="$(createKeyName "${KEYUSER}" "${KEYSUBU}" "${KEYSPEC}" "${KEYHOST}")"

generateKeyPair "${KEYNAME}" "${KEYPASS}"
#writePasswordFile "${KEYNAME}" "${KEYPASS}"
addKdbxEntry "${KEYNAME}" "${KEYPASS}" "${USERNAME}" "${HOSTNAME}"
writeAuthorizedKeysFile "${KEYNAME}" "${KEYCOMD}" "${USERNAME}" "${HOSTNAME}" "(no password)"
writeSshConfigFileEntry "" "restic append-only" "${USERNAME}" "${HOSTNAME}" "" "${KEYNAME}" "${KEYCOMD}" 
writeChezmoiSshPubKeyFile "${KEYNAME}"
# -----------------------------------------------------------
KEYSUBU="ck"
KEYSPEC="restic"
KEYCOMD="rclone serve restic --stdio --config=/dev/null ./${KEYSUBU}/restic"
KEYPASS="$(generatePassword)"

KEYNAME="$(createKeyName "${KEYUSER}" "${KEYSUBU}" "${KEYSPEC}" "${KEYHOST}")"

generateKeyPair "${KEYNAME}" "${KEYPASS}"
#writePasswordFile "${KEYNAME}" "${KEYPASS}"
addKdbxEntry "${KEYNAME}" "${KEYPASS}" "${USERNAME}" "${HOSTNAME}"
writeAuthorizedKeysFile "${KEYNAME}" "${KEYCOMD}" "${USERNAME}" "${HOSTNAME}" "(no password)"
writeSshConfigFileEntry "" "restic" "${USERNAME}" "${HOSTNAME}" "" "${KEYNAME}" "${KEYCOMD}"  
writeChezmoiSshPubKeyFile "${KEYNAME}"

# -----------------------------------------------------------
popd # leave ${OUTDIR}
# -----------------------------------------------------------

# EOF

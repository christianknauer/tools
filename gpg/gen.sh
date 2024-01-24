#!/usr/bin/env bash

# check if we are being sourced
(return 0 2>/dev/null) && sourced=1

[ -n "$sourced" ] && echo "abort: this script cannot be sourced" >&2 && return 1

source kdbx.sh

getKeyTrust() {
	gpg --export-ownertrust 2> /dev/null | grep "$(getKeyFingerprint "$1")" | cut -f 2 -d ':'
}

getKeyId() {
        gpg --list-keys  --with-colons "${1}" 2> /dev/null | grep '^pub' | cut -f 5 -d ':'
}

getKeyFingerprint() {
	gpg --list-keys --fingerprint --with-colons "${1}" 2> /dev/null | grep '^fpr' | head -1 | cut -f 10 -d ':'
}

getKeygrip() {
	gpg --with-colons --fingerprint --with-keygrip "${1}" 2> /dev/null | tail -1 | grep '^grp' | cut -f 10 -d ':' 
}

isKeyCachedinAgent() {
	gpg-connect-agent 'keyinfo --list' /bye | grep "$(getKeygrip "${1}")" | cut -d ' ' -f 7 | grep '^1' > /dev/null 
}

unlockKeyinAgent() {
	local KEYNAME="$1"
	local PASSWORD="$2"

#	local KEYGRIP=$(gpg --with-colons --fingerprint --with-keygrip "${KEYNAME}" | tail -1 | grep '^grp' | cut -f 10 -d ':')
#echo "${PASSWORD}" | "$(gpgconf --list-dirs libexecdir)"/gpg-preset-passphrase --preset "${KEYGRIP}"
        echo "${PASSWORD}" | "$(gpgconf --list-dirs libexecdir)"/gpg-preset-passphrase --preset "$(getKeygrip "${KEYNAME}")" &> /dev/null
}

addKdbxEntry() {
	local database="$1"
	local name="$2"
	local user="$4"
	local URL="$5"
}

SCRIPT=$(basename "$0")
usage() {
	local BOLD="\033[1m"
	local OFF="\033[0m"

	read -r -d '' USAGE <<EOF
  ${BOLD}Usage${OFF}: ${SCRIPT} [OPTIONS] name

  Generate a gpg key pair.

  Arguments:
	name (${BOLD}required${OFF}): name of the key

  Options:
	-F: force overwriting of existing output files

	-p <password>: use <password> as the password 
	-t: read the password from the terminal
	-f <file>: read the password from text file <file>
	-k <file>: read the password from kdbx db <file>

  	-h: show this help

EOF
	echo -e "${USAGE}" 1>&2
	exit 1
}

while getopts "Fhtp:f:" o; do
	case "${o}" in
	F)
		# force mode - overwrite existing files
		FORCE=1
		;;
	t)
		[ -n "${PASSWORD}" ] && echo "abort: password already specified" >&2 && exit 1
		[ ! -t 1 ] && echo "abort: stdout is not a terminal, cannot prompt passphrase" >&2 && exit 1
		# read password from terminal
		#PINTTY=$(tty)
		#PASSWORD=$(echo "GETPIN" | pinentry -T ${PINTTY} 2> /dev/null | grep D)
		#PASSWORD=${PASSWORD#D }
		PASSWORD=$(whiptail --passwordbox "Enter password" 10 40 3>&1 1>&2 2>&3)
		PASSCONF=$(whiptail --passwordbox "Confirm password" 10 40 3>&1 1>&2 2>&3)
		[[ ! "${PASSWORD}" = "${PASSCONF}" ]] && echo "abort: password confirmation error" >&2
		exit 3
		;;
	p)
		[ -n "${PASSWORD}" ] && echo "abort: password already specified" >&2 && exit 1
		# specify seed password via command line
		PASSWORD=${OPTARG}
		;;
	f)
		[ -n "${PASSWORD}" ] && echo "abort: password already specified" >&2 && exit 1
		# read seed password from file
		[ ! -f "${OPTARG}" ] && echo "abort: password file \"${OPTARG}\" does not exist, cannot read passphrase" >&2 && exit 1
		PASSWORD=$(cat "${OPTARG}")
		;;
	h)
		usage
		;;
	*)
		usage
		;;
	esac
done
shift $((OPTIND - 1))

KEYNAME=$1

# filename (base) is required
[ -z "${KEYNAME}" ] && usage

# password is required
[ -z "${PASSWORD}" ] && usage

# key files
SKEYFILE=${KEYNAME}-sec.gpg
PKEYFILE=${KEYNAME}-pub.gpg

# delete old files (if requested)
[ -n "${FORCE}" ] && echo "warning: existing output files will be overwritten (-F)" >&2

if [ -f "${SKEYFILE}" ]; then
  if [ -n "${FORCE}" ]; then
    echo "warning: removing secret key file ${SKEYFILE} (-F)" >&2 
    rm -f "${SKEYFILE}"
  else
    echo "abort: secret key file ${SKEYFILE} present (use -F to overwrite)" >&2 
    exit 1
  fi
fi

if [ -f "${PKEYFILE}" ]; then
  if [ -n "${FORCE}" ]; then
    echo "warning: removing public key file ${PKEYFILE} (-F)" >&2 
    rm -f "${PKEYFILE}"
  else
    echo "abort: public key file ${PKEYFILE} present (use -F to overwrite)" >&2 
    exit 1
  fi
fi

if gpg --list-secret-keys "${KEYNAME}" &>/dev/null; then
  if [ -n "${FORCE}" ]; then
	  echo "warning: removing secret key ${KEYNAME} from gpg storage (-F)" >&2 
    #gpg --yes --delete-secret-key "${KEYNAME}"
    gpg --batch --yes --delete-secret-key "$(getKeyFingerprint "${KEYNAME}")"
    gpg --list-secret-keys "${KEYNAME}" &>/dev/null && echo "abort: secret key ${KEYNAME} could not be removed" >&2 && exit 1
  else
    echo "abort: gpg storage already contains a secret key ${KEYNAME} (use -F to overwrite)" >&2 
    exit 1
  fi
fi

if gpg --list-keys "${KEYNAME}" &>/dev/null; then
  if [ -n "${FORCE}" ]; then
    echo "warning: removing public key ${KEYNAME} from gpg storage (-F)" >&2 
    #gpg --delete-key "${KEYNAME}"
    gpg --batch --yes --delete-key "$(getKeyFingerprint "${KEYNAME}")"
    gpg --list-keys "${KEYNAME}" &>/dev/null && echo "abort: public key ${KEYNAME} could not be removed" >&2 && exit 1
  else
    echo "abort: gpg storage already contains a public key ${KEYNAME} (use -F to overwrite)" >&2 
    exit 1
  fi
fi

# create batch file
BATCHFILE="gpg-create-${KEYNAME}-${RANDOM}.txt"
read -r -d '' BATCHCMDS <<EOF
%echo ${SCRIPT} is generating ${KEYNAME}
Key-Type: RSA
Key-Length: 4096
Subkey-Type: default
Subkey-Length: 4096
Key-Usage: encrypt,sign
Name-Real: GNU pass
Name-Email: ${KEYNAME}
Name-Comment: credentials store
Expire-Date: 0
%commit
%echo done
EOF
echo "${BATCHCMDS}" > "${BATCHFILE}"

# work

# create ephemeral gpg storage
EGPGHOME="dotgpg-${KEYNAME}-${RANDOM}"
mkdir "${EGPGHOME}" 

[ ! -d "${EGPGHOME}" ] && echo "abort: ephemeral gpg storage could not be created" >&2 && return 1

# create keys in ephemeral gpg storage

# this can be useful for debugging
# --logger-file "${EGPGHOME}/gpg-keygen.log"
# --status-file "${EGPGHOME}/gpg-keygen.sta" --with-colons 
echo "${PASSWORD}" | gpg --homedir "${EGPGHOME}" --batch --passphrase-fd 0 --pinentry-mode loopback --enable-large-rsa --gen-key "${BATCHFILE}" &> /dev/null
rm -f "${BATCHFILE}"

# export keys from ephemeral gpg storage to files
gpg --homedir "${EGPGHOME}" --armor --output "${PKEYFILE}" --export "${KEYNAME}" &> /dev/null
echo "${PASSWORD}" | gpg --homedir "${EGPGHOME}" --armor --output "${SKEYFILE}" --export-secret-key --passphrase-fd 0 --pinentry-mode loopback "${KEYNAME}" &> /dev/null

# debugging info only
#gpg --homedir "${EGPGHOME}" --list-secret-keys --keyid-format=long

# remove ephemeral gpg storage
rm -rf "${EGPGHOME}"

# import keys from files to gpg storage
echo "${PASSWORD}" | gpg --passphrase-fd 0 --pinentry-mode loopback --import "${SKEYFILE}" &> /dev/null

# import keys from files to gpg storage
#KEYID=$(gpg --with-colons --import-options show-only --import "${PKEYFILE}" | grep '^pub' | cut -f 5 -d ':')
#expect -c "spawn gpg --edit-key {$KEYID} trust quit; send \"5\\ry\\r\"; expect eof"
# set key trust to ultimate
expect -c "spawn gpg --edit-key {$(getKeyId "${KEYNAME}")} trust quit; send \"5\\ry\\r\"; expect eof" &> /dev/null

# cache key password in agent
unlockKeyinAgent "$KEYNAME" "$PASSWORD"

#gpg-connect-agent 'keyinfo --list' /bye

KEYGRIP=$(getKeygrip "${KEYNAME}")
KEYID=$(getKeyId "${KEYNAME}")
#KEYGRIP=$(gpg --with-colons --fingerprint --with-keygrip "${KEYNAME}" | tail -1 | grep '^grp' | cut -f 10 -d ':')
#echo "${PASSWORD}" | "$(gpgconf --list-dirs libexecdir)"/gpg-preset-passphrase --preset "${KEYGRIP}"

echo "info: ${KEYNAME} created, keyid=${KEYID}, keygrip=${KEYGRIP}"
isKeyCachedinAgent "$KEYNAME" && echo "info: key successfully cached in agent" 
echo "info: key trust level is $(getKeyTrust "${KEYNAME}")"
## check 
#gpg --output ${PWFILE}.gpg --encrypt --recipient "${KEYNAME}" ${PWFILE}
#gpg --output ${PWFILE}.dec --decrypt ${PWFILE}.gpg

# display data
gpg --list-keys --keyid-format=long "${KEYNAME}"
gpg --list-secret-keys --keyid-format=long "${KEYNAME}"

exit 0

# write data to kdbx file
DBNAME="${KEYNAME}"
DBFILE="${DBNAME}.kdbx"
DBENTRYNAME="${KEYNAME}"

if [ ! -f "${DBFILE}" ]; then
  echo "info: no database ${DBFILE} - creating it"
  ph --config "${DBNAME}.ini" --no-password --no-cache init --name "${SCRIPT} - ${DBNAME}" --database "${DBFILE}" 1> /dev/null
else
  echo "info: using database ${DBFILE}"
fi

if ! checkKdbxEntry "${DBFILE}" "${DBENTRYNAME}"; then
  echo "info: no entry at ${DBENTRYNAME} in database - creating it"
  initKdbxEntry "${DBFILE}" "${DBENTRYNAME}" 
else
  echo "info: entry at ${DBENTRYNAME} found in database - overwriting"
fi

#addKdbxEntry "${DBFILE}" "${NAME}" "$(cat "${SFILE}")" "${USERNAME}" "${URL}" "$(cat "${MFILE}")" "${HINT}" "${PASSWORD}"

echo "info: written to kdbx file \"${DBFILE}\""

# EOF

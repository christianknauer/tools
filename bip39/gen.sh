#!/usr/bin/env bash

# check if we are being sourced
(return 0 2>/dev/null) && sourced=1

[ -n "$sourced" ] && echo "abort: this script cannot be sourced" >&2 && return 1

# shellcheck disable=SC1091,SC1094
source bip39.sh

addKdbxEntry() {
	local database="$1"
	local name="$2"
	local password="$3"
	local user="$4"
	local URL="$5"
	local mnemonic="$6"
	local hint="$7"
	local seed_password="$8"

	local FIELDS='notes,bip39_seed_mnemonic_phrase,bip39_seed_password'
	local HINTORPASSWORD="${seed_password}"

	# if a hint is given, the seed_password is not embedded
	[ -n "${hint}" ] && FIELDS="${FIELDS}_hint" && HINTORPASSWORD="${hint}"

	cat <<EOF | ph --no-password --no-cache --database "${database}" add --fields "${FIELDS}" "${name}" 1>/dev/null
${user}
${password}
${password}
${URL}
The password was created from a BIP39 mnemonic phrase.
${mnemonic}
${HINTORPASSWORD}
EOF
	#ph --no-password --no-cache --database ${database} show ${name}
}

SCRIPT=$(basename "$0")
usage() {
	local BOLD="\033[1m"
	local OFF="\033[0m"

	#cat 1>&2 <<EOF
	read -r -d '' USAGE <<EOF
  ${BOLD}Usage${OFF}: ${SCRIPT} [OPTIONS] name

  Generate BIP39 mnemonics and seeds (see https://en.bitcoin.it/wiki/BIP_0039). 

  In generation mode (the standard) this command creates two files "name.mc" and "name.sd". The file "name.mc" contains a randomly generated BIP39 mnemonic. The file "name.sd" contains the corresponding 512 bit seed created from this mnemonic. The seed can be secured with a password. The seed file is a text file (base58 encoding is used) and can be used as a safe password, e.g., for gpg, ssh, etc. 
  Alternatively, an existing mnemonic can be read from a file (see -m).

  In seed verification mode (-v) an existing mnemonic is read from a file (see -m). The corresponding seed is then created (using the seed password specified) and compared against the seed in "name.sd".

  Notes:
        - A seed password is not required for seed creation.
        - The default entropy for mnemonic creation is 256 bits.
        - THE SEED PASSWORD CANNOT BE RECONSTRUCTED FROM THE SEED.

  Arguments:
	name (${BOLD}required${OFF}): name of the project (used as the stem of the output files)

  Options:
	-v: enable verification mode (requires -m)
	-f: force overwriting of existing output files

	-e <128|160|192|224|256>: specify the entropy for mnemonic creation
	    (default is 256)
	-m <file>: read the mnemonic from <file>

	-p <password>: use <password> as the password for seed creation
	-t: read the password for seed creation from the terminal
	-k <file>: read the password for seed creation from <file>

  	-h: show this help

	-U <user>: set seed user to <user> (only for kdbx entry)
	-L <url>: set seed URL to <url> (only for kdbx entry)
	-H use <hint> as the password hint (only for kdbx entry)
	-X use the seed password as the password hint (only for kdbx entry)
	   This overrides (-H). USE WITH CAUTION!
EOF
	echo -e "${USAGE}" 1>&2
	exit 1
}

# default mnemonic entropy
ENTROPY=256

while getopts "Xhfvte:p:k:m:U:L:H:" o; do
	case "${o}" in
	f)
		# force mode - overwrite existing files
		FORCE=1
		;;
	v)
		# verification mode - check if the seed is generated from the mnemonic
		# - needs -m
		VERIFY=1
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
	e)
		# mnemonic entropy
		# possible values are 128|160|192|224|256
		ENTROPY=${OPTARG}
		((ENTROPY == 128 || ENTROPY == 160 || ENTROPY == 192 || ENTROPY == 224 || ENTROPY == 256)) || usage
		;;
	p)
		[ -n "${PASSWORD}" ] && echo "abort: password already specified" >&2 && exit 1
		# specify seed password via command line
		PASSWORD=${OPTARG}
		;;
	k)
		[ -n "${PASSWORD}" ] && echo "abort: password already specified" >&2 && exit 1
		# read seed password from file
		[ ! -f "${OPTARG}" ] && echo "abort: password file \"${OPTARG}\" does not exist, cannot read passphrase" >&2 && exit 1
		PASSWORD=$(cat "${OPTARG}")
		;;
	m)
		# read mnemonic from file
		[ ! -f "${OPTARG}" ] && echo "abort: mnemonic file \"${OPTARG}\" does not exist, cannot read mnemonic" >&2 && exit 1
		MNEMONICFILE=${OPTARG}
		;;
	U)
		# specify kdbx entry user
		USERNAME=${OPTARG}
		;;
	L)
		# specify kdbx entry url
		URL=${OPTARG}
		;;
	H)
		# specify kdbx entry hint on the command line
		HINT=${OPTARG}
		;;
	X)
		# specify seed password as kdbx entry hint
		PASSWORDASHINT=1
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
NAME=$1

# filename (base) is required
[ -z "${NAME}" ] && usage

[ -n "${VERIFY}" ] && [ -z "${MNEMONICFILE}" ] && echo "abort: -v needs -m" >&2 && exit 1

# seed password can be empty, but warn about it
[ -z "${PASSWORD}" ] && echo "warning: empty seed password" >&2

# seed password can be empty, but warn about it
[ -n "${PASSWORD}" ] && [ -n "${PASSWORDASHINT}" ] && echo "warning: seed password is embedded in database" >&2

# if there is not user supplied hint, generate one
[ -z "${HINT}" ] && [ -z "${PASSWORD}" ] && HINT="The seed has no password."
[ -z "${HINT}" ] && [ -n "${PASSWORD}" ] && HINT="The seed password has ${#PASSWORD} symbols."

# override the hint of we want to have the seed password in the database
[ -n "${PASSWORDASHINT}" ] && [ -n "${PASSWORD}" ] && unset HINT

[ -n "${FORCE}" ] && echo "warning: existing output files will be overwritten (-f)" >&2

# work

MFILE=${NAME}.mc
SFILE=${NAME}.sd

# work

if [ -z "${MNEMONICFILE}" ]; then
	echo "info: generating new random mnemonic (${ENTROPY} bits of entropy)"
	# shellcheck disable=SC2207
	mnemonic=($(create-mnemonic "${ENTROPY}"))
	[ -f "${MFILE}" ] && [ -z "${FORCE}" ] && echo "abort: mnemonic file \"${MFILE}\" already exist and will not be overwritten (force with -f)" >&2 && exit 1
	echo -n "${mnemonic[@]}" >"${MFILE}"
	echo "info: mnemonic written to \"${MFILE}\""
else
	echo "info: mnemonic read from \"${MNEMONICFILE}\""
	readarray -td" " mnemonic < <(cat "${MNEMONICFILE}")
fi
#echo "info: mnemonic has ${#mnemonic[*]} words"
# declare -p mnemonic

if [ -n "${VERIFY}" ]; then
	echo "info: verification mode"
	# verification mode
	[ ! -f "${SFILE}" ] && echo "abort (verification): seed file \"${SFILE}\" does not exist" >&2 && exit 1
	TMP_SFILE=$(mktemp -p /tmp)

	BIP39_PASSPHRASE="${PASSWORD}" mnemonic-to-seed "${mnemonic[@]}" | base58 >"${TMP_SFILE}"
	[ ! -f "${TMP_SFILE}" ] && echo "abort (verification): temp seed file \"${TMP_SFILE}\" could not be created" >&2 && exit 1

	ec=0
	cmp -s "${SFILE}" "${TMP_SFILE}"
	ec=$?
	if [ ! $ec -eq 0 ]; then
		echo "info: verification failed ($ec)"
		#echo -n "  existing  seed is "; cat ${SFILE}
		#echo -n "  generated seed is "; cat ${TMP_SFILE}
	else
		echo "info: verification ok"
	fi
	rm -f "${TMP_SFILE}"
	exit ${ec}
fi

# generation mode
[ -f "${SFILE}" ] && [ -z "${FORCE}" ] && echo "abort: seed file \"${SFILE}\" already exist and will not be overwritten (force with -f)" >&2 && exit 1

BIP39_PASSPHRASE="${PASSWORD}" mnemonic-to-seed "${mnemonic[@]}" | base58 >"${SFILE}"
echo "info: seed written to \"${SFILE}\""

# write data to kdbx file

DBNAME="${NAME}"
DBFILE="${DBNAME}.kdbx"

[ ! -f "${DBFILE}" ] && ph --config "${DBNAME}.ini" --no-password --no-cache init --name "${SCRIPT} - ${DBNAME}" --database "${DBFILE}"

addKdbxEntry "${DBFILE}" "${NAME}" "$(cat "${SFILE}")" "${USERNAME}" "${URL}" "$(cat "${MFILE}")" "${HINT}" "${PASSWORD}"
echo "info: data written to kdbx file \"${DBFILE}\""

# EOF

#!/usr/bin/env bash

source bip39.sh

DBNAME="keys"
DBFILE="${DBNAME}.kdbx"

addKdbxEntry() {
	local database="$1"
	local name="$2"
	local password="$3"
	local user="$4"
	local URL="$5"
	local mnemonic="$6"
	local hint="$7"

	cat <<EOF | ph --no-password --no-cache --database ${database} add --fields notes,mnemonic,hint ${name} 1>/dev/null
${user}
${password}
${password}
${URL}
${mnemonic}
${mnemonic}
${hint}
EOF
	#ph --no-password --no-cache --database ${database} show ${name}
}

usage() {
	local SCRIPT=$(basename $0)
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
	-H <hint>: set seed password hint to <hint> (only for kdbx entry)
EOF
	echo -e "${USAGE}" 1>&2
	exit 1
}

# default mnemonic entropy
ENTROPY=256

while getopts "hfvte:p:k:m:U:L:H:" o; do
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
		[ ! -z "${PASSWORD}" ] && echo "abort: password already specified" >&2 && exit 1
		[ ! -t 1 ] && echo "abort: stdout is not a terminal, cannot prompt passphrase" >&2 && exit 1
		# read password from terminal
		#PINTTY=$(tty)
		#PASSWORD=$(echo "GETPIN" | pinentry -T ${PINTTY} 2> /dev/null | grep D)
		#PASSWORD=${PASSWORD#D }
		PASSWORD=$(whiptail --passwordbox "Enter password" 10 40 3>&1 1>&2 2>&3)
		PASSCONF=$(whiptail --passwordbox "Confirm password" 10 40 3>&1 1>&2 2>&3)
		[[ ${PASSWORD} != "${PASSCONF}" ]] && echo "abort: password confirmation error" >&2
		exit 3
		;;
	e)
		# mnemonic entropy
		# possible values are 128|160|192|224|256
		ENTROPY=${OPTARG}
		((ENTROPY == 128 || ENTROPY == 160 || ENTROPY == 192 || ENTROPY == 224 || ENTROPY == 256)) || usage
		;;
	p)
		[ ! -z "${PASSWORD}" ] && echo "abort: password already specified" >&2 && exit 1
		# specify seed password via command line
		PASSWORD=${OPTARG}
		;;
	k)
		[ ! -z "${PASSWORD}" ] && echo "abort: password already specified" >&2 && exit 1
		# read seed password from file
		[ ! -f ${OPTARG} ] && echo "abort: password file \"${OPTARG}\" does not exist, cannot read passphrase" >&2 && exit 1
		PASSWORD=$(cat ${OPTARG})
		;;
	m)
		# read mnemonic from file
		[ ! -f ${OPTARG} ] && echo "abort: mnemonic file \"${OPTARG}\" does not exist, cannot read mnemonic" >&2 && exit 1
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
		# specify kdbx entry hint
		HINT=${OPTARG}
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

[ ! -z "${VERIFY}" ] && [ -z "${MNEMONICFILE}" ] && echo "abort: -v needs -m" >&2 && exit 1

# seed password can be empty, but warn about it
[ -z "${PASSWORD}" ] && echo "warning: empty password" >&2

# if there is not user supplied hint, generate one
[ -z "${HINT}" ] && [ -z "${PASSWORD}" ] && HINT="seed has no password"
[ -z "${HINT}" ] && [ ! -z "${PASSWORD}" ] && HINT="seed password has ${#PASSWORD} symbols"

[ ! -z "${FORCE}" ] && echo "warning: existing output files will be overwritten (-f)" >&2

# work

MFILE=${NAME}.mc
SFILE=${NAME}.sd

# work

if [ -z "${MNEMONICFILE}" ]; then
	echo "info: generating new random mnemonic (${ENTROPY} bits of entropy)"
	mnemonic=($(create-mnemonic ${ENTROPY}))
	[ -f "${MFILE}" ] && [ -z "${FORCE}" ] && echo "abort: mnemonic file \"${MFILE}\" already exist and will not be overwritten (force with -f)" >&2 && exit 1
	echo -n "${mnemonic[@]}" >${MFILE}
	echo "info: mnemonic written to \"${MFILE}\""
else
	echo "info: mnemonic read from \"${MNEMONICFILE}\""
	readarray -td" " mnemonic < <(cat ${MNEMONICFILE})
fi
#echo "info: mnemonic has ${#mnemonic[*]} words"
# declare -p mnemonic

if [ ! -z "${VERIFY}" ]; then
	echo "info: verification mode"
	# verification mode
	[ ! -f "${SFILE}" ] && echo "abort (verification): seed file \"${SFILE}\" does not exist" >&2 && exit 1
	TMP_SFILE=$(mktemp -p /tmp)

	BIP39_PASSPHRASE="${PASSWORD}" mnemonic-to-seed "${mnemonic[@]}" | base58 >${TMP_SFILE}
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
	rm -f ${TMP_SFILE}
	exit ${ec}
fi

# generation mode
[ -f "${SFILE}" ] && [ -z "${FORCE}" ] && echo "abort: seed file \"${SFILE}\" already exist and will not be overwritten (force with -f)" >&2 && exit 1

BIP39_PASSPHRASE="${PASSWORD}" mnemonic-to-seed "${mnemonic[@]}" | base58 >${SFILE}
echo "info: seed written to \"${SFILE}\""

[ ! -f "${DBFILE}" ] && ph --config ${DBNAME}.ini --no-password --no-cache init --name ${DBNAME} --database ${DBFILE}

addKdbxEntry "${DBFILE}" "${NAME}" "$(cat ${SFILE})" "${USERNAME}" "${URL}" "$(cat ${MFILE})" "${HINT}"
echo "info: data written to kdbx file \"${DBFILE}\""

# EOF

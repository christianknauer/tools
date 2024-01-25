#!/usr/bin/env bash

# required for removing trailing and leading spaces
shopt -s extglob

# check if we are being sourced
(return 0 2>/dev/null) && sourced=1
[ -n "$sourced" ] && echo "abort: this script cannot be sourced" >&2 && return 1

## constants
# literal
readonly BOLD="\033[1m"
readonly OFF="\033[0m"
# derived
SCRIPT=$(basename "$0") && readonly SCRIPT

source gpg.sh
source kdbx.sh

function parse_real_comment()
{
  # argument vars
  local real_comment="$1"
  # result vars (call by reference)
  local -n real="$2"
  local -n comment="$3"

  # if a '(' appears in the spec, it must be closed with ')'
  # the enclosed string is the comment
  local pattern='(.*)\((.*)'
  if [[ "${real_comment}" =~ ${pattern} ]]; then
    # the real name is in front of the '('
    real="${BASH_REMATCH[1]##*( )}"
    # remove trailing spaces from the name
    real="${real%%*( )}"
    rest="${BASH_REMATCH[2]}"
    pattern='(.*)\).*'
    # rest must close the comment with ')'
    [[ ! "${rest}" =~ ${pattern} ]] && echo "abort: key specification malformed (comment started but not closed)" >&2 && exit 1
    # shellcheck disable=SC2034
    comment="${BASH_REMATCH[1]}" # return by reference
  else
    # no '(' appears in the spec
    # the spec is used as the real name
    real="$real_comment"
  fi

  return 0
}

function parse_name_spec()
{
  # argument vars
  local name_spec="$1"
  # result vars (call by reference)
  local -n name_email="$2"
  # shellcheck disable=SC2034
  local -n name_real="$3"
  # shellcheck disable=SC2034
  local -n name_comment="$4"

  # if a '<' appears in the spec, it must be closed with '>'
  # the enclosed string is the email
  local pattern='(.*)<(.*)'
  if [[ "${name_spec}" =~ ${pattern} ]]; then
    # the real name (+ commment) is in front of the '<'
    # remove leading + trailing spaces (requires "shopt -s extglob")
    real_and_comment="${BASH_REMATCH[1]##*( )}"
    real_and_comment="${real_and_comment%%*( )}"
    rest="${BASH_REMATCH[2]}"
    pattern='(.*)>.*'
    [[ ! "${rest}" =~ ${pattern} ]] && echo "abort: key specification malformed (email started with < but not closed)" >&2 && exit 1
    name_email="${BASH_REMATCH[1]}"
    parse_real_comment "${real_and_comment}" name_real name_comment
  else
    # no '<' appears in the spec
    # the spec is used as the email (no real or comment)
    name_email="$name_spec" # return by reference
  fi
  # remove leading + trailing spaces (requires "shopt -s extglob")
  name_email="${name_email##*( )}"
  name_email="${name_email%%*( )}"

  return 0
}

function usage()
{
  local USAGE

  read -r -d '' USAGE <<EOF
  ${BOLD}Usage${OFF}: ${SCRIPT} [OPTIONS] name

  Generate a gpg key pair. The name specifier <name> is of the form
  "REAL NAME (comment) <EMAIL>". The real name and the comment parts 
  are optional. The E-Mail is used as the name of the key. A name 
  specifier that does not contain a '<' is used as the key name verbatim.

  Arguments:
	name (${BOLD}required${OFF}): name of the key

  Options:
	-F: Force overwriting of existing output files.

	-p <password>: Use <password> as the password.
	-t: Read the password from the terminal.
	-f <file>: Read the password from text file <file>.

	-k <file>: Read the password from kdbx db <file>.
	    When this option is give, the password specified
	    is used to decode the kdbx db. The password for
	    the secret key is then extracted from the db.

  	-h: Show this help.

	-N: Do not generate new keys.
	    When combined with -F this can be used to delete
	    the keys specified by <name> from gpg and remove 
	    their key files.

EOF
  echo -e "${USAGE}" 1>&2
  exit 1
}

function main()
{
  # variables

  # options
  local FORCE NOGENERATE
  # key parameters
  local NAME_SPEC PASSWORD KEYID KEYFP KEYGRIP

  local kdbx_db kdbx_entry kdbx_password

  local opt
  while getopts "NFhtp:f:k:" opt; do
    case "${opt}" in
      N)
        # no generate mode - do not generate keys
        readonly NOGENERATE=1
        ;;
      F)
        # force mode - overwrite existing files
        readonly FORCE=1
        ;;
      t)
        [ -n "${PASSWORD}" ] && echo "abort: password already specified" >&2 && exit 1
        [ ! -t 1 ] && echo "abort: stdout is not a terminal, cannot prompt passphrase" >&2 && exit 1
        # read password from terminal
        #PINTTY=$(tty)
        #PASSWORD=$(echo "GETPIN" | pinentry -T ${PINTTY} 2> /dev/null | grep D)
        #PASSWORD=${PASSWORD#D }
        PASSWORD=$(whiptail --passwordbox "Enter password" 10 40 3>&1 1>&2 2>&3)
        local PASSCONF
        PASSCONF=$(whiptail --passwordbox "Confirm password" 10 40 3>&1 1>&2 2>&3)
        [[ ! "${PASSWORD}" = "${PASSCONF}" ]] && echo "abort: password confirmation error" >&2 && exit 3
        unset PASSCONF
        ;;
      p)
        [ -n "${PASSWORD}" ] && echo "abort: password already specified" >&2 && exit 1
        # specify password via command line
        PASSWORD=${OPTARG}
        ;;
      f)
        [ -n "${PASSWORD}" ] && echo "abort: password already specified" >&2 && exit 1
        # read password from file
        [ ! -f "${OPTARG}" ] && echo "abort: password file \"${OPTARG}\" does not exist, cannot read passphrase" >&2 && exit 1
        PASSWORD=$(cat "${OPTARG}")
        echo "info: password (${#PASSWORD} symbols) read from ${OPTARG}">&2 
        ;;
      k)
        # read password from kdbx db
        kdbx_db="${OPTARG}"
        [ ! -f "${kdbx_db}" ] && echo "abort: kdbx db \"${kdbx_db}\" does not exist, cannot read passphrase" >&2 && exit 1
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


  readonly NAME_SPEC=$1
  # name spec is required
  [ -z "${NAME_SPEC}" ] && usage

  local NAME_EMAIL NAME_REAL NAME_COMMENT
  parse_name_spec "${NAME_SPEC}" NAME_EMAIL NAME_REAL NAME_COMMENT

  # email is required
  [ -z "${NAME_EMAIL}" ] && usage

  # read password from kdbx db
  if [ -n "${kdbx_db}" ]; then
    kdbx_password="${PASSWORD}"
    [ -z "${kdbx_entry}" ] && kdbx_entry="${NAME_EMAIL}"

    PASSWORD=$(kdbx_get_entry "${kdbx_db}" "${kdbx_password}" "${kdbx_entry}" 'password')
    echo "info: password (${#PASSWORD} symbols) read from ${kdbx_entry}@${kdbx_db}">&2 
  fi

  readonly PASSWORD

  # password is required
  [ -z "${PASSWORD}" ] && echo "abort: no password specified" >&2 && usage

  # key files
  readonly SKEYFILE="${NAME_EMAIL}-sec.gpg"
  readonly PKEYFILE="${NAME_EMAIL}-pub.gpg"

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

  if gpg --list-secret-keys "${NAME_EMAIL}" &>/dev/null; then
    if [ -n "${FORCE}" ]; then
      echo "warning: removing secret key ${NAME_EMAIL} from gpg storage (-F)" >&2
      gpg --batch --yes --delete-secret-key "$(getKeyFingerprint "${NAME_EMAIL}")"
      gpg --list-secret-keys "${NAME_EMAIL}" &>/dev/null && echo "abort: secret key ${NAME_EMAIL} could not be removed" >&2 && exit 1
    else
      echo "abort: gpg storage already contains a secret key ${NAME_EMAIL} (use -F to overwrite)" >&2
      exit 1
    fi
  fi

  if gpg --list-keys "${NAME_EMAIL}" &>/dev/null; then
    if [ -n "${FORCE}" ]; then
      echo "warning: removing public key ${NAME_EMAIL} from gpg storage (-F)" >&2
      gpg --batch --yes --delete-key "$(getKeyFingerprint "${NAME_EMAIL}")"
      gpg --list-keys "${NAME_EMAIL}" &>/dev/null && echo "abort: public key ${NAME_EMAIL} could not be removed" >&2 && exit 1
    else
      echo "abort: gpg storage already contains a public key ${NAME_EMAIL} (use -F to overwrite)" >&2
      exit 1
    fi
  fi

  # abort here if -N was given
  [ -n "${NOGENERATE}" ] && echo "abort: no keys generated (-N)" >&2 && exit 0

  echo "info: starting key generation ..."

  # create batch file
  NAME_REAL_ENTRY="# Name-Real: undefined"
  [ -n "${NAME_REAL}" ] && NAME_REAL_ENTRY="Name-Real: ${NAME_REAL}"

  NAME_COMMENT_ENTRY="# Name-Comment: undefined"
  [ -n "${NAME_COMMENT}" ] && NAME_COMMENT_ENTRY="Name-Comment: ${NAME_COMMENT}"

  local BATCHFILE="gpg-create-${NAME_EMAIL}-${RANDOM}.txt"
  local BATCHCMDS
  read -r -d '' BATCHCMDS <<EOF
%echo ${SCRIPT} is generating ${NAME_EMAIL}
Key-Type: RSA
Key-Length: 4096
Subkey-Type: default
Subkey-Length: 4096
Key-Usage: encrypt,sign,auth
${NAME_REAL_ENTRY}
Name-Email: ${NAME_EMAIL}
${NAME_COMMENT_ENTRY}
Expire-Date: 0
%commit
%echo done
EOF
  echo "${BATCHCMDS}" >"${BATCHFILE}"
  unset BATCHCMDS

  # create ephemeral gpg storage
  local EGPGHOME
  readonly EGPGHOME="dotgpg-${NAME_EMAIL}-${RANDOM}"
  mkdir "${EGPGHOME}"

  [ ! -d "${EGPGHOME}" ] && echo "abort: ephemeral gpg storage could not be created" >&2 && return 1

  # create keys in ephemeral gpg storage

  # this can be useful for debugging
  # --logger-file "${EGPGHOME}/gpg-keygen.log"
  # --status-file "${EGPGHOME}/gpg-keygen.sta" --with-colons
  echo "${PASSWORD}" | gpg --homedir "${EGPGHOME}" --batch --passphrase-fd 0 --pinentry-mode loopback --enable-large-rsa --gen-key "${BATCHFILE}" &>/dev/null
  rm -f "${BATCHFILE}"

  # export keys from ephemeral gpg storage to files
  gpg --homedir "${EGPGHOME}" --armor --output "${PKEYFILE}" --export "${NAME_EMAIL}" &>/dev/null
  echo "${PASSWORD}" | gpg --homedir "${EGPGHOME}" --armor --output "${SKEYFILE}" --export-secret-key --passphrase-fd 0 --pinentry-mode loopback "${NAME_EMAIL}" &>/dev/null

  # remove ephemeral gpg storage
  rm -rf "${EGPGHOME}"

  # import keys from files to gpg storage
  echo "${PASSWORD}" | gpg --passphrase-fd 0 --pinentry-mode loopback --import "${SKEYFILE}" &>/dev/null

  # set key trust to ultimate
  expect -c "spawn gpg --edit-key {$(getKeyId "${NAME_EMAIL}")} trust quit; send \"5\\ry\\r\"; expect eof" &>/dev/null

  # generate report
  KEYID=$(getKeyId "${NAME_EMAIL}")
  KEYFP=$(getKeyFingerprint "${NAME_EMAIL}")
  KEYGRIP=$(getKeygrip "${NAME_EMAIL}")

  echo "info: key ${NAME_EMAIL} created"
  echo "info:   fingerprint=${KEYFP}"
  echo "info:   id=${KEYID}"
  echo "info:   grip=${KEYGRIP}"
  echo "info:   trust=$(getKeyTrust "${NAME_EMAIL}")"

  # cache key in agent
  unlockKeyinAgent "$NAME_EMAIL" "$PASSWORD"
  isKeyCachedinAgent "$NAME_EMAIL" && echo "info:   cached in agent"

  ## check
  #gpg --output ${PWFILE}.gpg --encrypt --recipient "${NAME_EMAIL}" ${PWFILE}
  #gpg --output ${PWFILE}.dec --decrypt ${PWFILE}.gpg

  # display data
  gpg --list-keys --keyid-format=long "${NAME_EMAIL}"
  gpg --list-secret-keys --keyid-format=long "${NAME_EMAIL}"

  # write secret key to kdbx db
  if [ -n "${kdbx_db}" ]; then
    if ! kdbx_check_entry "${kdbx_db}" "${kdbx_password}" "${kdbx_entry}"; then
      echo "info: no entry at ${kdbx_entry} in database - creating it"
      kdbx_init_entry "${kdbx_db}" "${kdbx_password}" "${kdbx_entry}"
    else
      echo "info: entry at ${kdbx_entry} found in database"
    fi
    kdbx_set_entry "${kdbx_db}" "${kdbx_password}" "${kdbx_entry}" 'tags' "gpg-generator"
    kdbx_set_entry "${kdbx_db}" "${kdbx_password}" "${kdbx_entry}" 'gpg_fingerprint' "${KEYFP}"
    kdbx_set_entry "${kdbx_db}" "${kdbx_password}" "${kdbx_entry}" 'gpg_creation_date' "$(date)"
    kdbx_set_entry "${kdbx_db}" "${kdbx_password}" "${kdbx_entry}" 'gpg_secret_key' "$(cat "${SKEYFILE}")"
    kdbx_set_entry "${kdbx_db}" "${kdbx_password}" "${kdbx_entry}" 'gpg_public_key' "$(cat "${PKEYFILE}")"
    kdbx_notes=$(kdbx_get_entry "${kdbx_db}" "${kdbx_password}" "${kdbx_entry}" 'notes')
    kdbx_notes="${kdbx_notes}
This entry was last updated by ${SCRIPT} (gpg key generation) on $(date)."
    kdbx_set_entry "${kdbx_db}" "${kdbx_password}" "${kdbx_entry}" 'notes' "${kdbx_notes}"
    echo "info: keys written to ${kdbx_entry}@${kdbx_db}">&2 
  fi
}

main "$@"

# EOF

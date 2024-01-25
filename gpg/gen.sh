#!/usr/bin/env bash

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
    # - the real name is in front of the '('
    real="${BASH_REMATCH[1]##*( )}"
    real="${real%%*( )}"
    rest="${BASH_REMATCH[2]}"
    pattern='(.*)\).*'
    [[ ! "${rest}" =~ ${pattern} ]] && echo "abort: key specification malformed (comment started with ( but not closed)" >&2 && exit 1
    comment="${BASH_REMATCH[1]}"
  else
    # no '<' appears in the spec
    # the spec is used as the email (no real or comment)
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
  local -n name_real="$3"
  local -n name_comment="$4"

  # if a '<' appears in the spec, it must be closed with '>'
  # the enclosed string is the email
  local pattern='(.*)<(.*)'
  if [[ "${name_spec}" =~ ${pattern} ]]; then
    # - the real name (+ commment) is in front of the '<'
#    real_and_comment="${BASH_REMATCH[1]}"
    # remove leading + trailing spaces (requires "shopt -s extglob")
    real_and_comment="${BASH_REMATCH[1]##*( )}"
    real_and_comment="${real_and_comment%%*( )}"
    rest="${BASH_REMATCH[2]}"
    pattern='(.*)\>.*'
    [[ ! "${rest}" =~ ${pattern} ]] && echo "abort: key specification malformed (email started with < but not closed)" >&2 && exit 1
    name_email="${BASH_REMATCH[1]}"
#    name_real="${real_and_comment}"
    parse_real_comment "${real_and_comment}" name_real name_comment
  else
    # no '<' appears in the spec
    # the spec is used as the email (no real or comment)
    name_email="$name_spec"
  fi

  return 0

  # search for a comment '(...)'
  local pattern='(.*)\((.*)'
  if [[ "${name_spec}" =~ ${pattern} ]]; then
    # a comment appears in the spec
    # - the real name is in front of the comment 
    rest="${BASH_REMATCH[2]}"
    name_real="${BASH_REMATCH[1]}"
    # remove leading + trailing spaces (requires "shopt -s extglob")
    name_real="${name_real##*( )}"
    name_real="${name_real%%*( )}"
    # match the rest of the comment
    # - the comment needs to be closed ')'
    pattern='(.*)\)(.*)'
    if [[ "${rest}" =~ ${pattern} ]]; then
      rest="${BASH_REMATCH[2]}"
      name_comment="${BASH_REMATCH[1]}"
      echo "rest=\"${rest}\""
    else 
      echo "abort: key specification malformed (comment started but not closed)"
    fi 

  else 
    echo "no comment in the specification here"
  fi 


  shopt -s extglob
  
  return 0
}

function addKdbxEntry()
{
  local database="$1"
  local name="$2"
}

function usage()
{
  local USAGE

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

	-N: do not generate new keys
	    (When combined with -F this can be used to delete
	    the keys specified by <name> from gpg and remove 
	    their key files.)

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

  local opt
  while getopts "NFhtp:f:" opt; do
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

  readonly PASSWORD

  local NAME_EMAIL NAME_REAL NAME_COMMENT
  #readonly NAME_SPEC=$1
  #parse_name_spec "${NAME_SPEC}" NAME_EMAIL NAME_REAL NAME_COMMENT

  NAME_SPEC="Clear Name <mail@addr>"
  unset NAME_EMAIL NAME_REAL NAME_COMMENT
  parse_name_spec "${NAME_SPEC}" NAME_EMAIL NAME_REAL NAME_COMMENT
  echo "spec=\"${NAME_SPEC}\""; echo "email=\"${NAME_EMAIL}\""; echo "real=\"${NAME_REAL}\""; echo "comment=\"${NAME_COMMENT}\""; echo "------------------------------"

  NAME_SPEC="Clear Name (weird comment) <mail@addr>"
  unset NAME_EMAIL NAME_REAL NAME_COMMENT
  parse_name_spec "${NAME_SPEC}" NAME_EMAIL NAME_REAL NAME_COMMENT
  echo "spec=\"${NAME_SPEC}\""; echo "email=\"${NAME_EMAIL}\""; echo "real=\"${NAME_REAL}\""; echo "comment=\"${NAME_COMMENT}\""; echo "------------------------------"

  NAME_SPEC="<mail@addr>"
  unset NAME_EMAIL NAME_REAL NAME_COMMENT
  parse_name_spec "${NAME_SPEC}" NAME_EMAIL NAME_REAL NAME_COMMENT
  echo "spec=\"${NAME_SPEC}\""; echo "email=\"${NAME_EMAIL}\""; echo "real=\"${NAME_REAL}\""; echo "comment=\"${NAME_COMMENT}\""; echo "------------------------------"

  NAME_SPEC="mail@addr"
  unset NAME_EMAIL NAME_REAL NAME_COMMENT
  parse_name_spec "${NAME_SPEC}" NAME_EMAIL NAME_REAL NAME_COMMENT
  echo "spec=\"${NAME_SPEC}\""; echo "email=\"${NAME_EMAIL}\""; echo "real=\"${NAME_REAL}\""; echo "comment=\"${NAME_COMMENT}\""; echo "------------------------------"

  #exit 1
  # filename (base) is required
  [ -z "${NAME_EMAIL}" ] && usage

  # password is required
  [ -z "${PASSWORD}" ] && usage

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

  # work

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

  exit 0

  # write data to kdbx file
  DBNAME="${NAME_EMAIL}"
  DBFILE="${DBNAME}.kdbx"
  DBENTRYNAME="${NAME_EMAIL}"

  if [ ! -f "${DBFILE}" ]; then
    echo "info: no database ${DBFILE} - creating it"
    ph --config "${DBNAME}.ini" --no-password --no-cache init --name "${SCRIPT} - ${DBNAME}" --database "${DBFILE}" 1>/dev/null
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
}

main "$@"

# EOF

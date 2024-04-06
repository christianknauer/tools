#!/bin/env bash

(return 0 2>/dev/null) && __sourced=1
[ -n "$__sourced" ] && echo "abort: this script cannot be sourced" >&2 && return 1
script=${0##*/}

echo "$script running"

[ -z "$CHEZMOI" ] && echo "$script abort: chezmoi hooks cannot be run standalone" >&2 && return 1
[ -z "$CHEZMOI_SOURCE_DIR" ] && echo "$script abort: chezmoi source directory not specified" >&2 && return 1

CM_SEC_TIMEOUT="2"
CM_SEC_TARGET_DIR="${CHEZMOI_SOURCE_DIR}/out"
CM_SEC_TARGET_ID=$(echo "$$CM_SEC_TARGET_DIR" | md5sum | cut -f1 -d" ")
CM_SEC_REMOTE="cm$CM_SEC_TARGET_ID"

get_rclone_pid() {
  pgrep -f "$CM_SEC_REMOTE"
}

is_mounted() {
    mountpoint -q "$1"
}

cleanup() {
  is_mounted "$CM_SEC_TARGET_DIR" || rm -rf "$TMP"
}

if ! is_mounted "$CM_SEC_TARGET_DIR"; then

  [ ! -d "$CM_SEC_TARGET_DIR" ] && echo "$script info: target directory $CM_SEC_TARGET_DIR created" && mkdir -p "$CM_SEC_TARGET_DIR"
  [ ! -d "$CM_SEC_TARGET_DIR" ] && echo "$script abort: target directory $CM_SEC_TARGET_DIR not found" && exit 1

  TMP=$(mktemp -d)
  [ ! -d "$TMP" ] && echo "$script abort: temp directory $TMP cannot be created" && exit 1
  trap cleanup EXIT

  CM_SEC_DIR_ENC=$(mktemp -d -p "$TMP")
  [ ! -d "$CM_SEC_DIR_ENC" ] && echo "$script abort: encrypted target directory $CM_SEC_DIR_ENC cannot be created" && exit 1

  RC_CONF_PREFIX="RCLONE_CONFIG_${CM_SEC_REMOTE^^}"
  eval "export ${RC_CONF_PREFIX}_TYPE=crypt"
  eval "export ${RC_CONF_PREFIX}_REMOTE=\"${CM_SEC_DIR_ENC}\""
  eval "export ${RC_CONF_PREFIX}_PASSWORD=$(tr -dc '[:alnum:]' </dev/urandom | head -c 32 | rclone obscure -)"
  eval "export ${RC_CONF_PREFIX}_PASSWORD2=$(tr -dc '[:alnum:]' </dev/urandom | head -c 32 | rclone obscure -)"

  rclone mount --daemon "${CM_SEC_REMOTE}:" "$CM_SEC_TARGET_DIR" || { echo "$script abort: mounting $CM_SEC_DIR_ENC at $CM_SEC_TARGET_DIR failed" && exit 1; }
  is_mounted "$CM_SEC_TARGET_DIR" || { echo "$script abort: mounting target directory ($CM_SEC_TARGET_DIR) failed"; rm -rf "$TMP"; exit 1; }

  echo "fusermount -uz $CM_SEC_TARGET_DIR; rm -rf $TMP" | at now +${CM_SEC_TIMEOUT} minutes &> /dev/null

  echo "$script info: target directory ($CM_SEC_TARGET_DIR) generated (expires in $CM_SEC_TIMEOUT minutes), rclone pid is $(get_rclone_pid)"
else 
  echo "$script abort: target directory ($CM_SEC_TARGET_DIR) already mounted, forcing unmount - rerun command"
  fusermount -uz "$CM_SEC_TARGET_DIR"
  rm -rf "$TMP"
  exit 1
fi

# EOF

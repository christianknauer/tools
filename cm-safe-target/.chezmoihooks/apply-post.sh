#!/bin/env bash

(return 0 2>/dev/null) && __sourced=1
[ -n "$__sourced" ] && echo "abort: this script cannot be sourced" >&2 && return 1
script=${0##*/}

echo "$script running"

[ -z "$CHEZMOI" ] && echo "$script abort: chezmoi hooks cannot be run standalone" >&2 && return 1
[ -z "$CHEZMOI_SOURCE_DIR" ] && echo "$script abort: chezmoi source directory not specified" >&2 && return 1

CM_SEC_TARGET_DIR="${CHEZMOI_SOURCE_DIR}/out"
CM_SEC_TARGET_ID=$(echo "$$CM_SEC_TARGET_DIR" | md5sum | cut -f1 -d" ")
CM_SEC_REMOTE="cm$CM_SEC_TARGET_ID"

get_rclone_pid() {
  pgrep -f "$CM_SEC_REMOTE"
}

is_mounted() {
    mountpoint -q "$1"
}

if ! is_mounted "$CM_SEC_TARGET_DIR"; then
  echo "$script warn: target directory ($CM_SEC_TARGET_DIR) not mounted"
else 
  echo "$script info: unmounting target directory ($CM_SEC_TARGET_DIR)"
  fusermount -uz "$CM_SEC_TARGET_DIR"
fi

# EOF

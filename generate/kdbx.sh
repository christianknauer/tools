# shellcheck shell=bash

ph_password_opt()
{
  local password_opt="--no-password"
  [ -n "${1}" ] && password_opt="--password \"${1}\""
  echo "${password_opt}"
}

kdbx_init_db()
{
  local name="$1"
  local db="$2"
  local password="$3"

  # word splitting intended
  # shellcheck disable=SC2046
  ph --config "${name}.ini" $(ph_password_opt "${password}") --no-cache init --name "${name}" --database "${db}" 1>/dev/null
}

kdbx_init_entry()
{
  local database="$1"
  local password="$2"
  local name="$3"
  # word splitting intended
  # shellcheck disable=SC2046
  printf "empty\nempty\nempty\nempty\n" | ph $(ph_password_opt "${password}") --no-cache --database "${database}" add "${name}" 1>/dev/null
}

kdbx_check_entry()
{
  local database="$1"
  local password="$2"
  local name="$3"
  # shellcheck disable=SC2046
  if ph $(ph_password_opt "${password}") --no-cache --database "${database}" show "${name}" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

kdbx_get_entry()
{
  local database="$1"
  local password="$2"
  local name="$3"
  local field="$4"

  # shellcheck disable=SC2046
  ph $(ph_password_opt "${password}") --no-cache --database "${database}" show --field "${field}" "${name}"
}

kdbx_set_entry()
{
  local database="$1"
  local password="$2"
  local name="$3"
  local field="$4"
  local value="$5"

  # shellcheck disable=SC2046
  ph $(ph_password_opt "${password}") --no-cache --database "${database}" edit --set "${field}" "${value}" "${name}" 1>/dev/null
}

# EOF

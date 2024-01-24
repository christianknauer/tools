# shellcheck shell=bash

initKdbxEntry() {
	local database="$1"
	local name="$2"
        printf "empty\nempty\nempty\nempty\n" | ph --no-password --no-cache --database "${database}" add "${name}" 1>/dev/null
}

checkKdbxEntry() {
	local database="$1"
	local name="$2"
	if ph --no-password --no-cache --database "${database}" show "${name}" &>/dev/null; then
	  return 0
        else
	  return 1
	fi
}

setKdbxEntry() {
	local database="$1"
	local name="$2"
	local field="$3"
	local value="$4"

	ph --no-password --no-cache --database "${database}" edit --set "${field}" "${value}" "${name}" 1>/dev/null
}

# EOF

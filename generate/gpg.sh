# shellcheck shell=bash

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

        echo "${PASSWORD}" | "$(gpgconf --list-dirs libexecdir)"/gpg-preset-passphrase --preset "$(getKeygrip "${KEYNAME}")" &> /dev/null
}

# EOF

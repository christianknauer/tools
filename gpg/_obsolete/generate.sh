KEYNAME=credentials@gnupass.app

PKEYFILE=${KEYNAME}-pub.gpg
SKEYFILE=${KEYNAME}-sec.gpg
PWFILE=password.txt

# temp home for gpg
EGPGHOME=${KEYNAME}-dotgpg

# create ephemeral gpg storage
mkdir ${EGPGHOME}

# create keys in ephemeral gpg storage
cat ${PWFILE} | gpg --homedir ${EGPGHOME} --batch --logger-file ${EGPGHOME}/gpg-keygen.log --status-file ${EGPGHOME}/gpg-keygen.sta --with-colons --passphrase-fd 0 --pinentry-mode loopback --enable-large-rsa --gen-key generate-batch-pass.txt

gpg --homedir ${EGPGHOME} --list-secret-keys --keyid-format=long

# export keys from ephemeral gpg storage to files
gpg --homedir ${EGPGHOME} --armor --output ${PKEYFILE} --export ${KEYNAME}
cat ${PWFILE} | gpg --homedir ${EGPGHOME} --armor --output ${SKEYFILE} --export-secret-key --passphrase-fd 0 --pinentry-mode loopback ${KEYNAME}

# remove ephemeral gpg storage
rm -rf ${EGPGHOME}

# import keys from files to gpg storage to files
KEYID=$(gpg --with-colons --import-options show-only --import ${PKEYFILE} | grep '^pub' | cut -f 5 -d ':')
cat ${PWFILE} | gpg --passphrase-fd 0 --pinentry-mode loopback --import ${SKEYFILE}

# set key trust to ultimate
expect -c "spawn gpg --edit-key {$KEYID} trust quit; send \"5\\ry\\r\"; expect eof"

# cache key password in agent
KEYGRIP=$(gpg --with-colons --fingerprint --with-keygrip ${KEYNAME} | tail -1 | grep '^grp' | cut -f 10 -d ':')
cat ${PWFILE} | "$(gpgconf --list-dirs libexecdir)"/gpg-preset-passphrase --preset ${KEYGRIP}

# check 
gpg --output ${PWFILE}.gpg --encrypt --recipient ${KEYNAME} ${PWFILE}
gpg --output ${PWFILE}.dec --decrypt ${PWFILE}.gpg

# display data
gpg --list-keys --keyid-format=long ${KEYNAME}
gpg --list-secret-keys --keyid-format=long ${KEYNAME}

gpg-connect-agent 'keyinfo --list' /bye

# EOF

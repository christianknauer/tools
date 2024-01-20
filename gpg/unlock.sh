GPPCMD="$(gpgconf --list-dirs libexecdir)"/gpg-preset-passphrase

Email=email@christianknauer.de

gpg-connect-agent 'keyinfo --list' /bye

echo "$(ph show @credentials/gpg/${Email} --field password)" | ${GPPCMD} --preset $(ph show @credentials/gpg/${Email} --field keygrip)

gpg-connect-agent 'keyinfo --list' /bye

# EOF

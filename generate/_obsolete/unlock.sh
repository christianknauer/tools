GPPCMD="$(gpgconf --list-dirs libexecdir)"/gpg-preset-passphrase

Email=email@christianknauer.de

gpg-connect-agent reloadagent /bye
gpg-connect-agent 'keyinfo --list' /bye
echo $(ph show @credentials/gpg/${Email} --field password) | ${GPPCMD} --preset $(ph show @credentials/gpg/${Email} --field keygrip)
gpg-connect-agent 'keyinfo --list' /bye

return 0

keygrips=($(gpg -K --fingerprint --with-colons ${Email} | sed -nr '/fpr/,+1{s/^grp:+(.*):$/\1/p}'))
for keygrip in "${keygrips[@]}"
do
    echo "$keygrip"
    echo $(ph show @credentials/gpg/${Email} --field password) | ${GPPCMD} --preset ${keygrip}
done

# EOF

GPPCMD="$(gpgconf --list-dirs libexecdir)"/gpg-preset-passphrase

Email=email@christianknauer.de

gpg-connect-agent reloadagent /bye
gpg-connect-agent 'keyinfo --list' /bye

keygrips=($(gpg -K --fingerprint --with-colons ${Email} | sed -nr '/fpr/,+1{s/^grp:+(.*):$/\1/p}'))
for keygrip in "${keygrips[@]}"
do
    echo "$keygrip"
    echo $(ph show @credentials/gpg/${Email} --field password) | ${GPPCMD} --preset ${keygrip}
    #echo $(ph show @credentials/gpg/${Email} --field password) | sed 's/.$//' | ${GPPCMD} --preset ${keygrip}
done

#echo $(ph show @credentials/gpg/${Email} --field password) | sed 's/.$//' | ${GPPCMD} --preset $(ph show @credentials/gpg/${Email} --field keygrip)

gpg-connect-agent 'keyinfo --list' /bye

# EOF

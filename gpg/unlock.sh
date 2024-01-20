GPPCMD="$(gpgconf --list-dirs libexecdir)"/gpg-preset-passphrase

Email=email@christianknauer.de

gpg-connect-agent 'keyinfo --list' /bye

fingerprints=($(gpg -K --fingerprint --with-colons ${Email} | sed -nr '/fpr/,+1{s/^grp:+(.*):$/\1/p}'))
# preset each fingerprint
for fingerprint in "${fingerprints[@]}"
do
    echo "$fingerprint"
    echo deadbeefaffe66666666666666 | ${GPPCMD} --preset $fingerprint
done

gpg-connect-agent 'keyinfo --list' /bye

return 0
echo $(ph show @credentials/gpg/${Email} --field password) | ${GPPCMD} --preset $(ph show @credentials/gpg/${Email} --field keygrip)


gpg-connect-agent 'keyinfo --list' /bye

# EOF

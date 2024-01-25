Email=email@christianknauer.de

gpg-connect-agent 'keyinfo --list' /bye

keygrips=($(gpg -K --fingerprint --with-colons ${Email} | sed -nr '/fpr/,+1{s/^grp:+(.*):$/\1/p}'))
for keygrip in "${keygrips[@]}"
do
    echo "$keygrip"
done

# EOF

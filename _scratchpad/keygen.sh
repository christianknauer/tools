#!/bin/env bash

#set -x

KEY_ID="keyname"
SKEY_PW="password"
SKEY_SSH_ID="key.pub"
PW_SSH_ID="key.pub"

# create random pw if no pw is specified
[ "${SKEY_PW}" == "" ] && SKEY_PW=$(cat /dev/urandom | tr -dc '[:alnum:]' | head -c 64)

# create $KEY_ID.sk.pw.sae 
echo -n "$SKEY_PW" > $KEY_ID.sk.pw 
sa-encrypt.sh -i $KEY_ID.sk.pw -k $PW_SSH_ID -o $KEY_ID.sk.pw.sae 
rm $KEY_ID.sk.pw 

# create $KEY_ID.pk

# generate key pair
age-keygen -o $KEY_ID.sk 2> $KEY_ID.pk

# creates $KEY_ID.sk.sae 
# uses 
# $SKEY_SSH_ID as agent encryption key
# $SKEY_PW as aes password
# needs
# $SKEY_SSH_ID in agent
# $PW_SSH_ID in agent 

sa-encrypt.sh -i $KEY_ID.sk -k $SKEY_SSH_ID -p "$SKEY_PW" -o $KEY_ID.sk.sae 
rm $KEY_ID.sk 

# remove key & checksum files
rm *.sak *.sac


# creates 
# $KEY_ID.sk
# needs
# $SKEY_SSH_ID in agent
# $PW_SSH_ID in agent 

sa-decrypt.sh -i $KEY_ID.sk.sae -p $KEY_ID.sk.pw.sae 

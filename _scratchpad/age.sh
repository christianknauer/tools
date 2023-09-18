#!/bin/env bash

empty="./empty"
tmp="/tmp/empty.tmp"			# tempfile to store results

# -----------------------------------------------------------------------------
password="12345"			# password (Change it!)
infile="age.sh"
outfile="${infile}.age"

rm $outfile 
$empty -f -L $tmp age -a -p -o $outfile $infile
$empty -w -v "Enter passphrase" "$password\n" >/dev/null
$empty -w -v "Confirm passphrase" "$password\n" >/dev/null

exit 0

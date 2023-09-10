#!/usr/bin/env bash

# show_droplets.sh

source lib.inc.sh
source token.inc.sh

Begin "Starting"

DROPLETS=$(curl -sS -X GET "https://api.digitalocean.com/v2/droplets" \
	-H "Authorization: Bearer $DO_TOKEN")

DROPLETS=$(echo $DROPLETS | jq ".droplets")

echo $DROPLETS

# EOF

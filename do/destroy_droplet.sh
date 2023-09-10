#!/usr/bin/env bash

# destroy_droplet.sh

source config.inc.sh
source token.inc.sh

# doctl compute droplet delete --force ubuntu-testing

DROPLETS=$(curl -sS -X GET "https://api.digitalocean.com/v2/droplets" \
	-H "Authorization: Bearer $DO_TOKEN")

DROPLET_ID=$(echo $DROPLETS | jq ".droplets | map(select(.name|contains(\"$DROPLET_NAME\")))[0].id")

echo $DROPLET_ID

#[ ! $DROPLET_ID == "null" ] || echo "ERROR: droplet $DROPLET_NAME not found." && exit 1

curl -X DELETE "https://api.digitalocean.com/v2/droplets/$DROPLET_ID" \
	-H "Authorization: Bearer $DO_TOKEN" \
	-H "Content-Type: application/json"

#[ ! $ANSWER == "" ] || echo "ERROR: droplet $DROPLET_NAME ($DROPLET_ID) could not be deleted." && exit 1

#echo $ANSWER
echo "droplet $DROPLET_NAME ($DROPLET_ID) was deleted."

# EOF

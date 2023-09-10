#!/usr/bin/env bash

source config.inc.sh
source token.inc.sh

SSH_KEYS=$(curl -sS -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DO_TOKEN" \
  "https://api.digitalocean.com/v2/account/keys")

DROPLET_SSH_KEY_ID=$(echo $SSH_KEYS | jq ".ssh_keys | map(select(.name|contains(\"$DROPLET_SSH_KEY_NAME\")))[0].id")

DOMAIN_RECORS=$(curl -sS -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DO_TOKEN" \
  "https://api.digitalocean.com/v2/domains/$DROPLET_DOMAIN/records")

DROPLET_DOMAIN_ID=$(echo $DOMAIN_RECORS | jq ".domain_records | map(select(.name|contains(\"$DROPLET_HOST_NAME\")))[0].id")

RESPONSE=$(curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DO_TOKEN" \
  -d "{\"name\":\"$DROPLET_NAME\",\"region\":\"$DROPLET_REGION\",\"size\":\"$DROPLET_SIZE\",\"image\":\"$DROPLET_IMAGE\",\"ssh_keys\":[$DROPLET_SSH_KEY_ID],\"vpc_uuid\":\"$DROPLET_VPC\",\"with_droplet_agent\":false}" \
  "https://api.digitalocean.com/v2/droplets")

DROPLET_ID=$(echo $RESPONSE | jq ".droplet.id")

CREATE_ACTION_ID=$(echo $RESPONSE | jq ".links.actions| map(select(.rel|contains(\"create\")))[0].id")

STATUS="in-progress"
while [ "$STATUS" = "in-progress" ]; do
	echo -n "."
	sleep 5
	RESPONSE=$(curl -sS -X GET \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer $DO_TOKEN" \
	  "https://api.digitalocean.com/v2/actions/$CREATE_ACTION_ID")
	STATUS=$(echo $RESPONSE | jq -r ".action.status")
done

DROPLET=$(curl -sS -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DO_TOKEN" \
  "https://api.digitalocean.com/v2/droplets/$DROPLET_ID")

DROPLET_IP=$(echo $DROPLET | jq -r ".droplet.networks.v4| map(select(.type|contains(\"public\")))[0].ip_address")

curl -X PUT \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DO_TOKEN" \
  -d '{"data":"'"$DROPLET_IP"'"}' \
  "https://api.digitalocean.com/v2/domains/$DROPLET_DOMAIN/records/$DROPLET_DOMAIN_ID"

# EOF

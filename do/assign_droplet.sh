#!/usr/bin/env bash

source config.inc.sh
source token.inc.sh

PROJECTS=$(curl -sS -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DO_TOKEN" \
  "https://api.digitalocean.com/v2/projects")

DROPLET_PROJECT_ID=$(echo $PROJECTS | jq -r ".projects | map(select(.name|contains(\"$DROPLET_PROJECT_NAMET\")))[0].id")

DROPLETS=$(curl -sS -X GET "https://api.digitalocean.com/v2/droplets" \
	-H "Authorization: Bearer $DO_TOKEN")

DROPLET_ID=$(echo $DROPLETS | jq ".droplets | map(select(.name|contains(\"$DROPLET_NAME\")))[0].id")

curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DO_TOKEN" \
  -d "{\"resources\": [\"do:droplet:$DROPLET_ID\"]}" \
  "https://api.digitalocean.com/v2/projects/$DROPLET_PROJECT_ID/resources"

curl -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DO_TOKEN" \
  "https://api.digitalocean.com/v2/projects/$DROPLET_PROJECT_ID/resources"

# EOF

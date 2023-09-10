#!/usr/bin/env bash

# file: show_droplets.sh

source lib.inc.sh

export LOGGING_LEVEL_DEBUG=0
export LOGGING_LEVEL_SCOPE="show_droplets"

source token.inc.sh

Begin show_droplets.sh

InfoMsg "show_droplets"

DebugLoggingConfig 2

DROPLETS=$(curl -sS -X GET "https://api.digitalocean.com/v2/droplets" \
	-H "Authorization: Bearer $DO_TOKEN")

DROPLETS=$(echo $DROPLETS | jq ".droplets")

echo $DROPLETS

# EOF

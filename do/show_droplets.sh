#!/usr/bin/env bash

# file: show_droplets.sh

source lib.inc.sh

LOGGING_LEVEL=3
LOGGING_MODULES="show_droplets"

source token.inc.sh

LoggingModuleName show_droplets

InfoMsg "show_droplets"

DebugLoggingConfig 2

DROPLETS=$(curl -sS -X GET "https://api.digitalocean.com/v2/droplets" \
	-H "Authorization: Bearer $DO_TOKEN")

DROPLETS=$(echo $DROPLETS | jq ".droplets")

echo $DROPLETS

# EOF

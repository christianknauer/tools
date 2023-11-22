#!/usr/bin/env bash

# file: show_droplets.sh

source lib.inc.sh
[ -z "$LIB_DIRECTORY" ] && echo "show_droplets.sh: LIB_DIRECTORY not defined, terminating." && exit 1

LOGGING_NAMESPACE="."
source ${LIB_DIRECTORY}/logging.sh
#LOGGING_DEBUG_LEVEL=3

source token.inc.sh

InfoMsg "show_droplets"

DROPLETS=$(curl -sS -X GET "https://api.digitalocean.com/v2/droplets" \
	-H "Authorization: Bearer $DO_TOKEN")

echo $DROPLETS

DROPLETS=$(echo $DROPLETS | jq ".droplets")

echo $DROPLETS

# EOF

#!/bin/bash

# Script to export preferences from a specified cClear as JSON files.
# Modified from Paul Sulistio's scripts.

###### Show help on how to use this script ######
OPTSPEC=":hu:p:t:"

show_help() {
cat << EOF
Usage: $0 [-u USER] [-p PASSWORD] [-f FROM_FOLDER] [-t TARGET_HOST_IP]
Script to export grafana dashboards
    -u      Required. cClear user to login
    -p      Required. cClear user password to login
    -t      Required. The IP of the source cClear host i.e  10.51.10.32
    -h      Display this help and exit.
EOF
}

###### Check script invocation options ######
while getopts "$OPTSPEC" optchar; do
    case "$optchar" in
        h)
            show_help
            exit
            ;;
        u)
            USER="$OPTARG";;
        p)
            PASSWORD="$OPTARG";;
        t)
            TARGET_HOST_IP="$OPTARG";;
        \?)
          echo "Invalid option: -$OPTARG" >&2
          exit 1
          ;;
        :)
          echo "Option -$OPTARG requires an argument." >&2
          exit 1
          ;;
    esac
done

###### Check required arguments ######
if [ -z "$USER" ] || [ -z "$PASSWORD" ] || [ -z "$TARGET_HOST_IP" ]; then
    show_help
    exit 1
fi

# set some colors for status OK, FAIL and titles
SETCOLOR_SUCCESS="echo -en \\033[0;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"
SETCOLOR_TITLE_PURPLE="echo -en \\033[0;35m" # purple 

# usage log "string to log" "color option"
function log_success() {
   if [ $# -lt 1 ]; then
       ${SETCOLOR_FAILURE}
       echo "Not enough arguments for log function! Expecting 1 argument got $#"
       exit 1
   fi

   timestamp=$(date "+%Y-%m-%d %H:%M:%S %Z")

   ${SETCOLOR_SUCCESS}
   printf "[${timestamp}] $1\n"
   ${SETCOLOR_NORMAL}
}

function log_failure() {
   if [ $# -lt 1 ]; then
       ${SETCOLOR_FAILURE}
       echo "Not enough arguments for log function! Expecting 1 argument got $#"
       exit 1
   fi

   timestamp=$(date "+%Y-%m-%d %H:%M:%S %Z")

   ${SETCOLOR_FAILURE}
   printf "[${timestamp}] $1\n"
   ${SETCOLOR_NORMAL}
}

function log_title() {
   if [ $# -lt 1 ]; then
       ${SETCOLOR_FAILURE}
       log_failure "Not enough arguments for log function! Expecting 1 argument got $#"
       exit 1
   fi

   ${SETCOLOR_TITLE_PURPLE}
   printf "|-------------------------------------------------------------------------|\n"
   printf "|$1|\n";
   printf "|-------------------------------------------------------------------------|\n"
   ${SETCOLOR_NORMAL}
}

function init() {
   PREF_FOLDER="preferences"
   PREF_DIR="$PWD/${PREF_FOLDER}"
   if [ ! -d "${PREF_DIR}" ]; then
   	 mkdir -p "${PREF_DIR}"
   else
   	 log_title "----------------- A $PREF_DIR directory already exists! -----------------"
   	 log_title "----------------- Rename or remove this directory before continuing -----------------"
   	 exit 1
   fi
}

# set cookie param for curl command according to login options
STATUS_CODE=$(curl --noproxy '*' -k --write-out '%{http_code}' --silent --output /dev/null --data "uname=$USER&psw=$PASSWORD" "https://$TARGET_HOST_IP/sess/login?rp=/vb/")
if [[ "$STATUS_CODE" -eq 404 ]]; then
  HOST="https://$USER:$PASSWORD@$TARGET_HOST_IP"
elif [[ "$STATUS_CODE" -eq 302 ]]; then
  HOST="https://$TARGET_HOST_IP"
  mycookie="$PWD/mycookie"
  LOGIN=$(curl --noproxy '*' -k -c mycookie --data "uname=$USER&psw=$PASSWORD" $HOST/sess/login?rp=/vb/)
  CURL_COOKIE="-b $mycookie"
else
  show_help
  exit 1
fi

init
# Get preferences
pref_org_json=$(curl --noproxy '*' -k $CURL_COOKIE "$HOST/graph-engine/api/org/preferences")
pref_user_json=$(curl --noproxy '*' -k $CURL_COOKIE "$HOST/graph-engine/api/user/preferences")

# log result
if [ -z "$pref_org_json" ] || [ -z "$pref_user_json" ]; then
  log_failure "Failed to download preferences. Please check parameters passed in. "
  show_help
  exit 1
elif [[ "$pref_org_json" == *"Unauthorized"* ]] || [[ "$pref_user_json" == *"Unauthorized"* ]]; then
  log_failure "Failed to login: $pref_org_json; $pref_user_json"
  exit 1
fi

# Save preferences
PREF_ORG="$PREF_DIR/preferences_org.json"
PREF_USER="$PREF_DIR/preferences_user.json"
echo $pref_org_json | jq '.' > "$PREF_ORG"
log_success "Org. preferences saved: $pref_org_json"
echo $pref_user_json | jq '.' > "$PREF_USER"
log_success "User preferences saved: $pref_user_json"

cclear_json=$(curl --noproxy '*' -k $CURL_COOKIE  "$HOST/api/admin/info")
CCLEAR_VERSION="cclear_$(echo $cclear_json | jq '.data.software.build' | tr -d '"')"
grafana_json=$(curl --noproxy '*' -k $CURL_COOKIE  "$HOST/graph-engine/api/health")
GRAFANA_VERSION="grafana_$(echo $grafana_json | jq '.version' | tr -d '"')"
DATE_TIME="date_$(date '+%d%m%Y_%H%M%S')"
PREF_FILE_ZIP="${PREF_FOLDER}_${TARGET_HOST_IP}_${CCLEAR_VERSION}_${GRAFANA_VERSION}_${DATE_TIME}"
zip -r -m "${PREF_FILE_ZIP}.zip" "${PREF_FOLDER}"
rm mycookie

log_title "Preferences were saved in ${PREF_FILE_ZIP}";
log_title "------------------------------ FINISHED ---------------------------------";

#!/bin/bash
#
#
#

OPTSPEC=":hu:p:t:f:"

show_help() {
cat << EOF
Usage: $0 [-u USER] [-p PASSWORD] [-f FROM_FOLDER] [-t TARGET_HOST]
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
            HOST="$OPTARG";;
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

if [ -z "$USER" ] || [ -z "$PASSWORD" ] || [ -z "$HOST" ]; then
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
   DATE_TIME=$(date '+%d%m%Y_%H%M%S')
   DASH_DIR="$PWD/preferences_${HOST}_${DATE_TIME}"
   if [ ! -d "${DASH_DIR}" ]; then
   	 mkdir "${DASH_DIR}"
   else
   	 log_title "----------------- A $DASH_DIR directory already exists! -----------------"
   fi
}

init

PREF_ORG="$DASH_DIR/preferences_org.json"
PREF_USER="$DASH_DIR/preferences_user.json"

# host url
if [[ ! "$HOST" == "https://"* ]]; then
  HOST="https://$HOST"
fi

mycookie="$PWD/mycookie"
curl --noproxy '*' -k -c mycookie --data "uname=$USER&psw=$PASSWORD" "$HOST/sess/login?rp=/vb/"

# Get preferences
pref_org_json=$(curl --noproxy '*' -k -b "$mycookie" "$HOST/graph-engine/api/org/preferences")
pref_user_json=$(curl --noproxy '*' -k -b "$mycookie" "$HOST/graph-engine/api/user/preferences")

rm mycookie

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
echo $pref_org_json | jq '.' > "$PREF_ORG"
log_success "Org. preferences saved: $pref_org_json"
echo $pref_user_json | jq '.' > "$PREF_USER"
log_success "User preferences saved: $pref_user_json"

log_title "Preferences were saved in $DASH_DIR";
log_title "------------------------------ FINISHED ---------------------------------";

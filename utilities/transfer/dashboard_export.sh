#!/bin/bash

# Script to export dashboards from a specified cClear  as JSON files
# "folderUid" and "folderTitle" are added to each dashboard to help identify the folders to import later by
# running "dashboard_import.sh".
# Modified from Paul Sulistio's scripts.

# todo: add support to import multiple folders separated by ";"

OPTSPEC=":hu:p:t:f:"

# Show help on how to use this script
show_help() {
cat << EOF
Usage: $0 [-u USER] [-p PASSWORD] [-t TARGET_HOST_IP] [-f FROM_FOLDER]
Script to export grafana dashboards
    -u      Required. cClear user to login
    -p      Required. cClear user password to login
    -t      Required. The IP of the source cClear host i.e 10.51.10.32
    -f      Optional. The name of the folder to export from, double quotes with spaces. Export all folders if not
    specified.
    -h      Display this help and exit.
EOF
}

# Check script invocation options
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
        f)
            FROM="$OPTARG";;
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

# Check required arguments
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
   DASH_FOLDER="dashboards"
   DASH_DIR="$PWD/${DASH_FOLDER}"
   if [ ! -d "${DASH_DIR}" ]; then
   	 mkdir -p "${DASH_DIR}"
   else
   	 log_title "----------------- A $DASH_DIR directory already exists! -----------------"
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

# get folders
folder_json=$(curl --noproxy '*' -k $CURL_COOKIE --request "GET" -H "Content-Type:application/json" \
"$HOST/graph-engine/api/folders")
# From folder specified:
declare -a dashboard_uids
if [ ${#FROM} -gt 0 ]; then
  IFS=';' read -ra FROM_LIST <<< "$FROM"
  for i in "${FROM_LIST[@]}"; do
    folder_i=$(echo $i | xargs)
    # Find matching folder from remote (with folder title)
    FOLDER_UID=$(echo "$folder_json" | jq -r '.[] | select(.title == "'"${folder_i}"'") | .uid')
    # Folder not found, prompt error and exit
    if [ -z "$FOLDER_UID" ] ; then
      log_failure "Folder ${i} is not found. Please check spelling and double quote with any spaces."
      continue
    fi
    # Folder found: get the collection of dashboard uids in this folder
    uids=$(curl --noproxy '*' -k $CURL_COOKIE  "$HOST"/graph-engine/api/search\?query\=\& | \
    jq -r '.[] | select(.type | contains("dash-db")) | select(.folderUid != null) | select(.folderUid == "'"$FOLDER_UID"'") | .uid')
    dashboard_uids+=${uids[@]}
  done
# From all folders:
else
  dashboard_uids=$(curl --noproxy '*' -k $CURL_COOKIE  "$HOST"/graph-engine/api/search\?query\=\& | \
  jq -r '.[] | select(.type | contains("dash-db")) | .uid')
fi

#echo "dashboard_uids: "$dashboard_uids

# exit if nothing to import
#if [[ ${#dashboard_uid[@]} -eq 0 ]]; then
#  exit 1
#fi

# Export dashboards
init
counter=0
for dashboard_uid in $dashboard_uids; do
   url=$(echo "$HOST/graph-engine/api/dashboards/uid/$dashboard_uid" | tr -d '\r')
   dashboard_json=$(curl --noproxy '*' -k $CURL_COOKIE  "$url")
   dashboard_title=$(echo "$dashboard_json" | jq -r '.dashboard | .title' | sed -r 's/[ \/]+/_/g' )
   dashboard_file=$(echo "$dashboard_title" | tr '[:upper:]' '[:lower:]')
   dashboard_version=$(echo "$dashboard_json" | jq -r '.dashboard | .version')
   dashboard_folder_raw=$(echo "$dashboard_json" | jq -r '.meta | .folderTitle')
   dashboard_folder=$(echo "$dashboard_json" | jq -r '.meta | .folderTitle' | sed -r 's/[ \/]+/_/g' )
   dashboard_folderId=$(echo "$dashboard_json" | jq -r '.meta | .folderId')

   # Find folder uid to save (so that importing can find the right folder to import to)
   folder_uid=$(echo "$folder_json" | jq -r '.[] | select(.id=='$dashboard_folderId') | .uid ')

   # create the folder if not existing
   if [ ! -d "${DASH_DIR}/${dashboard_folder}" ]; then
   	 mkdir "${DASH_DIR}/${dashboard_folder}"
   fi

   counter=$((counter + 1))
   # save dashboard with folder uid and title to help identify folders to import later.
   echo "$dashboard_json" | jq  '.dashboard | . += {"folderUid":"'$folder_uid'", "folderTitle": "'"$dashboard_folder_raw"'"}' > \
   "$DASH_DIR/${dashboard_folder}/${dashboard_file}_v${dashboard_version}.json"
   log_success "Dashboard has been saved\t\t title=\"${dashboard_file}\", uid=\"${dashboard_uid}\",
   path=\"${DASH_DIR}/${dashboard_folder}/${dashboard_file}_v${dashboard_version}.json\"."
done

if [[ ${counter} -gt 0 ]]; then
   cclear_json=$(curl --noproxy '*' -k $CURL_COOKIE  "$HOST/api/admin/info")
   CCLEAR_VERSION="cclear_$(echo $cclear_json | jq '.data.software.build' | tr -d '"')"
   grafana_json=$(curl --noproxy '*' -k $CURL_COOKIE  "$HOST/graph-engine/api/health")
   GRAFANA_VERSION="grafana_$(echo $grafana_json | jq '.version' | tr -d '"')"
   DATE_TIME="date_$(date '+%d%m%Y_%H%M%S')"
   DASH_FILE_ZIP="${DASH_FOLDER}_${TARGET_HOST_IP}_${CCLEAR_VERSION}_${GRAFANA_VERSION}_${DATE_TIME}"
   zip -r -m ${DASH_FILE_ZIP}.zip ${DASH_FOLDER}
fi
rm mycookie 2> /dev/null

log_title "${counter} dashboards were saved in "$PWD/${DASH_FILE_ZIP}".zip";
log_title "------------------------------ FINISHED ---------------------------------";

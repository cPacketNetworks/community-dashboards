#!/bin/bash

# Script to import dashboard JSON files into a specified cClear
# Dashboards json files from running "dashboard_export.sh" will get imported to the specified folders.
# Dashboards saved from Grafana import will get imported to the "General" folder.
# Modified from Paul Sulistio's scripts.

OPTSPEC=":hu:p:t:i:"

###### Show help on how to use this script ######
show_help() {
cat << EOF
Usage: $0 [-u USER] [-p PASSWORD] [-t TARGET_HOST_IP] [-i IMPORT_PATH]
Script to import dashboards into Grafana
    -u      Required. cClear user to login
    -p      Required. cClear user password to login
    -t      Required. The IP of the destination cClear host i.e 10.51.10.32
    -i      Required. Full path to the folder or zip file containing JSON exports of the dashboards
            you want to be imported.
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
        i)
            IMPORT_PATH="$OPTARG";;
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
if [ -z "$USER" ] || [ -z "$PASSWORD" ] || [ -z "$IMPORT_PATH" ] || [ -z "$TARGET_HOST_IP" ]; then
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
   printf "[%s] $1\n" "$timestamp"
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
   printf "[%s] $1\n" "$timestamp"
   ${SETCOLOR_NORMAL}
}

function log_title() {
   if [ $# -lt 1 ]; then
       ${SETCOLOR_FAILURE}
       log_failure "Not enough arguments for log function! Expecting 1 argument got $#"
       exit 1
   fi

   ${SETCOLOR_TITLE_PURPLE}
   printf "|---------------------------------------------------------------------------------------|\n"
   printf "| %s |\n" "$1";
   printf "|---------------------------------------------------------------------------------------|\n"
   ${SETCOLOR_NORMAL}
}


ZIP_FILE=$(basename $IMPORT_PATH)

if [[ $ZIP_FILE =~ \.zip$ ]]; then
   DASH_DIR=$(unzip -qql $IMPORT_PATH | head -n1 | tr -s ' ' | cut -d' ' -f5-)
   unzip -o $IMPORT_PATH
   DIR_LENGTH=${#DASH_DIR}
   DASH_DIR=${DASH_DIR:0:DIR_LENGTH-1}
else
   DASH_DIR=$IMPORT_PATH
fi

if [ -d "$DASH_DIR" ]; then
   DASH_LIST=$(find "$PWD/$DASH_DIR" -mindepth 1 -name \*.json)

   if [ -z "$DASH_LIST" ]; then
       log_title "----------------- $DASH_DIR contains no JSON files! -----------------"
       log_failure "Directory $DASH_DIR does not appear to contain any JSON files for import. Check your path and try again."
       exit 1
   else
       FILESTOTAL=$(echo "$DASH_LIST" | wc -l)
       log_title "----------------- Starting import of $FILESTOTAL dashboards -----------------"
   fi
else
   log_title "-------------------- $DASH_DIR directory not found! -----------------"
   log_failure "Directory $DASH_DIR does not exist. Check your path and try again."
   exit 1
fi

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

NUMSUCCESS=0
NUMFAILURE=0
COUNTER=0
for DASH_FILE in $DASH_LIST; do
    COUNTER=$((COUNTER + 1))
    echo "Import $COUNTER/$FILESTOTAL: $DASH_FILE..."

    # Get folder uid and title from dashboard
    dashboard=$(cat "$DASH_FILE")
    folder_title=$(echo "$dashboard" | jq -r '.folderTitle')
    folder_uid=$(echo "$dashboard" | jq -r '.folderUid')
    dashboard=$(echo "$dashboard" | jq -r 'del(.folderTitle) | del(.folderUid)')
    # shellcheck disable=SC2116
    dashboard=$(echo '{"dashboard": ' "${dashboard}"'}')

   # If folder uid id not provided, import to the "General" folder
   if [ ${#folder_uid} -eq 0 ]; then
      RESULT=$(echo "$dashboard" | jq -r '. * {overwrite: true, dashboard: {id: null}}' | curl -k $CURL_COOKIE -X POST \
      -H "Content-Type: application/json" $HOST/graph-engine/api/dashboards/db -d @-)
   else
      # Find the folder id from $HOST with this folder uid
      folder_id=$(curl --noproxy '*' -k $CURL_COOKIE "$HOST"/graph-engine/api/folders/$folder_uid | jq -r '.id')
      # If not found, try finding it with folder title.
      if [ "$folder_id" == "null" ]; then
        folder_json=$(curl --noproxy '*' -k $CURL_COOKIE --request "GET" -H "Content-Type:application/json" \
        "$HOST/graph-engine/api/folders")
        folder_id=$(echo "$folder_json" | jq -r '.[] | select(.title == "'"$folder_title"'") | .id')
        folder_uid=$(echo "$folder_json" | jq -r '.[] | select(.title == "'"$folder_title"'") | .uid')
      fi
      # If still not found, create a folder with this folder uid and folder title.
      if [ "$folder_id" == "null" ] || [ ${#folder_id} -eq 0 ]; then
        echo " here"
         folder_new=$(echo '{"uid": "'$folder_uid'", "title": "'"$folder_title"'"}' | curl --noproxy '*' -k \
         $CURL_COOKIE -X POST -H "Content-Type: application/json" $HOST/graph-engine/api/folders -d @-)
         folder_id=$(echo $folder_new | jq -r '.id')
         folder_uid=$(echo $folder_new | jq -r '.uid')
      fi
      # Import dashboard with folder id, uid, and title
      RESULT=$(echo "$dashboard" | jq -r '. * {overwrite: true, dashboard: {id: null}} | . += {folderId:'$folder_id', folderUid:"'$folder_uid'", folderTitle: "'"$folder_title"'"}' \
      | curl --noproxy '*' -k $CURL_COOKIE -X POST -H "Content-Type: application/json" $HOST/graph-engine/api/dashboards/db -d @-)
   fi

   # log result
   if [[ "$RESULT" == *"success"* ]]; then
      log_success "$RESULT"
      NUMSUCCESS=$((NUMSUCCESS + 1))
   else
      log_failure "$RESULT"
      NUMFAILURE=$((NUMFAILURE + 1))
   fi
done

rm mycookie
rm -rf "$DASH_DIR"

log_title "Import complete. $NUMSUCCESS dashboards were successfully imported. $NUMFAILURE dashboard imports failed.";
log_title "-------------------------------------FINISHED----------------------------------------";

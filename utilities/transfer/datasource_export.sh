#!/bin/bash

# Script to export datasource from a specified cClear as JSON files.
# Modified from Paul Sulistio's scripts.

OPTSPEC=":hu:p:t:"

###### Show help on how to use this script ######
show_help() {
cat << EOF
Usage: $0 [-u USER] [-p PASSWORD] [-t TARGET_HOST_IP]
Script to export grafana datasources
    -u      Required. cClear user to login
    -p      Required. cClear user password to login
    -t      Required. The IP of the target host i.e 10.51.10.32
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
   DS_FOLDER="datasources"
   DS_DIR="$PWD/${DS_FOLDER}"
   echo $DS_DIR

   if [ ! -d "${DS_DIR}" ]; then
   	 mkdir -p "${DS_DIR}"
   else
   	 log_title "----------------- A $DS_DIR directory already exists! -----------------"
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

counter=0
init
datasource_json=$(curl --noproxy '*' -k $CURL_COOKIE "$HOST/graph-engine/api/datasources")
for id in $(echo $datasource_json | jq -r '.[] | .id'); do
    name=$(echo $datasource_json | jq -r '.[] | select(.id == '"$id"') | .name' | sed -r 's/[ \/]+/_/g' | \
    tr '[:upper:]' '[:lower:]')
    counter=$((counter + 1))
    curl --noproxy '*' -f -k $CURL_COOKIE "$HOST/graph-engine/api/datasources/${id}" | jq '' > "$DS_DIR/${name}.json"
    log_success "Datasource has been saved\t id=\"${id}\", name=\"${name}\", path=\"${DS_DIR}/${name}.json\"."
done

cclear_json=$(curl --noproxy '*' -k $CURL_COOKIE  "$HOST/api/admin/info")
CCLEAR_VERSION="cclear_$(echo $cclear_json | jq '.data.software.build' | tr -d '"')"
grafana_json=$(curl --noproxy '*' -k $CURL_COOKIE  "$HOST/graph-engine/api/health")
GRAFANA_VERSION="grafana_$(echo $grafana_json | jq '.version' | tr -d '"')"
DATE_TIME="date_$(date '+%d%m%Y_%H%M%S')"
DS_FILE_ZIP="${DS_FOLDER}_${TARGET_HOST_IP}_${CCLEAR_VERSION}_${GRAFANA_VERSION}_${DATE_TIME}"
zip -r -m "${DS_FILE_ZIP}.zip" "${DS_FOLDER}"
rm mycookie

log_title "${counter} datasource(s) were saved and zipped in "$PWD/${DS_FILE_ZIP}".zip";
log_title "------------------------------ FINISHED ---------------------------------";

#!/bin/bash

OPTSPEC=":hu:p:t:"

show_help() {
cat << EOF
Usage: $0 [-u USER] [-p PASSWORD] [-t TARGET_HOST]
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

mycookie="$PWD/mycookie"
counter=0

function init() {
   DS_DIR="$PWD/datasources"

   if [ ! -d "${DS_DIR}" ]; then
   	 mkdir "${DS_DIR}"
   else
   	log_title "----------------- A $DS_DIR directory already exists! -----------------"
   fi
}

init

# host url
if [[ ! "$HOST" == "https://"* ]]; then
  HOST="https://$HOST"
fi

curl --noproxy '*' -k -c mycookie --data "uname=$USER&psw=$PASSWORD" "$HOST/sess/login?rp=/vb/"
datasource_json=$(curl --noproxy '*' -k -b $mycookie "$HOST/graph-engine/api/datasources")
for id in $(echo $datasource_json | jq -r '.[] | .id'); do
    counter=$((counter + 1))
    curl --noproxy '*' -f -k -b  $mycookie "$HOST/graph-engine/api/datasources/${id}" | jq '' > "$DS_DIR/${id}.json"
    log_success "Datasource has been saved\t id=\"${id}\", path=\"${DS_DIR}/${id}.json\"."
done

zip -r -m datasources.zip datasources
rm mycookie

log_title "${counter} datasource(s) were saved and zipped in $PWD/datasources.zip";
log_title "------------------------------ FINISHED ---------------------------------";

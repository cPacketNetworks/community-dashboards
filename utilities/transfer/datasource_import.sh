#!/bin/bash

# Script to import datasource JSON files into a specified cClear
# Tests have been done on exported datasource json files from running "datasource_export.sh".
# Modified from Paul Sulistio's scripts.

OPTSPEC=":hu:p:t:i:"

###### Show help on how to use this script ######
show_help() {
cat << EOF
Usage: $0 [-u USER] [-p PASSWORD] [-t TARGET_HOST_IP] [-i IMPORT_PATH]
Script to import datasource into Grafana
    -u      Required. cClear user to login
    -p      Required. cClear user password to login
    -t      Required. The IP of the target host i.e 10.51.10.32
    -i      Required. Full path to the zip file containing JSON exports of the datasource you want to be imported.
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
   printf "|-----------------------------------------------------------------------------------------|\n"
   printf "| %s |\n" "$1";
   printf "|-----------------------------------------------------------------------------------------|\n"
   ${SETCOLOR_NORMAL}
}

ZIP_FILE=$(basename $IMPORT_PATH)
echo $ZIP_FILE

if [[ $ZIP_FILE =~ \.zip$ ]]; then
   DS_DIR=$(unzip -qql $IMPORT_PATH | head -n1 | tr -s ' ' | cut -d' ' -f5-)
   unzip -o $IMPORT_PATH
   DS_DIR=${DS_DIR: : -1}
   if [ -d "$DS_DIR" ]; then
       DS_LIST=$(find "$PWD/$DS_DIR" -mindepth 1 -name \*.json)
       echo $DS_LIST 
       if [ -z "$DS_LIST" ]; then
           log_title "----------------- $DS_DIR contains no JSON files! -----------------"
           log_failure "Directory $DS_DIR does not appear to contain any JSON files for import. Check your path and try again."
           exit 1
       else
           FILESTOTAL=$(echo "$DS_LIST" | wc -l)
           log_title "----------------- Starting import of $FILESTOTAL datasource(s) -----------------"
       fi
   else
       log_title "-------------------- $DS_DIR directory not found! -----------------"
       log_failure "Directory $DS_DIR does not exist. Check your path and try again."
       exit 1
   fi
else
   log_title "-------------------- $ZIP_FILE Wrong format! -----------------"
   log_failure "$ZIP_FILE is not a zip file. Please enter a correct file"
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
for i in datasources/*; do
    RESULT=$(curl --noproxy '*' -k $CURL_COOKIE -X "POST" "$HOST/graph-engine/api/datasources" \
    -H "Content-Type: application/json" --data-binary @$i)
    if [[ "$RESULT" == *"Datasource added"* ]]; then
        log_success "$RESULT"
        NUMSUCCESS=$((NUMSUCCESS + 1))
    else
        log_failure "$RESULT"
        NUMFAILURE=$((NUMFAILURE + 1))
    fi
done

rm mycookie

log_title "Import complete. $NUMSUCCESS datasource(s) successfully imported. $NUMFAILURE datasource(s) imports failed.";
log_title "---------------------------------------FINISHED----------------------------------------";

#!/bin/bash
#
# todo: ip to both ip and https; from folder to be both zipped or unzipped
#
OPTSPEC=":hu:p:z:t:"

show_help() {
cat << EOF
Usage: $0 [-u USER] [-p PASSWORD] [-z PATH] [-t TARGET_HOST] 
Script to import dashboards into Grafana
    -u      Required. cClear user to login
    -p      Required. cClear user password to login
    -z      Required. Grafana preferences json file to import from. e.g. preferences.json
    -t      Required. The IP of the destination cClear host i.e 10.51.10.32
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
        z)
            PREF_PATH="$OPTARG";;
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

if [ -z "$USER" ] || [ -z "$PASSWORD" ] || [ -z "$PREF_PATH" ] || [ -z "$HOST" ]; then
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

PREF_FILE=$(basename $PREF_PATH)

if [[ ! $PREF_FILE =~ \.json$ ]]; then
   log_title "-------------------- $PREF_FILE Wrong format! -----------------"
   log_failure "$PREF_PATH is not a json file. Please enter a correct file"
   exit 1
fi

if [[ ! -f "$PREF_FILE" ]]; then
  log_failure "No such file: $PREF_FILE."
  exit 1
fi

NUMSUCCESS=0
NUMFAILURE=0
COUNTER=0


# host url
if [[ ! "$HOST" == "https://"* ]]; then
  HOST="https://$HOST"
fi

mycookie="$PWD/mycookie"
curl --noproxy '*' -k -c mycookie --data "uname=$USER&psw=$PASSWORD" $HOST/sess/login?rp=/vb/

RESULT=$(cat "$PREF_FILE" | jq '.' | curl --noproxy '*' -k -b $mycookie -X PUT -H \
"Content-Type: application/json" "$HOST/graph-engine/api/user/preferences" -d @-)

rm mycookie

# log result
if [[ "$RESULT" == *"updated"* ]]; then
  log_success "$RESULT"
else
  log_failure "$RESULT"
fi

log_title "-------------------- Preferences were successfully imported.-------------------------"

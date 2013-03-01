#!/bin/bash

# I took this function from
# https://github.com/dominictarr/JSON.sh
# while I was looking for a way to fix some strange char problems in the
# Graphite's CSV output
# Thanks Dominic
function tokenize () {
  local ESCAPE='(\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
  local CHAR='[^[:cntrl:]"\\]'
  local STRING="\"$CHAR*($ESCAPE$CHAR*)*\""
  local NUMBER='-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?'
  local KEYWORD='null|false|true'
  local SPACE='[[:space:]]+'
  egrep -ao "$STRING|$NUMBER|$KEYWORD|$SPACE|." --color=never |
    egrep -v "^$SPACE$"  # eat whitespace
}

function printArray { 
    echo ${VALUES[*]}; 
}

function sortValues { 
    VALUES=( $(for i in ${VALUES[@]}; do echo "$i"; done | sort -n) )
}

function avgValue { 
    echo "${VALUES[@]}" | awk '{ for (v=1; v<=NF; v++) total+=$v; } END { printf("%.1f\n", total/NF); }'   
}

function maxValue { 
    sortValues
    echo "${VALUES[${#VALUES[*]}-1]}"
}

function minValue {
    sortValues
    echo "${VALUES[0]}"   
}

function lastValue {
    echo "${VALUES[${#VALUES[*]}-1]}"
}

function parseGraphite {
    i=0
    while read LINE
    do 
        VALUE=$(echo "${LINE}"|awk -F, '{print $3 }'|tokenize)
        [ -n "${VALUE}" ] && { VALUES[${i}]="${VALUE}"; (( i++ )); }
    done < <(curl "${G_URL}" 2>/dev/null)
}

function printHelp() {

cat >&2 <<EOF
$@

    --warning|-w                        Warning threshold (in MBs)
    --critical|-c                       Critical threshold (in MBs)
    --graphite|-g                       Graphite server base URL (eg. http://graphite.local/)
    --metric|-m                         Set the Graphite metric name to check
    --tag|-t [tag name]                 Set an optional tag value for the metric. Used in the nagios output (default: "Value")
    --start-time|-s                     Set the series start time (default: now minus 15 min). Accepts "GNU date" format
    --end-time|-e                       Set the series end time (default: now). Accepts "GNU date" format
    --calc-mode|-c [last|avg|max|min]   Specify how to calculate the number that will be checked against thresholds (default: last)
EOF

exit 2

}

# main starts here
declare -a VALUES
STIME="now - 15 min"
ETIME="now"
CMODE="last"
TAG="Value"

while [ $# -gt 0 ]  
do
    case "$1" in
        --warning|-w)     WARNING="$2";       shift 2;;
        --critical|-c)    CRITICAL="$2";      shift 2;;
        --graphite|-g)    BASE_GRAPHITE="$2"; shift 2;;
        --metric|-m)      METRIC_NAME="$2";   shift 2;;
        --tag|-t)         TAG="$2";           shift 2;;
        --start-time|-s)  STIME="$2";         shift 2;;
        --end-time|-e)    ETIME="$2";         shift 2;;
        --calc-mode|-a)   CMODE="$2";         shift 2;;
        *)                printHelp           "Missing parameter" ;;
    esac        
done

FROM=$(date -d "${STIME}" "+%H%%3A%M_%Y%m%d") || printHelp "Invalid start time"
UNTIL=$(date -d "${ETIME}" "+%H%%3A%M_%Y%m%d") || printHelp "Invalid end time"
ADDITIONAL_PARAMS="format=csv&from=${FROM}&until=${UNTIL}"


if [ -z "${WARNING}" ];
then
    printHelp "Please specify a warning threshold"
fi

if [ -z "${CRITICAL}" ];
then
    printHelp "Please specify a critical threshold"
fi

if [ -z "${BASE_GRAPHITE}" ];
then
    printHelp "Please specify a Graphite server base URL (eg. http://graphite.local/)"
fi

if [ -z "${METRIC_NAME}" ];
then
    printHelp "Please specify a Graphite metric name to check"
fi

G_URL="${BASE_GRAPHITE}/render/?target=${METRIC_NAME}&${ADDITIONAL_PARAMS}"

parseGraphite

case "${CMODE}" in    
    last)
        MY_VALUE=$(lastValue)
        ;;
    avg)
        MY_VALUE=$(avgValue)
        ;;
    max)
        MY_VALUE=$(maxValue)
        ;;
    min)
        MY_VALUE=$(minValue)
        ;;
    *)
        printHelp "Unknown calc mode ${CMODE}"
        ;;
esac

if (( $(bc <<< "${MY_VALUE} >= ${CRITICAL}") > 0 ))
then
    echo "CRITICAL|${TAG}=${MY_VALUE}"
    exit 1
else
    if (( $(bc <<< "${MY_VALUE} >= ${WARNING}") > 0 ))
    then
        echo "WARNING|${TAG}=${MY_VALUE}"
        exit 2
    fi
    echo "OK|${TAG}=${MY_VALUE}"
    exit 0
fi
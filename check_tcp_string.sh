#!/bin/bash

function printHelp() {

cat >&2 <<EOF
$@

Usage: $(basename $0)
		--host|-h                       Remote host to connect to  (default: 127.0.0.1)       
		--port|-p                       Remote TCP port to connect to      			
		--send-text|-s                  Send this text to the remote host
		--look-for|-l                   Look for this answer from the remote host
		--alarm|-a (warning|critical)   If look-for text is not found, return this alarm level (default: warning)
EOF
    
exit 3

}

# main starts here

test -x $(which nc) || { echo "Cannot find nc. Aborting."; exit 3; }

ALARM="warning"
HOST="127.0.0.1"

while [ $# -gt 0 ]
do
    case "$1" in
        --host|-h)        HOST="${2}";      shift 2;;
        --port|-p)        PORT="$2";        shift 2;;
        --send-text|-s)   SEND_TEXT="$2";   shift 2;;
        --look-for|-l)    ANSWER_TEXT="$2"; shift 2;;
        --alarm|-a)       ALARM="${2}";     shift 2;;
        *)                printHelp "Missing parameter" ;;
    esac
done

[[ ${ALARM} == 'critical' ]] && EXIT_STATUS=2
[[ ${ALARM} == 'warning' ]]  && EXIT_STATUS=1

if [ -z "${PORT}" ];
then
    printHelp "Please specify a TCP port"
fi

if [ -z "${SEND_TEXT}" ];
then
    printHelp "Please specify the text you want to send"
fi

if [ -z "${ANSWER_TEXT}" ];
then
    printHelp "Please specify the answer string you are looking for"
fi

echo "${SEND_TEXT}"|nc ${HOST} ${PORT} -q 1 -w 1 | grep -q  "${ANSWER_TEXT}" 2>/dev/null && \
   { echo "OK: asked '${SEND_TEXT}', found '${ANSWER_TEXT}'"; exit 0; } || \
   { echo "${ALARM^^}: asked '${SEND_TEXT}', didn't find '${ANSWER_TEXT}'"; exit ${EXIT_STATUS}; }

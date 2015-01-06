#!/bin/bash


function printHelp() {

cat >&2 <<EOF
$@
    --warning|-w        Warning threshold (in MBs)
    --critical|-c       Critical threshold (in MBs)
    --zk-connect|-z     Zookeper connection string
    --group|-g          Set Kafka group to monitor
    --topic|-t          Set Kafka topic to monitor    
EOF

exit 2

}

# main starts here
while [ $# -gt 0 ]  
do
    case "$1" in
        --warning|-w)     WARNING="$2";     shift 2;;
        --critical|-c)    CRITICAL="$2";        shift 2;;
        --zk-connect|-z)  ZK="$2";    shift 2;;
        --group|-g)       GROUP="$2";    shift 2;;
        --topic|-t)       TOPIC="$2";     shift 2;;
        *)                printHelp "Missing parameter" ;;
    esac        
done

if [ -z "${WARNING}" ];
then
    printHelp "Please specify a warning threshold"
fi

if [ -z "${CRITICAL}" ];
then
    printHelp "Please specify a critical threshold"
fi

if [ -z "${ZK}" ];
then
    printHelp "Please specify a Zookeper connect string"
fi

if [ -z "${GROUP}" ];
then
    printHelp "Please specify a Kafka group"
fi

if [ -z "${TOPIC}" ];
then
    printHelp "Please specify a Kafka topic"
fi

LAG=$(/opt/kafka/kafka_install/bin/kafka-run-class.sh kafka.tools.ConsumerOffsetChecker --group "${GROUP}" --zkconnect "${ZK}" --topic "${TOPIC}" |grep $TOPIC |awk -F' ' '{ SUM += $6 } END { printf "%d", SUM/1024/1024 }')

if (( LAG >= ${CRITICAL} ))
then
    echo "CRITICAL|Lag=${LAG}MB"
    exit 2
else
    if (( LAG >= ${WARNING} ))
    then
        echo "WARNING|Lag=${LAG}MB"
        exit 1
    fi
    echo "OK|Lag=${LAG}MB"
    exit 0
fi

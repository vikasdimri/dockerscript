#!/bin/bash

listTheTopic() {
  docker exec -ti kafka /opt/kafka/bin/kafka-topics.sh --list --zookeeper zookeeper:2181
}

createTopic() {
  name=$1
  docker exec -ti kafka /opt/kafka/bin/kafka-topics.sh --create --zookeeper zookeeper:2181 --replication-factor 1 --partitions 1 --topic $name
}

describe() {
  docker exec -ti kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --all-groups --describe
}

getMessageFromTopic() {
  docker exec -ti kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic $1 --from-beginning
}

publishMessageToTopic() {
  docker exec -ti kafka /opt/kafka/bin/kafka-console-producer.sh --topic $1 --broker-list localhost:9092
}

displayHelp() {
  echo
    echo "*********************************************************************************************"
    echo "*   Usage: $0 [option...] {publish|get message|create|list topic|describe}" >&2                   "*"
    echo "*   -p   Publish message in given topic.             e.g. ./kafka-services.sh -p topic_name *"
    echo "*   -m   Get the message from given topic.           e.g. ./kafka-services.sh -m topic_name *"
    echo "*   -c   Create new topic.                           e.g. ./kafka-services.sh -c topic_name *"
    echo "*   -l   List the all topic.                         e.g. ./kafka-services.sh -l            *"
    echo "*   -d   Describe all topic offset and partitions.   e.g. ./kafka-services.sh -d            *"
    echo "*********************************************************************************************"
    echo
  }
while getopts ":p:m:c:ldh" opt; do
  case "${opt}" in
  c)
    action="create_topic"
    topic_name=$OPTARG
    ;;
  l) action="topic_list" ;;
  h) action="help" ;;
  d) action="describe" ;;
  m)
    action="get_message"
    topic_name=$OPTARG
    ;;
  p)
    action="publish_message"
    topic_name=$OPTARG
    ;;
  \?) echo "Invalid option: $OPTARG" 1>&2 ;;
  esac
done

if [[ "$action" == "topic_list" ]]; then
  listTheTopic
elif [[ "$action" == "create_topic" ]]; then
  createTopic "$topic_name"
elif [[ "$action" == "get_message" ]]; then
  getMessageFromTopic "$topic_name"
elif [[ "$action" == "publish_message" ]]; then
  publishMessageToTopic "$topic_name"
elif [[ "$action" == "describe" ]]; then
  describe
elif [[ "$action" == "help" ]]; then
  displayHelp
else
  displayHelp
fi

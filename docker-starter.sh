#!/bin/bash

repeat(){
	local start=1
	local end=$2
	local str=$3
	if [[ "$3" == 1 ]]; then
	  str="═"
	elif [ "$3" == 2 ]; then
	    str=" "
	fi
	local range=$(seq $start $end)
	for i in $range ; do printf "${str}"; done
#	echo
}
printBanner(){
  local firstArg=$1
  local secondArg=$2

  if [[ "$firstArg" != "" && "$secondArg" != "" ]]; then
    printf "╔"
    repeat 1 60 1
    echo "╗"
    whitespace=$(expr 55 - ${#firstArg})
    printf "╠"
    repeat 1 5 2
    printf "${firstArg}"
    repeat 1 $whitespace 2
    printf "╣"
    arr=($secondArg)
    for i in "${arr[@]}"
    do
      echo
      name="${i}"
      printf "╠"
      repeat 1 10 2
      printf "${name}"
      whitespace=$(expr 60 - ${#name})
      whitespace=$((whitespace-10))
      repeat 1 $whitespace 2
      printf "╣"
    done
    echo
    printf "╚"
    repeat 1 60 1
    echo "╝"
  elif [[ "$firstArg" != "" ]]; then
    printf "╔"
    repeat 1 60 1
    echo "╗"
    whitespace=$(expr 54 - ${#firstArg})
    printf "╠"
    repeat 1 5 2
    printf "${firstArg}"
    repeat 1 $whitespace 2
    printf ' %.0s' {1..$whitespace}
    printf "╣"
    echo
    printf "╚"
    printf '═%.0s' {1..60}
    echo "╝"
    elif [[ "$firstArg" != "" ]]; then
    printf "╔"
    printf '═%.0s' {1..60}
    echo "╗"
  fi
}

getActionAndContainer() {
  while getopts ":c:o:" opt; do
    case $opt in
    o) starts=$OPTARG ;;
    c) stops=$OPTARG ;;
    \?) echo "Invalid option: $OPTARG" 1>&2 ;;
    esac
  done
}

createDatabase() {
  docker-compose -f sqlserver-compose.yml up -d
  ip_sql=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' sqlserver)
  sleep 30
  docker exec -it mssql-tools bash -c "/opt/mssql-tools/bin/sqlcmd -S $ip_sql -U SA -P 'yourStrong(!)Password' -d master -Q 'CREATE DATABASE test'"
  docker stop mssql-tools
}

startDockerContainer() {
  printBanner "starting....." $1
  if [[ "$1" == "all" ]]; then
    docker run -d --rm --name redis -p 6379:6379 redis
    docker run -d --rm --name axonserver -p 8024:8024 -p 8124:8124 axoniq/axonserver:4.5.16-jdk-17-dev
    docker-compose -f sqlserver-compose.yml rm -fsv
    docker-compose -f kafka-compose.yml up -d
    createDatabase
  else
    case "$1" in
    "redis")
      docker run -d --rm --name redis -p 6379:6379 redis
      ;;
    "sqlserver")
      docker-compose -f sqlserver-compose.yml rm -fsv
      createDatabase
      ;;
    "axonserver")
      docker run -d --rm --name axonserver -p 8024:8024 -p 8124:8124 axoniq/axonserver:4.5.16-jdk-17-dev
      ;;
    "kafka")
      docker-compose -f kafka-compose.yml up -d
      ;;
    esac
  fi
}

stopDockerContainer() {
  if [[ "$1" == "all" ]]; then
    printBanner "stopping....." $1
    container_running=$(docker ps -a -q)
    if [[ "${container_running}" != "" ]]; then
      docker stop $(docker ps -a -q)
      docker-compose -f sqlserver-compose.yml rm -fsv
      docker-compose -f kafka-compose.yml rm -fsv
    else
      echo "No container is running."
    fi
  else
    printBanner "stopping....." $1
    container_running=$(docker ps -f "name=$1" -a -q)
    if [[ "${container_running}" != "" ]]; then
      if [[ "${1}" == "sqlserver" ]]; then
        docker-compose -f sqlserver-compose.yml rm -fsv
      elif [[ "${1}" == "kafka" ]]; then
        docker-compose -f kafka-compose.yml rm -fsv
      else
        echo "Stopping $1 container."
        docker stop $(docker ps -f "name=$1" -a -q)
        echo "$1 container stopped."
      fi
    else
      echo "No container is running for $1 image."
    fi
  fi
}

spinGivenContainer() {
  starts=(${1})
  stops=(${2})
  if [[ "${starts}" != "" ]]; then
    for index in "${!starts[@]}"
    do
        start="${starts[$index]}"
        if [[ "${start}" != "" ]]; then
          stopDockerContainer $start
          startDockerContainer $start
          echo ""
        fi
    done
  fi
  if [[ "${stops}" != "" ]]; then
    for index in "${!stops[@]}"
        do
            stop="${stops[$index]}"
            if [[ "${stop}" != "" ]]; then
              stopDockerContainer $stop
            fi
        done
  fi
}
printBanner "#################### Start ####################"
if [[ "${@}" == "" ]]; then
  echo "No option selected, restart all containers"
  stopDockerContainer all
  startDockerContainer all
elif [[ "${@}" == "all" ]]; then
  echo "All selected, restart all containers"
  stopDockerContainer all
  startDockerContainer all
else
  getActionAndContainer "$@"
  if [[ "${starts}" == "" && "${stops}" == "" ]]; then
    echo "Provide the containers names."
  else
    if [[ "${starts}" != "" ]]; then
      printBanner "Requested container to start/restart" "${starts}"
    fi
    if [[ "${stops}" != "" ]]; then
      printBanner "Requested container to stop" "${stops}"
    fi
    spinGivenContainer "${starts}" "${stops}"
  fi
fi
printBanner "Currently running containers"
docker ps
printBanner "#################### End ####################"
#!/usr/bin/env bash

# Pass a docker container, and then:
# -rc --runcommand | Print out a run command generated for that docker

function DOCKER_PORTS() {
  #Given a docker container, get port mappings:
  PORT_MAPPINGS=""
  #Get list of mapped ports first
  PORTS=$( echo $DOCKER_INSPECT | jq -r '.[].NetworkSettings.Ports | keys | .[]' 2>/dev/null )
  #Iterate through array and rebuild mappings:
  for i in ${PORTS[@]}; do
    #Get mapping (if any)
    NETWORK_CONFIG=$( echo $DOCKER_INSPECT | jq -r ".[].NetworkSettings.Ports.\""$i"\"[0]")
    HOST_PORT=$( echo $NETWORK_CONFIG | jq -r ".HostPort" )
    HOST_IP=$( echo $NETWORK_CONFIG | jq -r ".HostIp" )
    if [ $HOST_IP == "0.0.0.0" ]; then
      HOST_IP=""
    fi
    #A null string is returned back if the port was never mapped to the host.
    if [ ! $HOST_PORT == "null" ]; then
      PORT_MAPPINGS="$PORT_MAPPINGS -p $HOST_PORT:$i"
    fi
  done
  PORT_MAPPINGS=$( echo "${PORT_MAPPINGS}" | xargs )
}

function DOCKER_VOLUMES() {
  #Given a docker container, get the volume mappings made:
  VOLUME_MAPPINGS=""
  VOLUMES=$( echo $DOCKER_INSPECT | jq -r '.[].HostConfig.Binds | .[]' 2>/dev/null)
  for i in ${VOLUMES[@]}; do
    VOLUME_MAPPINGS="$VOLUME_MAPPINGS -v $i"
  done
  VOLUME_MAPPINGS=$( echo $VOLUME_MAPPINGS | xargs )
}

function DOCKER_COMMAND() {
  #Given a docker container, get any user-specified command strings specified after the remote image name:
  COMMANDS=""
  DOCKER_COMMANDS=$( echo $DOCKER_INSPECT | jq -r '.[].Config.Cmd | .[]' 2>/dev/null)
    for i in ${DOCKER_COMMANDS[@]}; do
      COMMANDS="$COMMANDS $i"
    done
  COMMANDS=$( echo $COMMANDS | xargs )
}

function DOCKER_RESTART_POLICY() {
  DOCKER_RESTART_POLICY=$( echo $DOCKER_INSPECT | jq -r '.[].HostConfig.RestartPolicy')
  DOCKER_RESTART_POLICY_NAME=$( echo $DOCKER_RESTART_POLICY | jq -r '.Name')
  if [ $DOCKER_RESTART_POLICY_NAME == "on-failure" ]; then
    DOCKER_RESTART_POLICY_RETRIES=$(echo $DOCKER_RESTART_POLICY | jq -r '.MaximumRetryCount')
    RESTART_POLICY="--restart $DOCKER_RESTART_POLICY_NAME:$DOCKER_RESTART_POLICY_RETRIES"
  else
    RESTART_POLICY="--restart ${DOCKER_RESTART_POLICY_NAME}${DOCKER_RESTART_POLICY_RETRIES}"
  fi
}

function DOCKER_NETWORKING() {
  DOCKER_NETWORK_CONFIG=$( echo $DOCKER_INSPECT | jq -r '.[].NetworkSettings.Networks')
  DOCKER_NETWORK_TYPE=$( echo $DOCKER_NETWORK_CONFIG | jq -r '. | keys | .[]')
  if [ "$DOCKER_NETWORK_TYPE" == "bridge" ]; then
    NETWORK=""
  else
    NETWORK="--network=$DOCKER_NETWORK_TYPE"
  fi
}

function DOCKER_ENV() {
  ENVS=""
  DOCKER_ENVS=$( echo $DOCKER_INSPECT | jq -r '.[].Config.Env | .[]' 2>/dev/null)
    for i in ${DOCKER_ENVS[@]}; do
      if [ ! $( echo $i | cut -d '=' -f 1) == "PATH" ]; then
        ENVS="$ENVS --env $i"
      fi
    done
}

function CHECK_JQ() {
  if [ -z $(jq --version) 2>/dev/null ]; then
    echo "jq is not installed."
    exit 1
  fi
}

DOCKER_IMAGE=$1
if [ -z $1 ]; then
  echo "Must supply a docker container name!"
  exit 1
fi
shift

# See if docker is installed and running locally.
DOCKER_SYS_CHECK=$( docker --version ) 2>/dev/null
if [ -z "$DOCKER_SYS_CHECK" ]; then
  echo "I don't think docker is installed on your system."
  exit 1
fi

# Check the docker container exists
DOCKER_CONTAINER_CHECK=$( docker ps -a | grep "$DOCKER_IMAGE" )
if [ -z "$DOCKER_CONTAINER_CHECK" ]; then
  echo "No container with name \"${DOCKER_IMAGE}\" exists."
  exit 1
fi

CHECK_JQ

#As an example, minio has this run command: docker run -p 9010:9000 -d --name miniOS -v ~/minio/data:/data minio/minio server /data
DOCKER_INSPECT=$(docker inspect $DOCKER_IMAGE)
DOCKER_NAME=$( echo $DOCKER_INSPECT | jq -r .[].Name | cut -d '/' -f 2 )
IMAGE_NAME=$( echo $DOCKER_INSPECT | jq -r .[].Config.Image )
DOCKER_PORTS
DOCKER_VOLUMES
DOCKER_COMMAND
DOCKER_NETWORKING
DOCKER_ENV
if [ -z $1 ]; then
  echo "docker run --name ${DOCKER_NAME} ${NETWORK} ${PORT_MAPPINGS} ${VOLUME_MAPPINGS} ${IMAGE_NAME}" | xargs
elif [ $1 == "-v" ]; then
  echo "*****"
  echo "-v produces additional output which may contain defaults or sensitive data"
  echo "*****"
  echo "docker run --name ${DOCKER_NAME} ${NETWORK} ${PORT_MAPPINGS} ${ENVS} ${VOLUME_MAPPINGS} ${IMAGE_NAME} ${COMMANDS}" | xargs
fi

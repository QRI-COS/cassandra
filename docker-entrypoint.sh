#!/bin/bash
set -e

# First arg is `-f` or `--some-option`
if [ "${1:0:1}" = '-' ]; then
  set -- ${CASSANDRA_USER} -f "$@"
fi

# Allow the container to be started with `--user`
if [ "$1" = 'cassandra' -a "$(id -u)" = '0' ]; then
  mkdir -p ${CASSANDRA_DATA} ${CASSANDRA_LOG} ${CASSANDRA_DATA} ${CASSANDRA_PERSIST_DIR} ${CASSANDRA_COMMITLOG}
  chown -R ${CASSANDRA_USER} ${CASSANDRA_DATA} ${CASSANDRA_CONFIG} ${CASSANDRA_LOG} ${CASSANDRA_PERSIST_DIR}
  exec gosu ${CASSANDRA_USER} "$BASH_SOURCE" "$@"
fi

if [ "$1" = 'cassandra' ]; then
  : ${CASSANDRA_RPC_ADDRESS='0.0.0.0'}

  : ${CASSANDRA_LISTEN_ADDRESS='auto'}
  if [ "$CASSANDRA_LISTEN_ADDRESS" = 'auto' ]; then
    CASSANDRA_LISTEN_ADDRESS="$(hostname -i)"
  fi

  : ${CASSANDRA_BROADCAST_ADDRESS="$CASSANDRA_LISTEN_ADDRESS"}

  if [ "$CASSANDRA_BROADCAST_ADDRESS" = 'auto' ]; then
    CASSANDRA_BROADCAST_ADDRESS="$(hostname -i)"
  fi
  : ${CASSANDRA_BROADCAST_RPC_ADDRESS:=$CASSANDRA_BROADCAST_ADDRESS}

  if [ -n "${CASSANDRA_NAME:+1}" ]; then
    : ${CASSANDRA_SEEDS:="cassandra"}
  fi
  : ${CASSANDRA_SEEDS:="$CASSANDRA_BROADCAST_ADDRESS"}

  sed -ri 's/(- seeds:).*/\1 "'"$CASSANDRA_SEEDS"'"/' "$CASSANDRA_CONFIG/cassandra.yaml"

  for yaml in \
    broadcast_address \
    broadcast_rpc_address \
    cluster_name \
    endpoint_snitch \
    listen_address \
    num_tokens \
    rpc_address \
    start_rpc \
  ; do
    var="CASSANDRA_${yaml^^}"
    val="${!var}"
    if [ "$val" ]; then
      sed -ri 's/^(# )?('"$yaml"':).*/\2 '"$val"'/' "$CASSANDRA_CONFIG/cassandra.yaml"
    fi
  done

  for rackdc in dc rack; do
    var="CASSANDRA_${rackdc^^}"
    val="${!var}"
    if [ "$val" ]; then
      sed -ri 's/^('"$rackdc"'=).*/\1 '"$val"'/' "$CASSANDRA_CONFIG/cassandra-rackdc.properties"
    fi
  done
fi

exec "$@"
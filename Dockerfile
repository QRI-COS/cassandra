FROM alpine:latest

#SETUP ENV VARS
ENV CASSANDRA_VERSION=3.11.11 \
    CASSANDRA_HOME=/opt/cassandra \
    CASSANDRA_CONFIG=/etc/cassandra \
    CASSANDRA_PERSIST_DIR=/var/lib/cassandra \
    CASSANDRA_DATA=/var/lib/cassandra/data \
    CASSANDRA_COMMITLOG=/var/lib/cassandra/commitlog \
    CASSANDRA_LOG=/var/log/cassandra \
    CASSANDRA_USER=cassandra

#PREPARE DIRECTORIES
RUN mkdir -p ${CASSANDRA_DATA} \
             ${CASSANDRA_CONFIG} \
             ${CASSANDRA_LOG} \
             ${CASSANDRA_COMMITLOG}

#ADD APK PACKAGES             
RUN apk --no-cache --upgrade add curl ca-certificates tar openjdk8

#INSTALL CASSANDRA
RUN curl -s -o /tmp/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz https://apache.claz.org/cassandra/3.11.11/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz && \
  tar -xzf /tmp/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz -C /tmp/ && \
  mv /tmp/apache-cassandra-${CASSANDRA_VERSION} ${CASSANDRA_HOME} && \
  rm -r /tmp/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz 

##CLEANUP
RUN apk --purge del curl ca-certificates tar 

# Setup entrypoint and bash to execute it
COPY ./docker-entrypoint.sh /docker-entrypoint.sh
RUN apk add --update --no-cache bash && \
    chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/bin/bash", "/docker-entrypoint.sh"]

# Add default config
RUN mv ${CASSANDRA_HOME}/conf/* ${CASSANDRA_CONFIG}
COPY ./conf/* ${CASSANDRA_CONFIG}/
RUN chmod +x ${CASSANDRA_CONFIG}/*.sh

# https://issues.apache.org/jira/browse/CASSANDRA-11661
RUN sed -ri 's/^(JVM_PATCH_VERSION)=.*/\1=25/' /etc/cassandra/cassandra-env.sh

# Add cassandra bin to PATH
ENV PATH=$PATH:${CASSANDRA_HOME}/bin \
    CASSANDRA_CONF=${CASSANDRA_CONFIG}

# Change directories ownership and access rights
RUN adduser -D -s /bin/sh ${CASSANDRA_USER} && \
    chown -R ${CASSANDRA_USER}:${CASSANDRA_USER} \
      ${CASSANDRA_HOME} \
      ${CASSANDRA_PERSIST_DIR} \
      ${CASSANDRA_DATA} \
      ${CASSANDRA_CONFIG} \
      ${CASSANDRA_LOG} \
      ${CASSANDRA_COMMITLOG} && \
    chmod 777 ${CASSANDRA_HOME} \
      ${CASSANDRA_PERSIST_DIR} \
      ${CASSANDRA_DATA} \
      ${CASSANDRA_CONFIG} \
      ${CASSANDRA_LOG} \
      ${CASSANDRA_COMMITLOG}

USER ${CASSANDRA_USER}
WORKDIR ${CASSANDRA_HOME}

# Expose data volume
VOLUME ${CASSANDRA_PERSIST_DIR}

# 7000: intra-node communication
# 7001: TLS intra-node communication
# 7199: JMX
# 9042: CQL
# 9160: thrift service
EXPOSE 7000 7001 7199 9042 9160

CMD ["cassandra", "-f"]
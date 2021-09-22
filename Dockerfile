FROM azul/zulu-openjdk:11

ARG APACHEDS_VERSION=${APACHEDS_VERSION:-2.0.0.AM26}

ENV APACHEDS_ACCESS_CONTROL_ENABLED=1 \
    APACHEDS_ADMIN_PASSWORD=secret \
    APACHEDS_DOMAIN_NAME=example \
    APACHEDS_DOMAIN_SUFFIX=com \
    APACHEDS_INSTANCE_NAME=default \
    APACHEDS_VERSION=${APACHEDS_VERSION} \
    DEBIAN_FRONTEND=noninteractive

ADD KEYS /tmp/KEYS

RUN set -x \
    && apt-get update -qq \
    && apt-get install -qq -y --no-install-recommends \
      ca-certificates \
      curl \
      dumb-init \
      gettext-base \
      gnupg \
      ldap-utils \
      netcat \
      procps \
      wget \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sL -o /tmp/apacheds.deb https://archive.apache.org/dist/directory/apacheds/dist/${APACHEDS_VERSION}/apacheds-${APACHEDS_VERSION}-amd64.deb \
    && curl -sL -o /tmp/apacheds.deb.asc https://archive.apache.org/dist/directory/apacheds/dist/${APACHEDS_VERSION}/apacheds-${APACHEDS_VERSION}-amd64.deb.asc \
    && gpg --no-tty --import /tmp/KEYS \
    && cat /tmp/apacheds.deb.asc \
    && gpg --no-tty --verify --trust-model always /tmp/apacheds.deb.asc /tmp/apacheds.deb \
    && dpkg -i /tmp/apacheds.deb \
    && rm \
      /tmp/apacheds.deb \
      /tmp/apacheds.deb.asc \
      /tmp/KEYS \
    && ln -s /opt/apacheds-${APACHEDS_VERSION}/bin/apacheds /usr/local/bin/ \
    && mv /var/lib/apacheds-${APACHEDS_VERSION} /var/lib/apacheds \
    && sed -ie 's/^INSTANCES_DIRECTORY=.*/INSTANCES_DIRECTORY="\/var\/lib\/apacheds"/g' /opt/apacheds-${APACHEDS_VERSION}/bin/apacheds \
    && sed -ie "s/^# wrapper.java.command=.*/wrapper.java.command=$(which java)/g" /opt/apacheds-${APACHEDS_VERSION}/conf/wrapper.conf \
    && apt-get purge -y --auto-remove gnupg wget \
    && rm -rf /var/lib/apt/lists/* \
    && cp -a /var/lib/apacheds /var/lib/apacheds.tmpl

COPY ldif/ /ldif/
COPY templates/ /templates/
COPY entrypoint.sh /usr/local/bin/

EXPOSE 10389 10636
VOLUME ["/var/lib/apacheds"]

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]

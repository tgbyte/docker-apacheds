FROM openjdk:8-jre

ENV APACHEDS_ACCESS_CONTROL_ENABLED=1 \
    APACHEDS_ADMIN_PASSWORD=secret \
    APACHEDS_DOMAIN_NAME=example \
    APACHEDS_DOMAIN_SUFFIX=com \
    APACHEDS_INSTANCE_NAME=default \
    APACHEDS_VERSION=2.0.0-M24-SNAPSHOT \
    DUMBINIT_VERSION=1.2.0 \
    DUMBINIT_SHA256SUM=81231da1cd074fdc81af62789fead8641ef3f24b6b07366a1c34e5b059faf363 \
    DEBIAN_FRONTEND=noninteractive

COPY directory-server/installers/target/installers/apacheds-2.0.0-M24-SNAPSHOT-amd64.deb /tmp/

RUN set -x \
    && apt-get update -qq && apt-get install -qq -y --no-install-recommends ca-certificates gettext-base ldap-utils netcat wget && rm -rf /var/lib/apt/lists/* \
    && wget -q -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMBINIT_VERSION}/dumb-init_${DUMBINIT_VERSION}_amd64 \
    && echo "${DUMBINIT_SHA256SUM}  /usr/local/bin/dumb-init" > /tmp/SHA256SUM \
    && sha256sum -c /tmp/SHA256SUM \
    && rm /tmp/SHA256SUM \
    && chmod +x /usr/local/bin/dumb-init \
    && dpkg -i /tmp/apacheds-${APACHEDS_VERSION}-amd64.deb \
    && ln -s /opt/apacheds-${APACHEDS_VERSION}/bin/apacheds /usr/local/bin/ \
    && mv /var/lib/apacheds-${APACHEDS_VERSION} /var/lib/apacheds \
    && sed -ie 's/^INSTANCES_DIRECTORY=.*/INSTANCES_DIRECTORY="\/var\/lib\/apacheds"/g' /opt/apacheds-${APACHEDS_VERSION}/bin/apacheds \
    && apt-get purge -y --auto-remove wget

COPY ldif/ /ldif/
COPY templates/ /templates/
COPY entrypoint.sh /usr/local/bin/

EXPOSE 10389 10636 60088 60464 8080 8443
VOLUME ["/var/lib/apacheds"]

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]

#!/bin/bash

/usr/local/bin/apacheds start ${APACHEDS_INSTANCE_NAME}
while ! nc -z localhost 10389; do
  echo "Waiting for ApacheDS to come online..."
  sleep 0.1
done
sleep 1

if [ "${APACHEDS_ADMIN_PASSWORD}" != "secret" ] && [ ! -e "/var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.password-set" ]; then
  echo "*** Setting admin password..."

  envsubst < "/templates/admin_password.ldif" > "/tmp/admin_password.ldif"
  ldapmodify -c -a -f /tmp/admin_password.ldif -h localhost -p 10389 -D "uid=admin,ou=system" -w secret
  touch /var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.password-set
fi

if [ -n "${APACHEDS_ACCESS_CONTROL_ENABLED}" ] && [ ! -e "/var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.access" ]; then
  echo "*** Enabling access control..."

  ldapmodify -c -a -f /ldif/access.ldif -h localhost -p 10389 -D "uid=admin,ou=system" -w ${APACHEDS_ADMIN_PASSWORD}
  touch /var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.access
  /usr/local/bin/apacheds stop ${APACHEDS_INSTANCE_NAME}
  /usr/local/bin/apacheds start ${APACHEDS_INSTANCE_NAME}
  while ! nc -z localhost 10389; do
    echo "Waiting for ApacheDS to come online..."
    sleep 0.1
  done
  sleep 1
fi

if [ "${APACHEDS_DOMAIN_NAME}" != "example" ] || [ "${APACHEDS_DOMAIN_SUFFIX}" != "com" ]; then
  if [ ! -e "/var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.domain-created" ]; then
    echo "*** Creating partition ${APACHEDS_DOMAIN_NAME} for domain dc=${APACHEDS_DOMAIN_NAME},dc=${APACHEDS_DOMAIN_SUFFIX}..."

    envsubst < "/templates/partition.ldif" > "/tmp/partition.ldif"
    ldapmodify -c -a -f /tmp/partition.ldif -h localhost -p 10389 -D "uid=admin,ou=system" -w ${APACHEDS_ADMIN_PASSWORD}
    ldapdelete "ads-partitionId=example,ou=partitions,ads-directoryServiceId=default,ou=config" -r -p 10389 -h localhost -D "uid=admin,ou=system" -w ${APACHEDS_ADMIN_PASSWORD}
    ldapdelete "dc=example,dc=com" -p 10389 -h localhost -D "uid=admin,ou=system" -r -w ${APACHEDS_ADMIN_PASSWORD}
    /usr/local/bin/apacheds stop ${APACHEDS_INSTANCE_NAME}
    /usr/local/bin/apacheds start ${APACHEDS_INSTANCE_NAME}
    while ! nc -z localhost 10389; do
      echo "Waiting for ApacheDS to come online..."
      sleep 0.1
    done
    sleep 1
    envsubst < "/templates/top_domain.ldif" > "/tmp/top_domain.ldif"
    ldapmodify -c -a -f /tmp/top_domain.ldif -h localhost -p 10389 -D "uid=admin,ou=system" -w ${APACHEDS_ADMIN_PASSWORD}
    touch /var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.domain-created
  fi
fi

if [ -n "${APACHEDS_ACCESS_CONTROL_ENABLED}" ] && [ ! -e "/var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.access_config" ]; then
  echo "*** Enabling access control..."

  envsubst < "/templates/access_config.ldif" > "/tmp/access_config.ldif"
  ldapmodify -c -a -f /tmp/access_config.ldif -h localhost -p 10389 -D "uid=admin,ou=system" -w ${APACHEDS_ADMIN_PASSWORD}
  touch /var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.access_config
fi

if [ -d /ldif.d/ ] && [ ! -e "/var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.ldif.d" ]; then
  for f in /ldif.d/*.ldif; do
    echo "*** Importing ${f}..."
    ldapmodify -c -a -f ${f} -h localhost -p 10389 -D "uid=admin,ou=system" -w ${APACHEDS_ADMIN_PASSWORD}
  done
  touch /var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.ldif.d
fi

/usr/local/bin/apacheds stop ${APACHEDS_INSTANCE_NAME}
exec /usr/local/bin/apacheds console ${APACHEDS_INSTANCE_NAME}

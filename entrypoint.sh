#!/bin/bash

function wait_for_apacheds {
  ATTEMPT=0
  while ! nc -z localhost 10389; do
    ((ATTEMPT++))
    if [ $ATTEMPT -eq 20 ]; then
      echo "FATAL: ApacheDS failed to start, exiting..."
      echo "*** ps auxw ***"
      ps auxw
      echo "*** wrapper.log ***"
      tail -200 /var/lib/apacheds/default/log/wrapper.log
      echo "*** apacheds.log ***"
      tail -200 /var/lib/apacheds/default/log/apacheds.log
      exit 1
    fi
    echo "Waiting for ApacheDS to start..."
    sleep 0.5
  done
  sleep 1
}

target=$1
if find /var/lib/apacheds -mindepth 1 -print -quit | grep -q .; then
  echo "/var/lib/apacheds already populated, skipping initialization"
else
  echo "/var/lib/apacheds empty, performing initialization"
  cp -a /var/lib/apacheds.tmpl/* /var/lib/apacheds/
fi

REAL_APACHEDS_VERSION=$(basename /opt/apacheds-* | sed 's/^apacheds-//')

echo "#include /opt/apacheds-${REAL_APACHEDS_VERSION}/conf/wrapper.conf" > /var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/conf/wrapper-instance.conf

# Decide up front whether any of the bootstrap blocks below has work to do.
# Each of them is already guarded by its own marker file, so on a populated
# volume every one is a no-op -- but the server still had to be started for
# them and stopped again before the real run, and that throwaway cycle
# dominated the startup time. When there is nothing to bootstrap, skip it and
# hand straight over to `apacheds console`.
#
# The conditions here must stay identical to the ones on the blocks; a
# mismatch that under-reports would leave a block wanting a server that is
# not running. Over-reporting is harmless: it only costs the old cycle.
INSTANCE_DIR="/var/lib/apacheds/${APACHEDS_INSTANCE_NAME}"
needs_bootstrap=""
[ "${APACHEDS_ADMIN_PASSWORD}" != "secret" ] && [ ! -e "${INSTANCE_DIR}/.password-set" ] && needs_bootstrap=yes
[ -n "${APACHEDS_ACCESS_CONTROL_ENABLED}" ] && [ ! -e "${INSTANCE_DIR}/.access" ] && needs_bootstrap=yes
{ [ "${APACHEDS_DOMAIN_NAME}" != "example" ] || [ "${APACHEDS_DOMAIN_SUFFIX}" != "com" ]; } && [ ! -e "${INSTANCE_DIR}/.domain-created" ] && needs_bootstrap=yes
[ -n "${APACHEDS_ACCESS_CONTROL_ENABLED}" ] && [ ! -e "${INSTANCE_DIR}/.access_config" ] && needs_bootstrap=yes
[ -d /ldif.d/ ] && [ ! -e "${INSTANCE_DIR}/.ldif.d" ] && needs_bootstrap=yes

if [ -n "${needs_bootstrap}" ]; then
  echo "Bootstrap work pending, starting ApacheDS for it"
  /usr/local/bin/apacheds start ${APACHEDS_INSTANCE_NAME}
  wait_for_apacheds
else
  echo "Nothing to bootstrap, skipping the setup start/stop cycle"
fi

if [ "${APACHEDS_ADMIN_PASSWORD}" != "secret" ] && [ ! -e "/var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.password-set" ]; then
  echo "*** Setting admin password..."

  envsubst < "/templates/admin_password.ldif" > "/tmp/admin_password.ldif"
  ldapmodify -c -a -f /tmp/admin_password.ldif -H ldap://localhost:10389 -D "uid=admin,ou=system" -w secret
  touch /var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.password-set
fi

if [ -n "${APACHEDS_ACCESS_CONTROL_ENABLED}" ] && [ ! -e "/var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.access" ]; then
  echo "*** Enabling access control..."

  ldapmodify -c -a -f /ldif/access.ldif -H ldap://localhost:10389 -D "uid=admin,ou=system" -w ${APACHEDS_ADMIN_PASSWORD}
  touch /var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.access
  /usr/local/bin/apacheds stop ${APACHEDS_INSTANCE_NAME}
  /usr/local/bin/apacheds start ${APACHEDS_INSTANCE_NAME}
  wait_for_apacheds
fi

if [ "${APACHEDS_DOMAIN_NAME}" != "example" ] || [ "${APACHEDS_DOMAIN_SUFFIX}" != "com" ]; then
  if [ ! -e "/var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.domain-created" ]; then
    echo "*** Creating partition ${APACHEDS_DOMAIN_NAME} for domain dc=${APACHEDS_DOMAIN_NAME},dc=${APACHEDS_DOMAIN_SUFFIX}..."

    envsubst < "/templates/partition.ldif" > "/tmp/partition.ldif"
    ldapmodify -c -a -f /tmp/partition.ldif -H ldap://localhost:10389 -D "uid=admin,ou=system" -w ${APACHEDS_ADMIN_PASSWORD}
    ldapdelete "ads-partitionId=example,ou=partitions,ads-directoryServiceId=default,ou=config" -r -H ldap://localhost:10389 -D "uid=admin,ou=system" -w ${APACHEDS_ADMIN_PASSWORD}
    ldapdelete "dc=example,dc=com" -H ldap://localhost:10389 -D "uid=admin,ou=system" -r -w ${APACHEDS_ADMIN_PASSWORD}
    /usr/local/bin/apacheds stop ${APACHEDS_INSTANCE_NAME}
    /usr/local/bin/apacheds start ${APACHEDS_INSTANCE_NAME}
    wait_for_apacheds
    envsubst < "/templates/top_domain.ldif" > "/tmp/top_domain.ldif"
    ldapmodify -c -a -f /tmp/top_domain.ldif -H ldap://localhost:10389 -D "uid=admin,ou=system" -w ${APACHEDS_ADMIN_PASSWORD}
    touch /var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.domain-created
  fi
fi

if [ -n "${APACHEDS_ACCESS_CONTROL_ENABLED}" ] && [ ! -e "/var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.access_config" ]; then
  echo "*** Enabling access control..."

  envsubst < "/templates/access_config.ldif" > "/tmp/access_config.ldif"
  ldapmodify -c -a -f /tmp/access_config.ldif -H ldap://localhost:10389 -D "uid=admin,ou=system" -w ${APACHEDS_ADMIN_PASSWORD}
  touch /var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.access_config
fi

if [ -d /ldif.d/ ] && [ ! -e "/var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.ldif.d" ]; then
  for f in /ldif.d/*.ldif; do
    echo "*** Importing ${f}..."
    ldapmodify -c -a -f ${f} -H ldap://localhost:10389 -D "uid=admin,ou=system" -w ${APACHEDS_ADMIN_PASSWORD}
  done
  touch /var/lib/apacheds/${APACHEDS_INSTANCE_NAME}/.ldif.d
fi

if [ -n "${needs_bootstrap}" ]; then
  /usr/local/bin/apacheds stop ${APACHEDS_INSTANCE_NAME}
fi
exec /usr/local/bin/apacheds console ${APACHEDS_INSTANCE_NAME}

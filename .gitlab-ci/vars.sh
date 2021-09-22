#!/bin/bash

set -e -o pipefail

APACHEDS_VERSION=$(curl -s "https://directory.apache.org/apacheds/" \
  | grep '<li><a href="/apacheds/downloads.html">ApacheDS' \
  | head -1 \
  | sed 's,^.*>ApacheDS \(.*\)</a>.*$,\1,' || exit 0)
export APACHEDS_VERSION

ARG_APACHEDS_VERSION="${APACHEDS_VERSION}"
export ARG_APACHEDS_VERSION

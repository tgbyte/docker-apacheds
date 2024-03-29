#!/bin/bash -ex

export GIT_COMMITTER_NAME=Anonymous
export GIT_COMMITTER_EMAIL=me@privacy.net

git clone -v https://github.com/apache/directory-server.git
cd directory-server
git checkout ${DIRECTORY_SERVER_GIT_REVISION}
mvn -P debian -B -T 1C -DskipTests clean install

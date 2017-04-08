node {
  git credentialsId: 'jenkins', url: 'git@gitlab:docker/apacheds.git'
  checkout scm

  docker.withTool('Docker') {
    docker.image('maven:3.3.9-jdk-8').inside("-e GIT_COMMITTER_NAME=Anonymous -e GIT_COMMITTER_EMAIL=me@privacy.net -v ${workspace}/.m2:/root/.m2") {
      sh 'git clone https://github.com/apache/directory-shared.git'
      sh 'cd directory-shared && mvn -B clean install'
    }

    docker.image('maven:3.3.9-jdk-8').inside("-e GIT_COMMITTER_NAME=Anonymous -e GIT_COMMITTER_EMAIL=me@privacy.net -v ${workspace}/.m2:/root/.m2") {
      sh 'git clone https://github.com/apache/directory-server.git'
      sh 'cd directory-server && mvn -P debian -B clean install'
    }
  }
}

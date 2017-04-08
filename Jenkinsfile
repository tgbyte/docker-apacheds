node {
  git credentialsId: 'jenkins', url: 'git@gitlab:docker/apacheds.git'
  checkout scm

  sh 'git clone https://github.com/apache/directory-server.git'

  docker.withTool('Docker') {
    docker.withServer('tcp://dind:2375') {
      docker.image('maven:3.3.9-jdk-8').inside {
        sh 'git clone https://github.com/apache/directory-shared.git'
        sh 'mvn -B clean install'
      }
    }
  }
}

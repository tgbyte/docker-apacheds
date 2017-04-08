node {
  stage('Checkout') {
    checkout scm
  }

  docker.withTool('Docker') {
    def mavenArgs = "-e MAVEN_OPTS=-Duser.home=/root -e GIT_COMMITTER_NAME=Anonymous -e GIT_COMMITTER_EMAIL=me@privacy.net -v ${workspace}/.m2:/root/.m2"

    stage('Build directory-shared') {
      docker.image('maven:3.3.9-jdk-8').inside(mavenArgs) {
        sh 'git clone https://github.com/apache/directory-shared.git'
        sh 'cd directory-shared && mvn -B clean install'
      }
    }

    stage('Build directory-server') {
      docker.image('maven:3.3.9-jdk-8').inside(mavenArgs) {
        sh 'git clone https://github.com/apache/directory-server.git'
        sh 'cd directory-server && mvn -P debian -B -T 1C clean install'
      }
    }

    stage('Build apacheds Docker image') {
      def image = docker.build('tgbyte/apacheds')
    }
  }
}

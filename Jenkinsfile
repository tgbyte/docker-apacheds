node {
  def directorySharedRevision = 'b015ff51a13018652c6e57d452650d1fb34d0bed'
  def directoryServerRevision = '7c9ec394af8baafb822142421d843448acdba889'

  stage('Cleanup') {
    sh 'rm -rf directory-shared directory-server'
  }

  stage('Checkout') {
    checkout scm
  }

  docker.withTool('Docker') {
    def mavenArgs = "-e MAVEN_OPTS=-Duser.home=${workspace} -e GIT_COMMITTER_NAME=Anonymous -e GIT_COMMITTER_EMAIL=me@privacy.net"

    stage('Build directory-shared') {
      docker.image('maven:3.2.5-jdk-8').inside(mavenArgs) {
        sh 'git clone https://github.com/apache/directory-shared.git'
        sh "cd directory-shared && git checkout ${directorySharedRevision} && mvn -B -DskipTests clean install"
      }
    }

    stage('Build directory-server') {
      docker.image('maven:3.2.5-jdk-8').inside(mavenArgs) {
        sh 'git clone https://github.com/apache/directory-server.git'
        sh "cd directory-server && git checkout ${directoryServerRevision} && mvn -P debian -B -T 1C -DskipTests clean install"
      }
    }

    def image
    stage('Build apacheds Docker image') {
      def tag = env.BRANCH_NAME == 'master' ? 'latest' : env.BRANCH_NAME.replace('/', '-')
      def image = docker.build("tgbyte/apacheds:${tag}")
    }

    stage('Push apacheds Docker image') {
      docker.withRegistry('https://index.docker.io/v1/', 'docker-hub') {
        image.push()
      }
    }
  }
}

pipeline {
    agent any
    environment {
        IMAGE_NAME = "smarthome_backend"
    }
    stages {
        stage("clone backend repo") {
            steps {
                sh "git clone https://github.com/NadavNV/SmartHomeBackend"
                echo "Backend repo was cloned"
            }
        }
        stage('create .env file') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'mongo-creds', usernameVariable: 'MONGO_USER', passwordVariable: 'MONGO_PASS')]) {
                    sh '''
                        echo "MONGO_USER=$MONGO_USER" > SmartHomeBackend/.env
                        echo "MONGO_PASS=$MONGO_PASS" >> SmartHomeBackend/.env
                    '''
                }
            }
        }
        stage("build image") {
    steps {
        echo "Building the app image"
        sh "docker build -t ${env.IMAGE_NAME}:${env.BUILD_NUMBER} SmartHomeBackend"
            }
        }
        stage('test') {
            steps {
                echo "******testing the app******"
                sh "docker run -d -p 5200:5200 --name test-container ${env.IMAGE_NAME}:${env.BUILD_NUMBER}"
                sh "sleep 5"
                sh "python3 SmartHomeBackend/Test/test.py"
            }
            // post {
            //     always {
            //         sh "docker rm -f test-container"
            //     }
            // }
        }
        stage('deploy') {
            steps {
                echo "******deploying a new version******"
                // withCredentials(...) {
                //     ...
                // }
            }
        }
    }

    post {
        always {
            cleanWs()
            sh "docker rmi -f ${env.IMAGE_NAME}:${env.BUILD_NUMBER}"
        }
    }
}
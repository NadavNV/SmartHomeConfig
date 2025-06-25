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
        stage("build image") {
            steps {
                echo "Building the app image"
                sh "docker build -f SmartHomeBackend/Dockerfile -t ${env.IMAGE_NAME}:${env.BUILD_NUMBER} ."
            }
        }
        stage('test') {
            steps {
                echo "******testing the app******"
                sh "docker run -d -p 5200:5200 --name test-container ${env.IMAGE_NAME}:${env.BUILD_NUMBER}"
                sh "sleep 60"
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
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
                sh '''
                    echo "Waiting for Flask app to become available..."
                    for i in {1..20}; do
                        if curl -s http://localhost:5200/api/devices > /dev/null; then
                        echo "Flask app is up!"
                        break
                        fi
                        sleep 1
                    done
                    '''
                sh "python3 SmartHomeBackend/Test/test.py"
            }
            post {
                always {
                    sh "docker rm -f test-container"
                }
            }
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
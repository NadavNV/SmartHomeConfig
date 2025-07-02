pipeline {
    agent any
    environment {
        IMAGE_NAME = "smarthome_backend"
        SIM_IMAGE_NAME = "smarthome_simulator"
    }
    stages {
        // for testing only
        // stage("clone config repo") {
        //     steps {
        //         sh "git clone https://github.com/NadavNV/SmartHomeConfig"
        //         echo "config repo was cloned"
        //     }
        // }
        stage("clone backend repo") {
            steps {
                sh "git clone https://github.com/NadavNV/SmartHomeBackend"
                echo "Backend repo was cloned"
            }
        }
        stage("clone simulator repo") {
            steps {
                sh "git clone https://github.com/NadavNV/SmartHomeSimulator"
                echo "simulator repo was cloned"
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
        stage("build backend image") {
    steps {
        echo "Building the app image"
        sh "docker build -t ${env.IMAGE_NAME}:${env.BUILD_NUMBER} SmartHomeBackend"
            }
        }
        stage("build simulator image") {
    steps {
        echo "Building the simulator image"
        sh "docker build -t ${env.SIM_IMAGE_NAME}:${env.BUILD_NUMBER} SmartHomeSimulator"
            }
        }
        stage('test') {
            steps {
                echo "******testing the app******"
                sh "docker network create test-net || true"
                sh "docker run -d -p 5200:5200 --network test-net --env-file SmartHomeBackend/.env --name test-container ${env.IMAGE_NAME}:${env.BUILD_NUMBER}"
                sh "sleep 10"
                sh '''
                    docker run --rm \
                    --network test-net \
                    -v /home/jenkins/.jenkins/workspace/smarthome_test:/app \
                    -w /app \
                    python:3.12-slim \
                    /bin/sh -c "pip install requests && python3 SmartHomeBackend/Test/test.py"
                '''
            }
            post {
                always {
                    sh "docker rm -f test-container"
                    sh "docker network rm test-net"
                }
            }
        }
//         stage('deploy') {
//     steps {
//         echo "******deploying a new version******"
//         withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
//             sh """
//                 echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

//                 docker tag ${env.IMAGE_NAME}:${env.BUILD_NUMBER} $DOCKER_USER/${env.IMAGE_NAME}:V${env.BUILD_NUMBER}
//                 docker push $DOCKER_USER/${env.IMAGE_NAME}:V${env.BUILD_NUMBER}
//                 docker tag ${env.IMAGE_NAME}:${env.BUILD_NUMBER} $DOCKER_USER/${env.IMAGE_NAME}:latest
//                 docker push $DOCKER_USER/${env.IMAGE_NAME}:latest

//                 docker tag ${env.SIM_IMAGE_NAME}:${env.BUILD_NUMBER} $DOCKER_USER/${env.SIM_IMAGE_NAME}:V${env.BUILD_NUMBER}
//                 docker push $DOCKER_USER/${env.SIM_IMAGE_NAME}:V${env.BUILD_NUMBER}
//                 docker tag ${env.SIM_IMAGE_NAME}:${env.BUILD_NUMBER} $DOCKER_USER/${env.SIM_IMAGE_NAME}:latest
//                 docker push $DOCKER_USER/${env.SIM_IMAGE_NAME}:latest

//                 docker logout
//             """
//         }
//     }
// }

    }

    post {
        always {
            cleanWs()
            sh "docker rmi -f ${env.IMAGE_NAME}:${env.BUILD_NUMBER}"
            // sh "docker rmi -f ${env.IMAGE_NAME}:V${env.BUILD_NUMBER}"
            // sh "docker rmi -f ${env.IMAGE_NAME}:latest"
            sh "docker rmi -f ${env.SIM_IMAGE_NAME}:${env.BUILD_NUMBER}"
        }
    }
}
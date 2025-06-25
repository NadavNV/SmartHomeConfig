pipeline{
    agent any
    environment {
        IMAGE_NAME = "SmartHome-Backend"
    }
    stages{
        stage("clone backend repo"){
            steps{
                sh "git clone https://github.com/NadavNV/SmartHomeBackend"
                echo "Backend repo was cloned" 
            }
        }
        stage("build image"){
            steps{
            echo "Building the app image"
            sh "docker build-f SmartHomeBackend/Dockerfile -t ${env.IMAGE_NAME}:${env.BUILD_NUMBER} ."
            }
        }
        stage('test') {
            steps {
                echo "******testing the app******"
                sh "docker run -d -p 5200:5200 --name test-container ${env.IMAGE_NAME}:${env.BUILD_NUMBER}"
                sh "sleep 5"
                sh "python3 SmartHomeBackend/Test/test.py"
            }
            post {
                always {
                    sh "docker rm -f test-container"
                }
            }
        }
        // stage('deploy') {
        //     steps {
        //         echo "******deploying a new version******"
        //         withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
        //             sh """
        //                 echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
        //                 docker tag ${env.IMAGE_NAME}:${env.BUILD_NUMBER} $DOCKER_USER/movies_api:latest
        //                 docker push $DOCKER_USER/movies_api:latest
        //             """
        //         }
        //     }
        // }
    }

    post {
        always {
            cleanWs()
            sh "docker rmi -f ${env.IMAGE_NAME}:${env.BUILD_NUMBER}"
        }
    }
}
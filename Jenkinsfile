pipeline {
    agent any
    environment {
        IMAGE_NAME = "smarthome_backend"
        SIM_IMAGE_NAME = "smarthome_simulator"
        FRONT_IMAGE_NAME = "smarthome_dashboard"
    }
    stages {
        stage("clone backend repo") {
            steps {
                sh "git clone https://github.com/NadavNV/SmartHomeBackend"
                echo "Backend repo was cloned"
            }
        }
        stage("clone frontend repo") {
            steps {
                sh "git clone https://github.com/NadavNV/SmartHomeDashboard"
                echo "Frontend repo was cloned"
                // Change the nginx.conf file to work localy
                writeFile file: 'SmartHomeDashboard/nginx.conf', text: '''
                server {
                    listen 3001;
                    root /usr/share/nginx/html;
                    index index.html;
                    etag on;

                    # Serve the React app
                    location / {
                        try_files $uri $uri/ /index.html;
                    }

                    # Proxy API requests to backend container on Docker network
                    location /api/ {
                        proxy_pass http://test-container:5200;
                        proxy_http_version 1.1;
                        proxy_set_header Host $host;
                        proxy_set_header X-Real-IP $remote_addr;
                        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                        proxy_set_header X-Forwarded-Proto $scheme;
                    }
                }
                '''
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
                        echo "BROKER_URL=mqtt-broker" >> SmartHomeBackend/.env
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
        stage("build frontend image") {
            steps {
                echo "Building the frontend image"
                sh "docker build -t ${env.FRONT_IMAGE_NAME}:${env.BUILD_NUMBER} --build-arg VITE_API_URL=http://test-container:5200 SmartHomeDashboard"
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
                sh """
                    docker run -d \
                    --network test-net \
                    --name mqtt-broker \
                    -v "$WORKSPACE/mosquitto/mosquitto.conf:/mosquitto/config/mosquitto.conf" \
                    eclipse-mosquitto
                """
                sh "sleep 10"
                sh "docker run -d -p 5200:5200 --network test-net \
                --env-file SmartHomeBackend/.env \
                --name test-container \
                --hostname test-container \
                -e BROKER_URL=mqtt-broker \
                -e BROKER_PORT=1883 \
                 ${env.IMAGE_NAME}:${env.BUILD_NUMBER}"
                sh "sleep 10"
                script {
                    def backendIp = sh(
                        script: '''
                            MAX_RETRIES=10
                            RETRY_DELAY=2
                            DEFAULT_IP="172.19.0.3"
                            IP=""
                            for i in $(seq 1 $MAX_RETRIES); do
                                IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' test-container 2>/dev/null)
                                if [[ -n "$IP" ]]; then
                                    break
                                else
                                    >&2 echo "Waiting for test-container IP... attempt $i"
                                    sleep $RETRY_DELAY
                                fi
                            done
                            if [[ -z "$IP" ]]; then
                                IP="$DEFAULT_IP"
                            fi
                            echo "$IP"
                        ''',
                        returnStdout: true
                    ).trim()

                    echo "Backend IP: ${backendIp}"
                    env.BACKEND_URL = "http://${backendIp}:5200"
                }

                sh "docker run -d --network test-net --name simulator-container -e API_URL=${BACKEND_URL} ${env.SIM_IMAGE_NAME}:${env.BUILD_NUMBER}"
                sh "docker run -d -p 3001:3001 --network test-net --name frontend-container --hostname frontend-container ${env.FRONT_IMAGE_NAME}:${env.BUILD_NUMBER}"
                sh "sleep 20"
                sh """
                    docker run --rm \
                    --network test-net \
                    -v "${env.WORKSPACE}:/app" \
                    -w /app \
                    -e FRONTEND_URL=http://frontend-container:3001 \
                    -e BACKEND_URL=${BACKEND_URL} \
                    yardenziv/smarthome-test-runner:latest \
                    SmartHomeBackend/Test/test.py
                """

            }
            post {
                always {
            sh "docker rm -f test-container || true"
            sh "docker rm -f simulator-container || true"
            sh "docker rm -f frontend-container || true"
            sh "docker rm -f mqtt-broker || true"
            sh "docker network rm test-net || true"
                }
            }
        }
        stage('deploy') {
    steps {
        echo "******deploying a new version******"
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
            sh """
                echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

                docker tag ${env.IMAGE_NAME}:${env.BUILD_NUMBER} $DOCKER_USER/${env.IMAGE_NAME}:V${env.BUILD_NUMBER}
                docker push $DOCKER_USER/${env.IMAGE_NAME}:V${env.BUILD_NUMBER}
                docker tag ${env.IMAGE_NAME}:${env.BUILD_NUMBER} $DOCKER_USER/${env.IMAGE_NAME}:latest
                docker push $DOCKER_USER/${env.IMAGE_NAME}:latest

                docker tag ${env.SIM_IMAGE_NAME}:${env.BUILD_NUMBER} $DOCKER_USER/${env.SIM_IMAGE_NAME}:V${env.BUILD_NUMBER}
                docker push $DOCKER_USER/${env.SIM_IMAGE_NAME}:V${env.BUILD_NUMBER}
                docker tag ${env.SIM_IMAGE_NAME}:${env.BUILD_NUMBER} $DOCKER_USER/${env.SIM_IMAGE_NAME}:latest
                docker push $DOCKER_USER/${env.SIM_IMAGE_NAME}:latest

                docker tag ${env.FRONT_IMAGE_NAME}:${env.BUILD_NUMBER} $DOCKER_USER/${env.FRONT_IMAGE_NAME}:V${env.BUILD_NUMBER}
                docker push $DOCKER_USER/${env.FRONT_IMAGE_NAME}:V${env.BUILD_NUMBER}
                docker tag ${env.FRONT_IMAGE_NAME}:${env.BUILD_NUMBER} $DOCKER_USER/${env.FRONT_IMAGE_NAME}:latest
                docker push $DOCKER_USER/${env.FRONT_IMAGE_NAME}:latest

                docker logout
            """
        }
    }
}

    }

    post {
        always {
            cleanWs()
            sh '''
            for id in $(docker images -q ${IMAGE_NAME} | sort -u); do
            docker rmi -f $id || true
            done
        '''
            sh '''
            for id in $(docker images -q ${SIM_IMAGE_NAME} | sort -u); do
            docker rmi -f $id || true
            done
        '''
        sh '''
            for id in $(docker images -q ${FRONT_IMAGE_NAME} | sort -u); do
            docker rmi -f $id || true
            done
        '''
        }
    }
}
pipeline{
    agent any
    environment{
        FLASK = "smart-home-backend-flask"
        NGINX = "smart-home-backend-nginx"
        GRAFANA = "smart-home-grafana"
        FRONTEND = "smart-home-dashboard"
        SIMULATOR = "smart-home-simulator"
        DOCKER_USERNAME = "nadavnv"
        PC = "a"  // I work from different computers with different BUILD_NUMBERs
    }
    stages{
        stage("Prepare") {
            steps{
                // Make sure docker is available
                sh "docker ps"
            }
        }
        stage('Clone'){
            parallel {
                stage("Cloning backend"){
                    steps{
                        echo "====== Cloning backend repo ======"
                        sh "mkdir SmartHomeBackend"
                        dir('SmartHomeBackend'){
                            git branch: 'main', url: 'https://github.com/NadavNV/SmartHomeBackend'
                            sh "git submodule update --init --recursive"
                            withCredentials([usernamePassword(credentialsId: 'redis-credentials', passwordVariable: 'REDIS_PASS', usernameVariable: 'REDIS_USER'), usernamePassword(credentialsId: 'mongo-credentials', passwordVariable: 'MONGO_PASS', usernameVariable: 'MONGO_USER')]) {
                                echo "====== Creating backend .env ======"
                                sh '''
                                    echo "MONGO_USER=$MONGO_USER" > .env
                                    echo "MONGO_PASS=$MONGO_PASS" >> .env
                                    echo "REDIS_PASS=$REDIS_PASS" >> .env
                                    echo "BROKER_HOST=mqtt-broker" >> .env
                                '''
                            }
                        }
                    }
                }
                stage("Cloning frontend"){
                    steps{
                        echo "====== Cloning frontend repo ======"
                        sh "mkdir SmartHomeDashboard"
                        dir('SmartHomeDashboard'){
                            git branch: 'main', url: 'https://github.com/NadavNV/SmartHomeDashboard'
                            sh "git submodule update --init --recursive"
                            echo "====== Creating frontend .env ======"
                            sh '''
                                echo "BACKEND_URL=backend:5200" > .env
                            '''
                        }
                    }
                }
                stage("Cloning simulator"){
                    steps{
                        echo "====== Cloning simulator repo ======"
                        sh "mkdir SmartHomeSimulator"
                        dir('SmartHomeSimulator'){
                            git branch: 'main', url: 'https://github.com/NadavNV/SmartHomeSimulator'
                            sh "git submodule update --init --recursive"
                            echo "====== Creating simulator .env ======"
                            sh '''
                                echo "BROKER_HOST=mqtt-broker" > .env
                            '''
                        }
                    }
                }
                stage("Cloning config"){
                    steps{
                        echo "====== Cloning config repo ======"
                        sh "mkdir SmartHomeConfig"
                        dir('SmartHomeConfig'){
                            git branch: 'main', url: 'https://github.com/NadavNV/SmartHomeConfig'
                        }
                    }
                }
            }
        }
        stage('Build'){
            parallel{
                stage("Building backend"){
                    steps{
                        echo "====== Building the backend ======"
                        // Make sure that the container names are available
                        sh "docker stop ${FLASK} || true"
                        sh "docker stop backend || true"
                        dir('SmartHomeBackend'){
                            sh "docker build -f flask.Dockerfile -t ${DOCKER_USERNAME}/${FLASK}:V${PC}.${BUILD_NUMBER} ."
                            sh "docker build -f nginx.Dockerfile -t ${DOCKER_USERNAME}/${NGINX}:V${PC}.${BUILD_NUMBER} ."
                        }
                    }
                }
                stage("Building frontend"){
                    steps{
                        echo "====== Building the frontend ======"
                        // Make sure that the container name is available
                        sh "docker stop ${FRONTEND} || true"
                        dir('SmartHomeDashboard'){
                            sh "docker build --build-arg VITE_API_URL=backend:5200 -t ${DOCKER_USERNAME}/${FRONTEND}:V${PC}.${BUILD_NUMBER} ."
                        }
                    }
                }
                stage("Building simulator"){
                    steps{
                        echo "====== Building the simulator ======"
                        // Make sure that the container name is available
                        sh "docker stop ${SIMULATOR} || true"
                        dir('SmartHomeSimulator'){
                            sh "docker build -t ${DOCKER_USERNAME}/${SIMULATOR}:V${PC}.${BUILD_NUMBER} ."
                        }
                    }
                }
                stage("Building grafana"){
                    steps{
                        echo "====== Building grafana ======"
                        // Make sure that the container name is available
                        sh "docker stop ${GRAFANA} || true"
                        dir('SmartHomeConfig/monitoring/grafana'){
                            sh "docker build -t ${DOCKER_USERNAME}/${GRAFANA}:V${PC}.${BUILD_NUMBER} ."
                        }
                    }
                }
            }
        }
        stage('Prepare for testing'){
            steps{
                echo "====== Testing the app ======"
                sh "docker network create test || true"
                // run and config a local mqtt-broker for testing
                sh '''
                    docker stop mqtt-broker || true
                    docker rm -f mqtt-broker || true

                    CONFIG_DIR="$WORKSPACE/mosquitto_config"

                    mkdir -p "$CONFIG_DIR"

                    if [ ! -f "$WORKSPACE/mosquitto/mosquitto.conf" ]; then
                        printf "listener 1883\nallow_anonymous true\n\n" > "$CONFIG_DIR/mosquitto.conf"
                    else
                        cp "$WORKSPACE/mosquitto/mosquitto.conf" "$CONFIG_DIR"
                    fi

                    cat "$CONFIG_DIR/mosquitto.conf"
                    chmod 644 "$CONFIG_DIR/mosquitto.conf"

                    docker run --rm -v "$CONFIG_DIR/mosquitto.conf":/mosquitto/config/mosquitto.conf alpine ls -l /mosquitto/config

                    docker run -d \
                    --network test \
                    --name mqtt-broker \
                    -v "$CONFIG_DIR":/mosquitto/config \
                    eclipse-mosquitto

                    sleep 3

                    docker logs mqtt-broker
                '''
            }
        }
        stage("Run the backend"){
            steps{
                echo "====== Running the backend ======"
                sh """
                    docker run -d -p 8000:8000 --env-file SmartHomeBackend/.env \\
                    --network test --name ${FLASK} ${DOCKER_USERNAME}/${FLASK}:V${PC}.${BUILD_NUMBER}

                    docker run -d -p 5200:5200 --network test --name backend \\
                    ${DOCKER_USERNAME}/${NGINX}:V${PC}.${BUILD_NUMBER}

                    docker ps -a
                    docker logs ${FLASK}
                """
                echo "====== Testing the backend ======"
                sh "for i in {1..10}; do docker exec ${FLASK} curl http://localhost:8000/ready && break || sleep 5; done"
                sh "for i in {1..10}; do docker exec backend curl http://localhost:5200/ready && break || sleep 5; done"
                sh "docker exec ${FLASK} python -m unittest discover -s /app/test -p \"test_*.py\" -v"
            }
        }
        stage("Unit test dependencies"){
            parallel{
                stage("Testing the simulator"){
                    steps{
                        echo "====== Running the simulator ======"
                        sh """
                        docker run -d --env-file SmartHomeSimulator.env \\
                        --network test --name ${SIMULATOR} ${DOCKER_USERNAME}/${SIMULATOR}:V${PC}.${BUILD_NUMBER}
                        """
                        echo "====== Testing the simulator ======"
                        sh "for i in {1..10}; do docker exec ${SIMULATOR} cat status | grep ready && break || sleep 5; done"
                    }
                }
                stage("Testing the frontend"){
                    steps{
                        echo "====== Running the frontend ======"
                        sh """
                        docker run -d --network test --env-file SmartHomeDashboard/.env --name ${FRONTEND} \\
                        ${DOCKER_USERNAME}/${FRONTEND}:V${PC}.${BUILD_NUMBER}
                        """
                        echo "====== Testing the frontend ======"                        
                        sh """bash -c '
                        for i in {1..10}; do
                        (curl --max-time 5 http://localhost:3001 && docker exec ${FRONTEND} curl http://backend:5200/ready) && break || sleep 5
                        done'
                        """
                    }
                }
                stage("Testing grafana"){
                    steps{
                        echo "====== Running grafana ======"
                        sh """
                        docker run -d --network test --name ${GRAFANA} \\
                        ${DOCKER_USERNAME}/${GRAFANA}:V${PC}.${BUILD_NUMBER}
                        """
                        echo "====== Testing grafana ======"
                        sh "for i in {1..10}; do curl http://localhost:3000/api/health && break || sleep 5; done"
                    }
                }
            }
        }
        stage("Integration test"){
            steps{
                sh """
                export FRONTEND_URL=${FRONTEND}:3001
                export BACKEND_URL=backend:5200
                docker exec ${FLASK} python test/integration_test.py
                """
            }
        }
        stage("Build clean frontend"){
            steps{
                dir('SmartHomeDashboard'){
                    sh "docker rm -f ${FRONTEND} || true"
                    sh "docker rmi -f ${DOCKER_USERNAME}/${FRONTEND}:V${PC}.${BUILD_NUMBER} || true"
                    sh "docker build -t ${DOCKER_USERNAME}/${FRONTEND}:V${PC}.${BUILD_NUMBER} ."
                }
            }
        }
        stage("Docker login"){
            steps{
                sh "docker logout"
                withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                    sh "echo $PASS | docker login -u $USER --password-stdin"
                }
            }
        }
        stage('Deploy'){
            parallel{
                stage("Deploying backend"){
                    steps{
                        echo "====== Deploying the backend ======"
                        sh "docker image tag ${DOCKER_USERNAME}/${FLASK}:V${PC}.$BUILD_NUMBER ${DOCKER_USERNAME}/${FLASK}:latest"
                        sh "docker image tag ${DOCKER_USERNAME}/${NGINX}:V${PC}.$BUILD_NUMBER ${DOCKER_USERNAME}/${NGINX}:latest"
                        retry(4){
                            sh "docker push ${DOCKER_USERNAME}/${NGINX}:latest"
                        }
                        retry(4){
                            sh "docker push ${DOCKER_USERNAME}/${NGINX}:V${PC}.${BUILD_NUMBER}"
                        }
                        retry(4){
                            sh "docker push ${DOCKER_USERNAME}/${FLASK}:latest"
                        }
                        retry(4){
                            sh "docker push ${DOCKER_USERNAME}/${FLASK}:V${PC}.${BUILD_NUMBER}"
                        }
                    }
                }
                stage("Deploying frontend"){
                    steps{
                        echo "====== Deploying the frontend ======"
                        sh "docker image tag ${DOCKER_USERNAME}/${FRONTEND}:V${PC}.$BUILD_NUMBER ${DOCKER_USERNAME}/${FRONTEND}:latest"
                        retry(4){
                            sh "docker push ${DOCKER_USERNAME}/${FRONTEND}:latest"
                        }
                        retry(4){
                            sh "docker push ${DOCKER_USERNAME}/${FRONTEND}:V${PC}.${BUILD_NUMBER}"
                        }
                    }
                }
                stage("Deploying simulator"){
                    steps{
                        echo "====== Deploying the simulator ======"
                        sh "docker image tag ${DOCKER_USERNAME}/${SIMULATOR}:V${PC}.$BUILD_NUMBER ${DOCKER_USERNAME}/${SIMULATOR}:latest"
                        retry(4){
                            sh "docker push ${DOCKER_USERNAME}/${SIMULATOR}:latest"
                        }
                        retry(4){
                            sh "docker push ${DOCKER_USERNAME}/${SIMULATOR}:V${PC}.${BUILD_NUMBER}"
                        }
                    }
                }
                stage("Deploying grafana"){
                    steps{
                        echo "====== Deploying grafana ======"
                        sh "docker image tag ${DOCKER_USERNAME}/${GRAFANA}:V${PC}.$BUILD_NUMBER ${DOCKER_USERNAME}/${GRAFANA}:latest"
                        retry(4){
                            sh "docker push ${DOCKER_USERNAME}/${GRAFANA}:latest"
                        }
                        retry(4){
                            sh "docker push ${DOCKER_USERNAME}/${GRAFANA}:V${PC}.${BUILD_NUMBER}"
                        }
                    }
                }
            }
        }
    }
    post{
        always{
            // Clean up workspace
            cleanWs(
                cleanWhenNotBuilt: false,
                deleteDirs: true,
                disableDeferredWipeout: true,
                notFailBuild: true
            )
            // Remove the containers
            sh "docker stop mqtt-broker || true"
            sh "docker stop ${FLASK} || true"
            sh "docker stop backend || true"
            sh "docker stop ${FRONTEND} || true"
            sh "docker stop ${SIMULATOR} || true"
            sh "docker stop ${GRAFANA} || true"
            sh "docker rm -f mqtt-broker || true"
            sh "docker rm -f ${FLASK} || true"
            sh "docker rm -f backend || true"
            sh "docker rm -f ${FRONTEND} || true"
            sh "docker rm -f ${SIMULATOR} || true"
            sh "docker rm -f ${GRAFANA} || true"
            // Remove images
            sh "docker rmi -f eclipse-mosquitto || true"
            sh "docker rmi -f \$(docker image ls | egrep '^nadav' | awk '{print \$3}') || true"
            sh "docker logout || true"
        }
    }
}
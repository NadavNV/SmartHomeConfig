pipeline{
    agent any
    environment{
        FLASK = "smart-home-backend-flask"
        NGINX = "smart-home-backend-nginx"
        GRAFANA = "smart-home-grafana"
        FRONTEND = "smart-home-dashboard"
        SIMULATOR = "smart-home-simulator"
        DOCKER_USERNAME = "nadavnv"
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
                            sh """
                                echo "BACKEND_URL=${NGINX}:5200" > .env
                            """
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
                            sh """
                                echo "BROKER_HOST=mqtt-broker" > .env
                                echo "API_URL=http://${NGINX}:5200" >> .env
                            """
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
        stage("Get Tags") {
            steps {
                script {
                    def services = [
                        [name: "FLASK",      dir: "SmartHomeBackend",     dockerImage: "${DOCKER_USERNAME}/${FLASK}"],
                        [name: "NGINX",      dir: "SmartHomeBackend",     dockerImage: "${DOCKER_USERNAME}/${NGINX}"],
                        [name: "FRONTEND",   dir: "SmartHomeDashboard",   dockerImage: "${DOCKER_USERNAME}/${FRONTEND}"],
                        [name: "SIMULATOR",  dir: "SmartHomeSimulator",   dockerImage: "${DOCKER_USERNAME}/${SIMULATOR}"],
                        [name: "GRAFANA",    dir: "SmartHomeConfig",      dockerImage: "${DOCKER_USERNAME}/${GRAFANA}"]
                    ]

                    // Clean tag tracking files
                    sh 'rm -f metadata.env'

                    for (svc in services) {
                        def tag = ""
                        dir(svc.dir) {
                            // Get latest tag pointing to HEAD commit
                            tag = sh(script: "git describe --tags --abbrev=0 || echo 0.0.0", returnStdout: true).trim()
                        }

                        // Write the tag to the env file
                        sh "echo '${svc.name}_TAG=${tag}' >> metadata.env"

                        // Check if Docker Hub already has this tag
                        def exists = sh(
                            script: """
                                curl -s -f https://hub.docker.com/v2/repositories/${svc.dockerImage}/tags/${tag} > /dev/null && echo exists || echo missing
                            """,
                            returnStdout: true
                        ).trim()

                        def isNew = (exists == "missing") ? "true" : "false"
                        sh "echo '${svc.name}_IS_NEW=${isNew}' >> metadata.env"
                        echo "${svc.name}: tag=${tag}, isNew=${isNew}"
                    }
                }
            }
        }
        stage('Build'){
            parallel{
                stage("Building backend"){
                    steps{
                        def envData = readFile('metadata.env').trim().split('\n')
                        def envMap = envData.collectEntries { line ->
                            def (k, v) = line.split('=')
                            [(k): v]
                        }
                        echo "====== Building the backend ======"
                        // Make sure that the container names are available
                        sh "docker stop ${FLASK} || true"
                        sh "docker stop ${NGINX} || true"
                        dir('SmartHomeBackend'){
                            sh "docker build -f flask.Dockerfile -t ${DOCKER_USERNAME}/${FLASK}:V${envMap.FLASK_TAG} ."
                            sh "docker build -f nginx.Dockerfile -t ${DOCKER_USERNAME}/${NGINX}:V${envMap.NGINX_TAG} ."
                        }
                    }
                }
                stage("Building frontend"){
                    steps{
                        def envData = readFile('metadata.env').trim().split('\n')
                        def envMap = envData.collectEntries { line ->
                            def (k, v) = line.split('=')
                            [(k): v]
                        }
                        echo "====== Building the frontend ======"
                        // Make sure that the container name is available
                        sh "docker stop ${FRONTEND} || true"
                        dir('SmartHomeDashboard'){
                            sh "docker build --build-arg VITE_API_URL=${NGINX}:5200 -t ${DOCKER_USERNAME}/${FRONTEND}:V${envMap.FRONTEND_TAG}_dirty ."
                        }
                    }
                }
                stage("Building simulator"){
                    steps{
                        def envData = readFile('metadata.env').trim().split('\n')
                        def envMap = envData.collectEntries { line ->
                            def (k, v) = line.split('=')
                            [(k): v]
                        }
                        echo "====== Building the simulator ======"
                        // Make sure that the container name is available
                        sh "docker stop ${SIMULATOR} || true"
                        dir('SmartHomeSimulator'){
                            sh "docker build -t ${DOCKER_USERNAME}/${SIMULATOR}:V${envMap.SIMULATOR_TAG} ."
                        }
                    }
                }
                stage("Building grafana"){
                    steps{
                        def envData = readFile('metadata.env').trim().split('\n')
                        def envMap = envData.collectEntries { line ->
                            def (k, v) = line.split('=')
                            [(k): v]
                        }
                        echo "====== Building grafana ======"
                        // Make sure that the container name is available
                        sh "docker stop ${GRAFANA} || true"
                        dir('SmartHomeConfig/monitoring/grafana'){
                            sh "docker build -t ${DOCKER_USERNAME}/${GRAFANA}:V${envMap.GRAFANA_TAG} ."
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
                sh """
                    docker stop mqtt-broker || true
                    docker rm -f mqtt-broker || true
                    
                    chmod 644 ${WORKSPACE}/SmartHomeConfig/mosquitto/mosquitto.conf
                    
                    docker run -d \\
                    --network test \\
                    --name mqtt-broker \\
                    eclipse-mosquitto

                    docker cp ${WORKSPACE}/SmartHomeConfig/mosquitto/mosquitto.conf mqtt-broker:/mosquitto/config/mosquitto.conf
                    docker restart mqtt-broker
                    docker exec mqtt-broker cat /mosquitto/config/mosquitto.conf

                    sleep 3
                """
            }
        }
        stage("Unit test the backend"){
            steps{
                def envData = readFile('metadata.env').trim().split('\n')
                def envMap = envData.collectEntries { line ->
                    def (k, v) = line.split('=')
                    [(k): v]
                }
                echo "====== Running the backend ======"
                sh """
                    docker run -d -p 8000:8000 --env-file SmartHomeBackend/.env \\
                    --network test --name ${FLASK} ${DOCKER_USERNAME}/${FLASK}:V${envMap.FLASK_TAG}

                    docker run -d -p 5200:5200 -e FLASK_BACKEND_HOST=${FLASK} --network test --name ${NGINX} \\
                    ${DOCKER_USERNAME}/${NGINX}:V${envMap.NGINX_TAG}

                """
                echo "====== Testing the backend ======"

                sh """
                    docker exec ${FLASK} sh -c "which curl || (apk update && apk add curl)"
                    i=1
                    while [ \$i -le 10 ]; do
                        echo "Attempt \$i: Checking if Flask is ready..."
                        if docker exec ${FLASK} curl -s --fail http://localhost:8000/ready; then
                            break
                        fi
                        i=\$((i + 1))
                        sleep 5
                    done

                    # Final check to fail if still not up
                    docker exec ${FLASK} curl -s --fail http://localhost:8000/ready || { docker logs ${FLASK} && exit 1; }
                """
                sh """
                    i=1
                    while [ \$i -le 10 ]; do
                        echo "Attempt \$i: Checking if nginx is ready..."
                        if docker exec ${NGINX} curl -s http://localhost:5200/ready; then
                            break
                        fi
                        i=\$((i + 1))
                        sleep 5
                    done

                    # Final check to fail if still not up
                    docker exec ${NGINX} curl -s http://localhost:5200/ready || { docker logs ${NGINX} && exit 1; }
                """
                script{
                    if (envMap.FLASK_IS_NEW == "true") {
                        sh "docker exec ${FLASK} python -m unittest discover -s /app/test -p \"test_*.py\" -v || { docker logs ${FLASK} && exit 1 }"
                    } else {
                        echo "Flask isn't new, skipping unit tests."
                    }
                }
            }
        }
        stage("Unit test dependencies"){
            steps{
                def envData = readFile('metadata.env').trim().split('\n')
                def envMap = envData.collectEntries { line ->
                    def (k, v) = line.split('=')
                    [(k): v]
                }
                parallel{
                    stage("Testing the simulator"){
                        steps{
                            echo "====== Running the simulator ======"
                            sh """
                            docker run -d --env-file SmartHomeSimulator/.env \\
                            --network test --name ${SIMULATOR} ${DOCKER_USERNAME}/${SIMULATOR}:V${envMap.SIMULATOR_TAG}
                            """
                            echo "====== Testing the simulator ======"
                            sh """"
                                i=1
                                while [ \$i -le 10 ]; do
                                    echo "Attempt \$i: Checking if simulator is ready..."
                                    if docker exec ${SIMULATOR} cat status | grep ready; then
                                        break
                                    fi
                                    i=\$((i + 1))
                                    sleep 5
                                done

                                # Final check to fail if still not up
                                docker exec ${SIMULATOR} cat status | grep ready || { docker logs ${SIMULATOR} && docker logs ${FLASK} && exit 1; }
                            """
                            script{
                                if (envMap.SIMULATOR_IS_NEW == "true") {
                                    sh "docker exec ${SIMULATOR} python -m unittest discover -s /app/test -p \"test_*.py\" -v || { docker logs ${SIMULATOR} && exit 1 }"
                                } else {
                                    echo "Simulator is not new, skipping unit tests"
                                }
                            }
                        }
                    }
                    stage("Testing the frontend"){
                        steps{
                            echo "====== Running the frontend ======"
                            sh """
                            docker run -d -p 3001:3001 --network test --env-file SmartHomeDashboard/.env --name ${FRONTEND} \\
                            ${DOCKER_USERNAME}/${FRONTEND}:V${envMap.FRONTEND_TAG}
                            """
                            echo "====== Testing the frontend ======"
                            sh """
                                i=1
                                while [ \$i -le 10 ]; do
                                    echo "Attempt \$i: Checking if frontend can reach backend..."
                                    if docker exec ${FRONTEND} curl -s http://${NGINX}:5200/ready; then
                                        break
                                    fi
                                    i=\$((i + 1))
                                    sleep 5
                                done

                                # Final check to fail if still not up
                                docker exec ${FRONTEND} curl -s http://${NGINX}:5200/ready || { docker logs ${FRONTEND} && exit 1; }
                            """
                            dir('SmartHomeDashboard'){
                                sh "npm ci"
                                sh "npm test -- --ci --coverage"
                            }
                        }
                    }
                    stage("Testing grafana"){
                        steps{
                            echo "====== Running grafana ======"
                            sh """
                            docker run -d --network test --name ${GRAFANA} \\
                            ${DOCKER_USERNAME}/${GRAFANA}:V${envMap.GRAFANA_TAG}
                            """
                            echo "====== Testing grafana ======"
                            sh """
                                i=1
                                while [ \$i -le 10 ]; do
                                    echo "Attempt \$i: Checking if grafana is ready..."
                                    if docker exec ${GRAFANA} curl http://localhost:3000/api/health; then
                                        break
                                    fi
                                    i=\$((i + 1))
                                    sleep 5
                                done

                                # Final check to fail if still not up
                                docker exec ${GRAFANA} curl http://localhost:3000/api/health || { docker logs ${GRAFANA} && exit 1; }
                            """
                        }
                    }
                }
            }
        }
        stage("Integration test"){
            steps{
                // Skip if none are new
                sh """
                docker exec -e FRONTEND_URL=http://${FRONTEND}:3001 -e BACKEND_URL=http://${NGINX}:5200 \\
                -e GRAFANA_URL=http://${GRAFANA}:3000 ${FLASK} python test/integration_test.py || { docker logs ${FLASK} && docker logs ${SIMULATOR} && exit 1; }
                """
            }
        }
        stage("Build clean frontend"){
            steps{
                def envData = readFile('metadata.env').trim().split('\n')
                def envMap = envData.collectEntries { line ->
                    def (k, v) = line.split('=')
                    [(k): v]
                }
                script{
                    if (envMap.FRONTEND_IS_NEW == "true"){
                        dir('SmartHomeDashboard'){
                            sh "docker rm -f ${FRONTEND} || true"
                            sh "docker rmi -f ${DOCKER_USERNAME}/${FRONTEND}:V${envMap.FRONTEND_TAG} || true"
                            sh "docker build -t ${DOCKER_USERNAME}/${FRONTEND}:V${envMap.FRONTEND_TAG} ."
                        }
                    } else {
                        echo "Frontend isn't new, skipping clean build."
                    }
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
            steps{
                def envData = readFile('metadata.env').trim().split('\n')
                def envMap = envData.collectEntries { line ->
                    def (k, v) = line.split('=')
                    [(k): v]
                }
                parallel{
                    stage("Deploying backend"){
                        steps{
                            echo "====== Deploying the backend ======"
                            sh "docker image tag ${DOCKER_USERNAME}/${FLASK}:V${envMap.FLASK_TAG} ${DOCKER_USERNAME}/${FLASK}:latest"
                            sh "docker image tag ${DOCKER_USERNAME}/${NGINX}:V${envMap.NGINX_TAG} ${DOCKER_USERNAME}/${NGINX}:latest"
                            script{
                                if (envMap.NGINX_IS_NEW == "true"){
                                    retry(4){
                                        sh "docker push ${DOCKER_USERNAME}/${NGINX}:latest"
                                    }
                                    retry(4){
                                        sh "docker push ${DOCKER_USERNAME}/${NGINX}:V${envMap.NGINX_TAG}"
                                    }
                                } else {
                                    echo "NGINX isn't new, skipping deployment."
                                }
                            }
                            script{
                                if (envMap.FLASK_IS_NEW == "true"){
                                    retry(4){
                                        sh "docker push ${DOCKER_USERNAME}/${FLASK}:latest"
                                    }
                                    retry(4){
                                        sh "docker push ${DOCKER_USERNAME}/${FLASK}:V${envMap.FLASK_TAG}"
                                    }
                                } else {
                                    echo "Flask isn't new, skipping deployment."
                                }
                            }
                        }
                    }
                    stage("Deploying frontend"){
                        steps{
                            echo "====== Deploying the frontend ======"
                            sh "docker image tag ${DOCKER_USERNAME}/${FRONTEND}:V${envMap.FRONTEND_TAG} ${DOCKER_USERNAME}/${FRONTEND}:latest"
                            script{
                                if (envMap.FRONTEND_IS_NEW == "true"){                        
                                    retry(4){
                                        sh "docker push ${DOCKER_USERNAME}/${FRONTEND}:latest"
                                    }
                                    retry(4){
                                        sh "docker push ${DOCKER_USERNAME}/${FRONTEND}:V${envMap.FRONTEND_TAG}"
                                    }
                                } else {
                                    echo "Frontend isn't new, skipping deployment."
                                }
                            }
                        }
                    }
                    stage("Deploying simulator"){
                        steps{
                            echo "====== Deploying the simulator ======"
                            sh "docker image tag ${DOCKER_USERNAME}/${SIMULATOR}:V${envMap.SIMULATOR_TAG} ${DOCKER_USERNAME}/${SIMULATOR}:latest"
                            script{
                                if (envMap.SIMULATOR_IS_NEW == "true"){
                                    retry(4){
                                        sh "docker push ${DOCKER_USERNAME}/${SIMULATOR}:latest"
                                    }
                                    retry(4){
                                        sh "docker push ${DOCKER_USERNAME}/${SIMULATOR}:V${envMap.SIMULATOR_TAG}"
                                    }
                                } else {
                                    echo "Simulator isn't new, skipping deployment."
                                }
                            }
                        }
                    }
                    stage("Deploying grafana"){
                        steps{
                            echo "====== Deploying grafana ======"
                            script{
                                if (envMap.GRAFANA_IS_NEW == "true"){
                                    sh "docker image tag ${DOCKER_USERNAME}/${GRAFANA}:V${envMap.GRAFANA_TAG} ${DOCKER_USERNAME}/${GRAFANA}:latest"
                                    retry(4){
                                        sh "docker push ${DOCKER_USERNAME}/${GRAFANA}:latest"
                                    }
                                    retry(4){
                                        sh "docker push ${DOCKER_USERNAME}/${GRAFANA}:V${envMap.GRAFANA_TAG}"
                                    }
                                } else{
                                    echo "Grafana isn't new, skipping deployment."
                                }
                            }
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
            sh "docker stop ${NGINX} || true"
            sh "docker stop ${FRONTEND} || true"
            sh "docker stop ${SIMULATOR} || true"
            sh "docker stop ${GRAFANA} || true"
            sh "docker rm -f mqtt-broker || true"
            sh "docker rm -f ${FLASK} || true"
            sh "docker rm -f ${NGINX} || true"
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
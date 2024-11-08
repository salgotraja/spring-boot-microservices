#!/usr/bin/env groovy
package jenkins

pipeline {
    agent any

    tools {
        maven "M3"
        jdk "jdk-21"
    }

    parameters {
        choice(
                name: 'BRANCH',
                choices: ['main', 'dev', 'staging', 'production'],
                description: 'Select the branch to build'
        )
    }

    environment {
        DEPLOY_DIR = '/var/jenkins_home/deploy'
        DOCKER_COMPOSE = '/usr/local/bin/docker-compose'
    }

    stages {
        stage('Debug Directory') {
            steps {
                sh """
                    echo "Current directory:"
                    pwd
                    
                    echo "Checking realm-config directory:"
                    ls -la ${DEPLOY_DIR}/realm-config || echo "realm-config directory not found"
                    
                    echo "Creating realm-config directory if not exists:"
                    mkdir -p ${DEPLOY_DIR}/realm-config
                    
                    echo "Checking if realm file exists:"
                    ls -la ${DEPLOY_DIR}/realm-config/bookstore-realm.json || echo "realm file not found"
                """
            }
        }

        stage('Checkout') {
            steps {
                git branch: "${params.BRANCH}", url: 'https://github.com/salgotraja/spring-boot-microservices.git'
            }
        }

        stage('Build') {
            steps {
                sh """
                    java -version
                    mvn -version
                    mvn clean package -Dmaven.test.failure.ignore=true
                """
            }
        }

        stage('Prepare Deploy') {
            steps {
                sh """
                    # Copy JARs
                    cp -v api-gateway/target/*.jar ${DEPLOY_DIR}/
                    cp -v catalog-service/target/*.jar ${DEPLOY_DIR}/
                    cp -v order-service/target/*.jar ${DEPLOY_DIR}/
                    cp -v notification-service/target/*.jar ${DEPLOY_DIR}/
                    cp -v bookstore-webapp/target/*.jar ${DEPLOY_DIR}/
                    
                    # Verify contents
                    echo "Contents of deploy directory:"
                    ls -la ${DEPLOY_DIR}
                    echo "Contents of realm-config directory:"
                    ls -la ${DEPLOY_DIR}/realm-config || echo "realm-config not found"
                """
            }
        }

        stage('Deploy Services') {
            steps {
                sh """
                    cd ${DEPLOY_DIR}
                    ${DOCKER_COMPOSE} down || true
                    ${DOCKER_COMPOSE} up -d
                    
                    echo "Waiting for services to start..."
                    sleep 10
                    
                    echo "Service status:"
                    ${DOCKER_COMPOSE} ps
                """
            }
        }
    }

    post {
        always {
            sh """
                echo "Final check of realm-config:"
                ls -la ${DEPLOY_DIR}/realm-config || echo "realm-config not found"
            """
        }
        success {
            echo """
            Deployment successful!
            Services should be available at:
            - API Gateway: http://localhost:8989
            - Catalog Service: http://localhost:8081
            - Order Service: http://localhost:8082
            - Notification Service: http://localhost:8083
            - Bookstore WebApp: http://localhost:8080
            - Keycloak: http://localhost:9191
            - RabbitMQ Management: http://localhost:15672
            - Mailhog: http://localhost:8025
            """
        }
        failure {
            echo "Deployment failed! Check the logs above for details."
        }
    }
}
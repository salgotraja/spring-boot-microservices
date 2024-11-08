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
        ARTIFACT_PATH = '/var/jenkins_home/artifacts'
        DEPLOY_PATH = '/var/jenkins_home/deploy'
    }

    stages {
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

        stage('Store Artifacts') {
            steps {
                sh """
                    # Ensure directories exist and have correct permissions
                    mkdir -p ${ARTIFACT_PATH}
                    mkdir -p ${DEPLOY_PATH}
                    
                    # Copy each JAR file individually to avoid globbing issues
                    cp api-gateway/target/*.jar ${ARTIFACT_PATH}/ || true
                    cp catalog-service/target/*.jar ${ARTIFACT_PATH}/ || true
                    cp order-service/target/*.jar ${ARTIFACT_PATH}/ || true
                    cp notification-service/target/*.jar ${ARTIFACT_PATH}/ || true
                    cp bookstore-webapp/target/*.jar ${ARTIFACT_PATH}/ || true
                    
                    # List the copied artifacts
                    echo "Copied artifacts:"
                    ls -l ${ARTIFACT_PATH}
                """
            }
        }
    }

    post {
        success {
            echo "Build successful! Artifacts stored in: ${ARTIFACT_PATH}"
        }
        failure {
            echo "Build failed! Check the logs for details"
        }
    }
}
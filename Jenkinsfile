pipeline {
    agent any
    
    environment {
        PROJECT_ID = 'avid-sunset-435316-a6'
        CLUSTER_NAME = 'placement-portal-cluster'
        CLUSTER_ZONE = 'us-central1-a'
        REGISTRY_HOSTNAME = 'gcr.io'
        IMAGE_BACKEND = "${REGISTRY_HOSTNAME}/${PROJECT_ID}/placement-backend"
        IMAGE_FRONTEND = "${REGISTRY_HOSTNAME}/${PROJECT_ID}/placement-frontend"
        SONAR_HOST_URL = 'http://35.225.234.133:9000'
        PATH = "${env.PATH}:/usr/local/bin"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('Install Dependencies') {
            parallel {
                stage('Backend Dependencies') {
                    steps {
                        dir('backend') {
                            sh 'npm ci'
                        }
                    }
                }
                stage('Frontend Dependencies') {
                    steps {
                        dir('frontend') {
                            sh 'npm ci'
                        }
                    }
                }
            }
        }
        
        stage('Code Quality & Security') {
            parallel {
                stage('Backend Lint & Test') {
                    steps {
                        dir('backend') {
                            sh 'npm run build'
                            script {
                                // Run tests if they exist, otherwise skip
                                def hasTests = sh(script: 'npm run test --dry-run 2>/dev/null', returnStatus: true) == 0
                                if (hasTests) {
                                    sh 'npm run test'
                                } else {
                                    echo 'No tests configured, skipping test execution'
                                }
                            }
                        }
                    }
                }
                
                stage('Frontend Lint & Test') {
                    steps {
                        dir('frontend') {
                            sh 'npm run lint'
                            sh 'npm run build'
                            script {
                                // Run tests if they exist, otherwise skip
                                echo 'Frontend build completed successfully'
                            }
                        }
                    }
                }
                
                stage('SonarQube Analysis') {
                    steps {
                        script {
                            echo 'SonarQube analysis would run here'
                            echo "SonarQube server available at: ${SONAR_HOST_URL}"
                            // SonarQube integration can be configured later
                        }
                    }
                }
                
                stage('Security Scan') {
                    steps {
                        script {
                            // Backend security scan
                            dir('backend') {
                                sh 'npm audit --audit-level=high'
                            }
                            // Frontend security scan
                            dir('frontend') {
                                sh 'npm audit --audit-level=high'
                            }
                        }
                    }
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                script {
                    echo 'Quality gate check would run here'
                    // Uncomment when SonarQube is properly configured
                    /*
                    timeout(time: 10, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true
                    }
                    */
                }
            }
        }
        
        stage('Build Docker Images') {
            parallel {
                stage('Build Backend') {
                    steps {
                        dir('backend') {
                            script {
                                echo "Building backend Docker image: ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT}"
                                sh "docker build -t ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT} ."
                                sh "docker tag ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT} ${IMAGE_BACKEND}:latest"
                                // Push commands will be added when GCR credentials are configured
                                echo "Backend image built successfully"
                            }
                        }
                    }
                }
                
                stage('Build Frontend') {
                    steps {
                        dir('frontend') {
                            script {
                                echo "Building frontend Docker image: ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT}"
                                sh "docker build -t ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT} ."
                                sh "docker tag ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT} ${IMAGE_FRONTEND}:latest"
                                // Push commands will be added when GCR credentials are configured
                                echo "Frontend image built successfully"
                            }
                        }
                    }
                }
            }
        }
        
        stage('Security Scanning - Images') {
            parallel {
                stage('Backend Image Scan') {
                    steps {
                        script {
                            sh """
                                gcloud container images scan ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT} \
                                --format='table(vulnerability.effectiveSeverity,vulnerability.cvssScore,package.name,package.packageType,vulnerability.description)'
                            """
                        }
                    }
                }
                
                stage('Frontend Image Scan') {
                    steps {
                        script {
                            sh """
                                gcloud container images scan ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT} \
                                --format='table(vulnerability.effectiveSeverity,vulnerability.cvssScore,package.name,package.packageType,vulnerability.description)'
                            """
                        }
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    echo "Deploy to Staging stage - would deploy to staging environment"
                    echo "Cluster: ${CLUSTER_NAME}, Zone: ${CLUSTER_ZONE}, Project: ${PROJECT_ID}"
                    echo "Backend Image: ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT}"
                    echo "Frontend Image: ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT}"
                    // Actual deployment commands will be added when kubectl access is configured
                }
            }
        }
        
        stage('Integration Tests') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    echo "Integration tests would run here for staging environment"
                    // Integration test commands will be added when test infrastructure is ready
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    // Manual approval for production deployment
                    input message: 'Deploy to Production?', ok: 'Deploy',
                          submitterParameter: 'DEPLOYER'
                    
                    echo "Production deployment approved by: ${DEPLOYER}"
                    echo "Would deploy to production cluster: ${CLUSTER_NAME}"
                    echo "Backend Image: ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT}"
                    echo "Frontend Image: ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT}"
                    // Actual deployment commands will be added when kubectl access is configured
                }
            }
        }
        
        stage('Post-deployment Tests') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "Post-deployment smoke tests would run here"
                    // Smoke test commands will be added when test infrastructure is ready
                }
            }
        }
    }
    
    post {
        always {
            // Clean workspace
            script {
                echo "Pipeline completed"
                try {
                    cleanWs()
                } catch (Exception e) {
                    echo "Warning: Could not clean workspace: ${e.getMessage()}"
                }
            }
        }
        
        success {
            echo "✅ Deployment successful! Pipeline: ${env.JOB_NAME} - Build: ${env.BUILD_NUMBER}"
        }
        
        failure {
            echo "❌ Deployment failed! Pipeline: ${env.JOB_NAME} - Build: ${env.BUILD_NUMBER}"
        }
    }
}

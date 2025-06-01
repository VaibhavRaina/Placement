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
        KUBECONFIG = credentials('kubeconfig')
    }
    
    tools {
        nodejs '18'
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
                                def image = docker.build("${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT}")
                                docker.withRegistry("https://${REGISTRY_HOSTNAME}", 'gcr:service-account') {
                                    image.push()
                                    image.push('latest')
                                }
                            }
                        }
                    }
                }
                
                stage('Build Frontend') {
                    steps {
                        dir('frontend') {
                            script {
                                def image = docker.build("${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT}")
                                docker.withRegistry("https://${REGISTRY_HOSTNAME}", 'gcr:service-account') {
                                    image.push()
                                    image.push('latest')
                                }
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
                    sh """
                        gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${CLUSTER_ZONE} --project ${PROJECT_ID}
                        
                        # Create staging namespace if it doesn't exist
                        kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
                        
                        # Update image tags in deployment files
                        sed -i 's|IMAGE_TAG|${env.GIT_COMMIT_SHORT}|g' k8s/staging/*.yaml
                        sed -i 's|PROJECT_ID|${PROJECT_ID}|g' k8s/staging/*.yaml
                        
                        # Apply staging configurations
                        kubectl apply -f k8s/staging/ -n staging
                        
                        # Wait for deployments to complete
                        kubectl rollout status deployment/placement-backend -n staging --timeout=300s
                        kubectl rollout status deployment/placement-frontend -n staging --timeout=300s
                    """
                }
            }
        }
        
        stage('Integration Tests') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    sh """
                        # Get staging service URLs
                        BACKEND_URL=\$(kubectl get service placement-backend-service -n staging -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                        FRONTEND_URL=\$(kubectl get service placement-frontend-service -n staging -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                        
                        # Run integration tests
                        npm run test:integration -- --backend-url=http://\$BACKEND_URL:5000 --frontend-url=http://\$FRONTEND_URL
                    """
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
                    
                    sh """
                        gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${CLUSTER_ZONE} --project ${PROJECT_ID}
                        
                        # Update image tags in deployment files
                        sed -i 's|IMAGE_TAG|${env.GIT_COMMIT_SHORT}|g' k8s/*.yaml
                        sed -i 's|PROJECT_ID|${PROJECT_ID}|g' k8s/*.yaml
                        
                        # Apply production configurations
                        kubectl apply -f k8s/
                        
                        # Wait for deployments to complete
                        kubectl rollout status deployment/placement-backend --timeout=600s
                        kubectl rollout status deployment/placement-frontend --timeout=600s
                        
                        # Verify deployment
                        kubectl get pods -l app=placement-backend
                        kubectl get pods -l app=placement-frontend
                    """
                }
            }
        }
        
        stage('Post-deployment Tests') {
            when {
                branch 'main'
            }
            steps {
                script {
                    sh """
                        # Get production service URLs
                        BACKEND_URL=\$(kubectl get service placement-backend-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                        FRONTEND_URL=\$(kubectl get service placement-frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                        
                        # Run smoke tests
                        npm run test:smoke -- --backend-url=http://\$BACKEND_URL:5000 --frontend-url=http://\$FRONTEND_URL
                    """
                }
            }
        }
    }
    
    post {
        always {
            // Clean up Docker images
            sh """
                docker rmi ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT} || true
                docker rmi ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT} || true
                docker system prune -f
            """
            
            // Archive test results
            publishTestResults testResultsPattern: '**/test-results.xml'
            
            // Clean workspace
            cleanWs()
        }
        
        success {
            slackSend channel: '#deployment',
                     color: 'good',
                     message: "✅ Deployment successful! Pipeline: ${env.JOB_NAME} - Build: ${env.BUILD_NUMBER}"
        }
        
        failure {
            slackSend channel: '#deployment',
                     color: 'danger',
                     message: "❌ Deployment failed! Pipeline: ${env.JOB_NAME} - Build: ${env.BUILD_NUMBER}"
        }
    }
}

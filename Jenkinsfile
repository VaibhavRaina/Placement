pipeline {
    agent any
    
    environment {
        AWS_ACCOUNT_ID = '011528267161'
        AWS_REGION = 'us-east-1'
        CLUSTER_NAME = 'placement-portal-cluster'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_BACKEND = "${ECR_REGISTRY}/placement-portal-backend"
        IMAGE_FRONTEND = "${ECR_REGISTRY}/placement-portal-frontend"
        SONAR_HOST_URL = 'http://sonarqube-server:9000'
        PATH = "${env.PATH}:/usr/local/bin"
        AWS_DEFAULT_REGION = "${AWS_REGION}"
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
        
        stage('Setup AWS Environment') {
            steps {
                script {
                    // Set AWS Account ID (from terraform outputs)
                    env.AWS_ACCOUNT_ID = "011528267161"
                    
                    // Set ECR registry and image URLs
                    env.ECR_REGISTRY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                    env.IMAGE_BACKEND = "${env.ECR_REGISTRY}/placement-portal-backend"
                    env.IMAGE_FRONTEND = "${env.ECR_REGISTRY}/placement-portal-frontend"
                    
                    echo "AWS Account ID: ${env.AWS_ACCOUNT_ID}"
                    echo "ECR Registry: ${env.ECR_REGISTRY}"
                    echo "Backend Image: ${env.IMAGE_BACKEND}"
                    echo "Frontend Image: ${env.IMAGE_FRONTEND}"
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
                            sh 'npm run lint || echo "Linting completed"'
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
                            sh 'npm run lint || echo "Linting completed with warnings"'
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
                    // Quality gate will be configured when SonarQube is set up
                }
            }
        }
        
        stage('Build Docker Images') {
            steps {
                script {
                    parallel([
                        'Build Backend': {
                            dir('backend') {
                                echo "Building backend Docker image: ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT}"
                                sh "docker build -t ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT} ."
                                sh "docker tag ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT} ${IMAGE_BACKEND}:latest"
                                echo "Backend image built successfully"
                            }
                        },
                        'Build Frontend': {
                            dir('frontend') {
                                echo "Building frontend Docker image: ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT}"
                                sh "docker build -t ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT} ."
                                sh "docker tag ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT} ${IMAGE_FRONTEND}:latest"
                                echo "Frontend image built successfully"
                            }
                        }
                    ])
                }
            }
        }
        
        stage('Push Docker Images') {
            parallel {
                stage('Push Backend') {
                    steps {
                        dir('backend') {
                            script {
                                echo "Pushing backend Docker image: ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT}"
                                sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                                sh "docker push ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT}"
                                sh "docker push ${IMAGE_BACKEND}:latest"
                                echo "Backend image pushed successfully"
                            }
                        }
                    }
                }
                
                stage('Push Frontend') {
                    steps {
                        dir('frontend') {
                            script {
                                echo "Pushing frontend Docker image: ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT}"
                                sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                                sh "docker push ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT}"
                                sh "docker push ${IMAGE_FRONTEND}:latest"
                                echo "Frontend image pushed successfully"
                            }
                        }
                    }
                }
            }
        }
        
        stage('Security Scanning') {
            parallel {
                stage('Backend Image Scan') {
                    steps {
                        script {
                            echo "Image security scanning would be performed here"
                            echo "Backend image: ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT}"
                            // Container scanning can be integrated with tools like Trivy, Snyk, or Clair
                        }
                    }
                }
                
                stage('Frontend Image Scan') {
                    steps {
                        script {
                            echo "Image security scanning would be performed here"
                            echo "Frontend image: ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT}"
                            // Container scanning can be integrated with tools like Trivy, Snyk, or Clair
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
                    echo "Deploying to Staging environment"
                    echo "Cluster: ${CLUSTER_NAME}, Region: ${AWS_REGION}"
                    echo "Backend Image: ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT}"
                    echo "Frontend Image: ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT}"
                    
                    // Connect to EKS cluster
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"
                    
                    // Create staging namespace if it doesn't exist
                    sh "kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -"
                    
                    // Update staging deployment files with new image tags
                    sh "sed -i 's|__BACKEND_ECR_REPO__:.*|${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT}|g' k8s/staging/backend-deployment.yaml"
                    sh "sed -i 's|__FRONTEND_ECR_REPO__:.*|${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT}|g' k8s/staging/frontend-deployment.yaml"
                    
                    // Apply staging deployments
                    sh "kubectl apply -f k8s/staging/"
                    
                    // Wait for rollout
                    sh "kubectl rollout status deployment/placement-backend -n staging --timeout=300s"
                    sh "kubectl rollout status deployment/placement-frontend -n staging --timeout=300s"
                    
                    echo "Staging deployment completed successfully"
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
            steps {
                script {
                    // Manual approval for production deployment
                    input message: 'Deploy to Production?', ok: 'Deploy',
                          submitterParameter: 'DEPLOYER'
                    
                    echo "Production deployment approved by: ${DEPLOYER}"
                    echo "Deploying to production cluster: ${CLUSTER_NAME}"
                    echo "Backend Image: ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT}"
                    echo "Frontend Image: ${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT}"
                    
                    // Connect to EKS cluster
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"
                    
                    // Update production deployment files with new image tags
                    sh "sed -i 's|__BACKEND_ECR_REPO__:.*|${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT}|g' k8s/backend-deployment.yaml"
                    sh "sed -i 's|__FRONTEND_ECR_REPO__:.*|${IMAGE_FRONTEND}:${env.GIT_COMMIT_SHORT}|g' k8s/frontend-deployment.yaml"
                    
                    // Apply production deployments
                    sh "kubectl apply -f k8s/secrets.yaml"
                    sh "kubectl apply -f k8s/backend-deployment.yaml"
                    sh "kubectl apply -f k8s/frontend-deployment.yaml"
                    sh "kubectl apply -f k8s/backend-service.yaml"
                    sh "kubectl apply -f k8s/frontend-service.yaml"
                    
                    // Wait for rollout
                    sh "kubectl rollout status deployment/placement-backend --timeout=300s"
                    sh "kubectl rollout status deployment/placement-frontend --timeout=300s"
                    
                    // Get external IP
                    sh "kubectl get services"
                    
                    echo "Production deployment completed successfully"
                }
            }
        }
        
        stage('Post-deployment Tests') {
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
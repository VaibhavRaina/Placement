pipeline {
  agent any

  environment {
    // SonarQube: configure these credentials in Jenkins Global Credentials
    SONAR_TOKEN = credentials('sonarqube-token')
    DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')
    SLACK_WEBHOOK_URL = credentials('slack-webhook-url')
    GCP_CREDENTIALS = credentials('gcp-service-account-key')  // GCP service account JSON key
    GCP_PROJECT_ID = 'your-gcp-project-id'                    // GCP project ID
    GCP_REGION = 'us-central1'                                 // Default GCP region
    CLUSTER_NAME = 'placement-cluster'                         // GKE cluster name
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Install Dependencies') {
      parallel {
        stage('Backend') {
          steps {
            dir('backend') {
              sh 'npm install'
            }
          }
        }
        stage('Frontend') {
          steps {
            dir('frontend') {
              sh 'npm install'
            }
          }
        }
      }
    }

    stage('Unit Tests') {
      parallel {
        stage('Backend Tests') {
          steps {
            dir('backend') {
              sh 'npm run test -- --coverage'
            }
          }
        }
        stage('Frontend Tests') {
          steps {
            dir('frontend') {
              sh 'npm run test -- --coverage'
            }
          }
        }
      }
      post {
        always {
          junit 'backend/jest-results.xml'
          junit 'frontend/jest-results.xml'
        }
      }
    }

    stage('SonarQube Analysis') {
      steps {
        withSonarQubeEnv('SonarQube') {
          sh 'sonar-scanner \
            -Dsonar.projectKey=placement-platform \
            -Dsonar.sources=. \
            -Dsonar.tests=backend,frontend \
            -Dsonar.typescript.lcov.reportPaths=frontend/coverage/lcov.info,backend/coverage/lcov.info \
            -Dsonar.login=$SONAR_TOKEN'
        }
      }
    }

    stage('Quality Gate') {
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    stage('Terraform Init & Plan') {
      steps {
        dir('infrastructure') {
          // Setup GCP authentication for Terraform
          sh 'echo "$GCP_CREDENTIALS" > gcp-key.json'
          sh 'export GOOGLE_APPLICATION_CREDENTIALS=$PWD/gcp-key.json'
          sh 'terraform init -input=false'
          sh 'terraform plan -out=tfplan -input=false'
        }
      }
    }

    stage('Terraform Apply') {
      steps {
        dir('infrastructure') {
          // Use GCP credentials file
          sh 'export GOOGLE_APPLICATION_CREDENTIALS=$PWD/gcp-key.json'
          sh 'terraform apply -input=false -auto-approve tfplan'
        }
      }
    }

    stage('Build & Push Docker') {
      parallel {
        stage('Backend Image') {
          steps {
            dir('backend') {
              sh 'docker build -t $DOCKERHUB_CREDENTIALS_USR/placement-backend:${env.BUILD_NUMBER} .'
              sh "docker login -u $DOCKERHUB_CREDENTIALS_USR -p $DOCKERHUB_CREDENTIALS_PSW"
              sh 'docker push $DOCKERHUB_CREDENTIALS_USR/placement-backend:${env.BUILD_NUMBER}'
            }
          }
        }
        stage('Frontend Image') {
          steps {
            dir('frontend') {
              sh 'docker build -t $DOCKERHUB_CREDENTIALS_USR/placement-frontend:${env.BUILD_NUMBER} .'
              sh "docker login -u $DOCKERHUB_CREDENTIALS_USR -p $DOCKERHUB_CREDENTIALS_PSW"
              sh 'docker push $DOCKERHUB_CREDENTIALS_USR/placement-frontend:${env.BUILD_NUMBER}'
            }
          }
        }
      }
    }

    stage('Deploy to GKE') {
      steps {
        dir('infrastructure') {
          // authenticate gcloud
          sh 'echo "$GCP_CREDENTIALS" > gcp-key.json'
          sh 'gcloud auth activate-service-account --key-file=gcp-key.json'
          sh 'gcloud container clusters get-credentials $CLUSTER_NAME --region $GCP_REGION --project $GCP_PROJECT_ID'
        }
        dir('k8s') {
          sh 'kubectl apply -f backend-deployment.yaml'
          sh 'kubectl apply -f backend-service.yaml'
          sh 'kubectl apply -f frontend-deployment.yaml'
          sh 'kubectl apply -f frontend-service.yaml'
        }
      }
    }
  }

  post {
    success {
      slackSend(channel: '#ci-cd-notifications', color: 'good', message: "Build ${env.JOB_NAME} #${env.BUILD_NUMBER} succeeded: ${env.BUILD_URL}")
    }
    failure {
      slackSend(channel: '#ci-cd-notifications', color: 'danger', message: "Build ${env.JOB_NAME} #${env.BUILD_NUMBER} failed: ${env.BUILD_URL}")
    }
  }
}

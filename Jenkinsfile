pipeline {
    agent any

    environment {
        DOCKER_HUB_CREDENTIALS = 'dockerhub-credentials'
        DOCKER_IMAGE_NAME = 'mujimmy/lab-app'
        GITHUB_REPO_URL = 'https://github.com/mujemi26/jenkins.git'
        KIND_CLUSTER_NAME = 'kind-kind'
        KUBECONFIG_FILE = 'kind-kubeconfig'
    }

    stages {
        stage('Validate Environment') {
            steps {
                sh '''
                    echo "Validating environment..."
                    docker version
                    kubectl version --client
                    kind version

                    echo "Checking KIND cluster status..."
                    kind get clusters
                '''
            }
        }

        stage('Checkout Code') {
            steps {
                checkout scm // Automatically checks out the branch
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh """
                        echo "Building Docker image: ${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}"
                        docker build -t ${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER} .
                    """
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    withDockerRegistry([credentialsId: 'dockerhub-credentials', url: '']) {
                        sh """
                            echo "Pushing Docker image to Docker Hub..."
                            docker push ${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}
                            docker tag ${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER} ${DOCKER_IMAGE_NAME}:latest
                            docker push ${DOCKER_IMAGE_NAME}:latest
                        """
                    }
                }
            }
        }

        stage('Deploy to Kind Cluster') {
            steps {
                script {
                    // Determine namespace based on branch name
                    def namespace = ''
                    if (env.BRANCH_NAME == 'dev') {
                        namespace = 'dev'
                    } else if (env.BRANCH_NAME == 'staging') {
                        namespace = 'staging'
                    } else if (env.BRANCH_NAME == 'production') {
                        namespace = 'production'
                    } else {
                        error "Unsupported branch: ${env.BRANCH_NAME}"
                    }

                    withCredentials([file(credentialsId: 'kind-kubeconfig', variable: 'KUBECONFIG_FILE')]) {
                        sh """
                            # Set KUBECONFIG
                            export KUBECONFIG=${KUBECONFIG_FILE}

                            # Load image into KIND cluster
                            kind load docker-image ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} --name ${KIND_CLUSTER_NAME}

                            # Create namespace if it doesn't exist
                            kubectl get namespace ${namespace} || kubectl create namespace ${namespace}

                            # Generate deployment YAML dynamically
                            cat > deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lab-app-deployment
  namespace: ${namespace}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: lab-app
  template:
    metadata:
      labels:
        app: lab-app
    spec:
      containers:
      - name: lab-app
        image: ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}
        ports:
        - containerPort: 80
EOF

                            # Apply deployment YAML
                            kubectl apply -f deployment.yaml

                            # Wait for deployment rollout
                            kubectl rollout status deployment/lab-app-deployment -n ${namespace} --timeout=300s

                            echo "Deployment successful in namespace: ${namespace}"
                        """
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    def namespace = ''
                    if (env.BRANCH_NAME == 'dev') {
                        namespace = 'dev'
                    } else if (env.BRANCH_NAME == 'staging') {
                        namespace = 'staging'
                    } else if (env.BRANCH_NAME == 'production') {
                        namespace = 'production'
                    }

                    withCredentials([file(credentialsId: 'kind-kubeconfig', variable: 'KUBECONFIG_FILE')]) {
                        sh """
                            export KUBECONFIG=${KUBECONFIG_FILE}

                            echo "Checking pods in namespace: ${namespace}"
                            kubectl get pods -n ${namespace}

                            echo "Fetching logs for pods in namespace: ${namespace}"
                            for pod in \$(kubectl get pods -n ${namespace} -l app=lab-app -o name); do
                                echo "Logs for \$pod:"
                                kubectl logs \$pod -n ${namespace}
                            done
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully."
        }
        failure {
            echo "Pipeline failed. Debugging required."
        }
        always {
            cleanWs()
        }
    }
}

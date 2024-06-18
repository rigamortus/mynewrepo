pipeline {
    agent any
    
    environment {
        // Define AWS credentials for S3 bucket access
        AWS_ACCESS_KEY_ID = credentials('awscreds')
        AWS_SECRET_ACCESS_KEY = credentials('awscreds')
        GITLAB_CRED_ID = 'mygithubcreds'
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    // Global git configuration to disable SSL verification
                    sh 'git config --global http.sslVerify false'

                    // Checkout code from GitHub repository using credentials
                    checkout([$class: 'GitSCM', branches: [[name: 'master']], userRemoteConfigs: [[url: 'https://github.com/rigamortus/mynewrepo.git', credentialsId: env.GITLAB_CRED_ID]]])
                }
            }
        }

        stage('Terraform init') {
            steps {
                script {
                    // Initialize Terraform
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform plan') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    script {
                        // Plan Terraform changes with verbose output and save to file
                        sh 'terraform plan -out=tfplan | tee terraform_plan_output.txt'
                    }
                }
            }
        }

        stage('Terraform apply') {
            steps {
                timeout(time: 20, unit: 'MINUTES') {
                    script {
                        // Apply Terraform changes with verbose output
                        sh 'terraform apply -auto-approve tfplan | tee terraform_apply_output.txt'
                    }
                }
            }
        }

        stage('Serve HTML') {
            steps {
                // Serve HTML file using Python's SimpleHTTPServer
                sh 'api_url=$(terraform output -raw api_url)'
                sh 'sed -i "s|\${api_url}|$myapi|g" index.html'
                sh 'nohup python3 -m http.server 5050 > /dev/null 2>&1 &'
            }
        }
    }
}

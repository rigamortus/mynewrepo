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

        stage('Check AWS Credentials') {
            steps {
                script {
                    // Check if AWS credentials are correctly configured
                    sh 'aws sts get-caller-identity'
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
                        sh 'terraform plan -out=tfplan -input=false -no-color | tee terraform_plan_output.txt'
                    }
                }
            }
        }

        stage('Check Plan Output') {
            steps {
                script {
                    // Display the output of the terraform plan for diagnostics
                    sh 'cat terraform_plan_output.txt'
                }
            }
        }

        stage('Terraform apply') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    script {
                        // Apply Terraform changes with verbose output
                        sh 'terraform apply -auto-approve -input=false tfplan | tee terraform_apply_output.txt'
                    }
                }
            }
        }

        stage('Check Apply Output') {
            steps {
                script {
                    // Display the output of the terraform apply for diagnostics
                    sh 'cat terraform_apply_output.txt'
                }
            }
        }

        stage('Serve HTML') {
            steps {
                // Serve HTML file using Python's SimpleHTTPServer
                sh 'nohup python3 -m http.server 5050 > /dev/null 2>&1 &'
            }
        }
    }
}

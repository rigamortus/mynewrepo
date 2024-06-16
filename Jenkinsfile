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
                // Checkout into repository
                script {
                    // global git configuration to disable SSL verification
                    sh 'git config --global http.sslVerify false'

                    // Checkout code from GitLab repository using credentials
                    checkout([$class: 'GitSCM', branches: [[name: 'master']], userRemoteConfigs: [[url: 'https://github.com/rigamortus/lambdas3.git', credentialsId: env.GITLAB_CRED_ID]]])
                }

            }
        }

        

        stage('Terraform init') {
            steps {
                script {
                   
                    // Plan and apply Terraform changes
                    sh 'terraform init'

                }
            }
        }


        stage('Terraform plan') {
            steps {
                script {
                   
                    // Plan and apply Terraform changes
                    sh 'terraform plan -out=tfplan'

                }
            }
        }

        stage('Terraform apply') {
            steps {
                script {
                    sh 'terraform apply -auto-approve tfplan | tee terraform_apply_output.txt'
                    // sh 'api_url=$(grep -oP "(?<=api_url = ).*" terraform_apply_output.txt)'
                    // sh 'sed -i "s|API_GATEWAY_ENDPOINT|$api_url|g" index.html'
                }
            }
        }

  

        stage('Serve HTML') {
            steps {
                // Serve HTML file using Python's SimpleHTTPServer
                sh 'nohup python -m SimpleHTTPServer 5050 > /dev/null 2>&1 &'
            }
        }
    }
}
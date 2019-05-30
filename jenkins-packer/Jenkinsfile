pipeline {
    agent any
    environment {
        YC_ACCOUNT_KEY_FILE = credentials('YC_ACCOUNT_KEY_FILE')
        YC_FOLDER_ID = credentials('YC_FOLDER_ID')
        YC_SUBNET_ID = credentials('YC_SUBNET_ID')

        PACKER_SH = '/opt/yandex-packer/packer build -color=false'
    }
    stages {
        stage('Core') {
            steps {
                sh label: '', script: "${env.PACKER_SH} ./jenkins-packer/packer/base.json"
            }
        }
        stage('Role-Based') {
            steps {
                parallel(
                    nginx: {
                        sh label: '', script: "${env.PACKER_SH} ./jenkins-packer/packer/nginx.json"
                    },
                    django: {
                        sh label: '', script: "${env.PACKER_SH} ./jenkins-packer/packer/django.json" 
                    }
                )
            }
        }
    }
}


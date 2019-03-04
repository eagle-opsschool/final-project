/*
    This is an example pipeline that implement full CI/CD for a simple static web site packed in a Docker image.

    The pipeline is made up of 6 main steps
    1. Git clone and setup
    2. Build and local tests
    3. Publish Docker and Helm
    4. Deploy to dev and test
    5. Deploy to staging and test
    6. Optionally deploy to production and test
 */

/*
    Check if the last commit contained a change to our pod def.
 */
def checkFolderForDiffs(path) {

}

/*
    Run a curl against a given url
 */
def curlRun (url, out) {
    echo "Running curl on ${url}"

    script {
        if (out.equals('')) {
            out = 'http_code'
        }
        echo "Getting ${out}"
            def result = sh (
                returnStdout: true,
                script: "curl --output /dev/null --silent --connect-timeout 5 --max-time 5 --retry 5 --retry-delay 5 --retry-max-time 30 --write-out \"%{${out}}\" ${url}"
        )
        echo "Result (${out}): ${result}"
    }
}

/*
    Test with a simple curl and check we get 200 back
 */
def curlTest (namespace, out) {
    echo "Running tests in ${namespace}"

    script {
        if (out.equals('')) {
            out = 'http_code'
        }

        // Get deployment's service IP
        def svc_ip = sh (
                returnStdout: true,
                script: "kubectl get svc -n ${namespace} | grep ${ID} | awk '{print \$3}'"
        )

        if (svc_ip.equals('')) {
            echo "ERROR: Getting service IP failed"
            sh 'exit 1'
        }

        echo "svc_ip is ${svc_ip}"
        url = 'http://' + svc_ip

        curlRun (url, out)
    }
}

/*
    This is the main pipeline section with the stages of the CI/CD
 */
pipeline {
    options {
        // Build auto timeout
        timeout(time: 60, unit: 'MINUTES')
    }

    // In this example, all is built and run from the master
    agent { node { label 'master' } }
    
    // Pipeline stages
    stages {
        ////////// Step 1 //////////
        stage('Git clone and setup') {
            steps {
                echo "Pulling from git"
                sh "git clone https://github.com/eagle-opsschool/final-project.git"

                echo "Checking if there were changes since last commit."
                // git diff will return 1 for changes (failure) which is caught in catch, or 0 meaning no changes 
                try {
                    sh "cd final-project/ansible; git diff --quiet --exit-code HEAD~1..HEAD group_vars/k8s"//roles/k8s/templates/mediawiki.yml"
                    return false
                } catch (err) {
                    return true
                }
                //checkFolderForDiffs()

                ID = "mediawiki-test-${DOCKER_TAG}"
            }
        }

        ////////// Step 2 //////////
        stage('Build and tests') {
            steps {
                echo "Downloading required mediawiki to our private registy"
                sh "cd ~/final-project/ansible; ansible-playbook site.yml -l k8s-master -t registry"
                   
//                    echo "Buildind application and Docker image"
//                    sh "ssh ubuntu@10.0.0.101 cd ~/final-project/ansible && "

                echo "Starting container for test" //TODO
                sh "docker run --detach --name ${ID} --rm --publish 56432:80 localhost:5000/mediawiki:{{ mediawiki_version }}:${DOCKER_TAG}"

                script {
                    host_ip = sh(returnStdout: true, script: '/sbin/ip route | awk \'/default/ { print $3 ":56432" }\'')
                }
            }
        }

        // Run the test on the currently running ACME Docker container
        stage('Local tests') {
            steps {
                curlRun ("${host_ip}", 'http_code')
                echo "Stop and remove container"
                sh "docker stop ${ID}"
            }
            
        }

        ////////// Step 4 //////////
        stage('Deploy test version') {
            steps {
                script {
                    namespace = 'development'

                    echo "Deploying application ${ID} to ${namespace} namespace"
                    createNamespace (namespace)

                    echo "Deploying"
                }
            }
        }

        // Run the 3 tests on the deployed Kubernetes pod and service
        stage('Test test vesion') {
            steps {
                 curlTest (namespace, 'http_code')
            }
        }


        ////////// Step 6 //////////
        stage('Deploy production version') {
            steps {
                script {
                    namespace = 'production'

                    echo "Deploying application ${IMAGE_NAME}:${DOCKER_TAG} to ${namespace} namespace"
                    createNamespace (namespace)

                    echo "Deploying"
                }
            }
        }

        // Run the 3 tests on the deployed Kubernetes pod and service
        stage('Production tests') {
            steps {
                curlRun ({{ haproxy_ip }}, 'http_code')
            }
        }
    }
    
	post {
        always {
            echo "Deleting git repo"
            sh "rm -rf final-project"
        }
    }
}

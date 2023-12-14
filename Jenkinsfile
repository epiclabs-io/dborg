node {

		env.GIT_BRANCH = "origin/${BRANCH_NAME}"
		env.BRANCH_NAME = "${BRANCH_NAME}"
		
		stage 'Checkout'
		checkout scm

		stage 'Build'
            ansiColor('xterm') {

            sh '''#!/bin/bash
            
            docker run -e GIT_BRANCH="$GIT_BRANCH" -v /var/run/docker.sock:/var/run/docker.sock -v $PWD:/src/ ecid/toolkit build.sh --fast

            '''
            }

		stage 'Push'

		
		
		withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'epicautobot-dockerhub',
                            usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD']]) {
		
		sh	'''#!/bin/bash
							
				docker run -e GIT_BRANCH="$GIT_BRANCH" -v /var/run/docker.sock:/var/run/docker.sock -v $PWD:/src/ -e REGISTRY_USERNAME=$USERNAME -e REGISTRY_PASSWORD=$PASSWORD "ecid/toolkit:$BRANCH_NAME" push-all.sh

						
			'''

			}		



}
#!/bin/bash
echo "Commencing Part 1 execution --- "
# Exit immediately incase of non zero status return
Set -e

# Get the cloud foundry public key and add the repository
wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add -
echo "deb http://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list

# Update the local package index, then install the cf CLI
sudo apt-get update
sudo apt-get install cf-cli

# Login to Cloud Foundry
cf api $CF_API #Use the cf api command to set the api endpoint
cf login -u $CF_USERNAME -p $CF_PASSWORD -o $CF_ORGANIZATION -s $CF_SPACE

# Get the script path to execute the script
pushd `dirname $0` > /dev/null
popd > /dev/null

echo "Part 1 to get the Travis environment ready - Completed successfully"

#Set the application name in BLUE variable
BLUE=$CF_APP 

#Green variable will store a temporary name for the application 
GREEN="${BLUE}-B"

#Remove manifest information stored in the temporary directory
finally ()
{
  rm $MANIFEST
}

#Inform that the deployment has failed for some reason
on_fail () {
  finally
  echo "DEPLOY FAILED - you may need to check 'cf apps' and 'cf routes' and do manual cleanup"
}

# pull the up-to-date manifest from the BLUE (existing) application
MANIFEST=$(mktemp -t "${BLUE}_manifestXXXX.temp")

#Create the new manifest file for deployment
echo "This is the manifest file and blue app: ${BLUE} and ${MANIFEST}" 
cf create-app-manifest $BLUE -p $MANIFEST

#Find and replace the application name (to the name stored in green variable) in the manifest file
sed -i -e "s/: ${BLUE}/: ${GREEN}/g" $MANIFEST
sed -i -e "s?path: ?path: $CURRENTPATH/?g" $MANIFEST

trap on_fail ERR

#Prepare the URL of the green application
DOMAIN=$CF_DOMAIN
cf push -f $MANIFEST 
GREENURL=https://${GREEN}.${DOMAIN}

#Check the URL to find if it fails
curl --fail -I -k $GREENURL

#Reroute the application URL to the green process
cf routes | tail -n +4 | grep $BLUE | awk '{print $3" -n "$2}' | xargs -n 3 cf map-route $GREEN

#Perform deletion of old application and rename the green process to blue 
cf delete $BLUE -f
cf rename $GREEN $BLUE
cf delete-route $DOMAIN -n $GREEN -f
finally

echo "DONE"
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
    MANIFEST=$(mktemp -t "${BLUE}_manifest.temp")

    #Create the new manifest file for deployment
    cf create-app-manifest $BLUE -p $MANIFEST
    
    #Find and replace the application name (to the name stored in green variable) in the manifest file
    sed -i -e "s/: ${BLUE}/: ${GREEN}/g" $MANIFEST
    sed -i -e "s?path: ?path: $CURRENTPATH/?g" $MANIFEST

    trap on_fail ERR
    
    #Prepare the URL of the green application
    DOMAIN=$CF_API
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
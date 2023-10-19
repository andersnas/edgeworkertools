# Edgeworker Tools
Just some useful tools for working with Akamai Edgeworkers.

buildew.sh 
- A shell script that takes care of creating a new version and deploying this to the desired network. 
1. It creates a new version and updated the bundle version number
2. It uploads the new version
3. It activates the version on the desired network
4. It waits for deployment to be done

Pre requisites:
1. You need a path for a valid edgerc file
2. You need to put the shellscript in the same directory as your code (where the bundle.json and main.js files are)
3. You need to alter the parameters at the top of the script to fit your application and environemnt.
4. You need a sub directory called builds where all builds will be stored

This is only tested with a valid accountkey on OSX.

![alt text](https://github.com/andersnas/edgeworkertools/blob/main/screenshot.jpg?raw=true)

#!/bin/bash

# Define edgerc location, section, and account-switch-key
edgerc=".edgerc" # Default path; adjust if necessary
edgerc_section="default" # Default section; adjust if necessary
accountkey="" # If you use account-switching, provide the key here
network="STAGING" # STAGING or PRODUCTION
package="main.js bundle.json blocklist.json" # Your files to be included
edgeworker_id="" # Replace with your EdgeWorker ID


# If no argument is provided, exit
# Check if an argument was provided
if [ "$#" -ne 1 ]; then
    # If no argument, prompt the user for input
    read -p "Please enter your description: " description
    # Exit if the description is empty
    if [[ -z "$description" ]]; then
        echo "Description cannot be empty!"
        exit 1
    fi
else
    description="$1"
fi

# Extract current version and increment patch version
current_version=$(jq -r '.["edgeworker-version"]' bundle.json)
IFS='.' read -ra version_parts <<< "$current_version"
patch_version=$((version_parts[2] + 1))
new_version="${version_parts[0]}.${version_parts[1]}.$patch_version"

# Update the version and description in bundle.json
jq --arg new_version "$new_version" --arg description "$description" \
   '.["edgeworker-version"]=$new_version | .description=$description' bundle.json > tmp.json && mv tmp.json bundle.json

# Create a tarball
tar czvf "builds/edgeworker-$new_version.tgz" $package

# Deploy to Akamai's staging using specified edgerc and account switch key
export AKAMAI_EDGERC=$edgerc_path
export AKAMAI_EDGERC_CONFIG=$edgerc_section

akamai edgeworkers upload $edgeworker_id --bundle "builds/edgeworker-$new_version.tgz" --edgerc $edgerc --accountkey $accountkey

# Activate on Akamai's staging network
akamai edgeworkers activate $edgeworker_id $network $new_version --edgerc $edgerc --accountkey $accountkey

# Poll for the status of the activated version
echo "Waiting for activation of version $new_version on $network to complete..."
while true; do
    # Run the command and save its output to a temp file
    akamai edgeworkers status $edgeworker_id --edgerc $edgerc --accountkey $accountkey --json > tmp_status_output.txt
    
    # Extract the JSON file path from the temp output
    json_filepath=$(grep 'Saving JSON output at:' tmp_status_output.txt | awk '{print $5}')
    
    # Check if file exists and is readable
    if [[ -r "$json_filepath" ]]; then
        # Parse the status for the specific version and network from the JSON file
        status=$(jq -r --arg ver "$new_version" --arg net "$network" '.data[] | select(.version == $ver and .network == $net) | .status' "$json_filepath")
        
        if [[ "$status" == "COMPLETE" ]]; then
            echo "Activation of version $new_version on $network is complete!"
            break
        elif [[ "$status" == "ERROR" ]]; then
            echo "Activation of version $new_version on $network encountered an error."
            exit 1
        elif [[ -z "$status" ]]; then
            echo "Version $new_version on $network not found. Waiting..."
            sleep 10
        else
            echo "Activation status of version $new_version on $network: $status. Waiting..."
            sleep 10
        fi
    else
        echo "Unable to read status file. Waiting..."
        sleep 10
    fi
done

# Cleanup
rm tmp_status_output.txt



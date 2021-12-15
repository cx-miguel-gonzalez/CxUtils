#make sure the map and cxflowjar variables are set with the names you have in your file structure
map="./config/projectMap.csv"
cxflowjar="cx-flow-1.6.26.jar"
currDate=$(date +'%F %H:%M%:%S')

#Insert Slack information here or comment out if you are not using Slack
SLACK_WEBHOOK_URL="webhookURL"
SLACK_CHANNEL="cxflow"
#function that sends the slack notifications
send_notification() {
  local color='good'
  if [ $1 == 'ERROR' ]; then
    color='danger'
  elif [ $1 == 'WARN' ]; then
    color = 'warning'
  fi
  local message="payload={\"channel\": \"#$SLACK_CHANNEL\",\"attachments\":[{\"pretext\":\"$2\",\"text\":\"$3\",\"color\":\"$color\"}]}"

  curl -X POST --data-urlencode "$message" ${SLACK_WEBHOOK_URL}
}

#Send Start Notification
if [[ ! -z $SLACK_WEBHOOK_URL ]]
    currDate=$(date +'%F %H:%M%:%S')
    msg="$currDate Batch Processor is starting"
    send_notification 'good' "Message Title" "$msg"
fi

#get the projectMap from the repository.
echo "cloning the repository"

if [[ ! -d "config" ]] 
then
    mkdir config
    #update this repository to point at the correct location
    git clone gitURL ./config && echo "Successfully cloned repository"
else
    cd config
    git checkout main && git pull && echo "Pulled latest version of the project map"
    cd ..
fi

echo "Validating mapping file projectMap.csv"
#set the count
count=0
while IFS==, read -r Checkmarx_Project Checkmarx_Team Bug_Tracker Bug_Tracker_Instance Jira_Project Jira_Issue_Type Repo_Name Branch Namespace Config end; do
    #check headers
    echo $Checkmarx_Project
    if [[ $count == 0 ]]
    then 
        if [[ $Checkmarx_Project == "Checkmarx_Project" && $Checkmarx_Team == "Checkmarx_Team" && $Bug_Tracker == "Bug_Tracker" 
            && $Bug_Tracker_Instance == "Bug_Tracker_Instance" && $Jira_Project == "Jira_Project" && $Jira_Issue_Type == "Jira_Issue_Type" 
            && $Repo_Name == "Repo_Name" && $Branch == "Branch" && $Namespace == "Namespace" && $Config == "Config" ]]
        then
            echo "Headers successfully validated"
        else
            echo "Please update the projectMap.csv file to have correct column order"
            exit 1
        fi
    else
        filename="$Checkmarx_Project.log"
        #configPath="./config/$Config"
        configPath=$Config
        #grab the correct bug tracker credentials
        bug_tracker_url="${Bug_Tracker}_url_${Bug_Tracker_Instance}"
        bug_tracker_token="${Bug_Tracker}_token_${Bug_Tracker_Instance}"
        bug_tracker_user="${Bug_Tracker}_user_${Bug_Tracker_Instance}"
        #add check to see if environment variables exist
        if [[ ! -z ${!bug_tracker_url} || ! -z ${!bug_tracker_token} || ! -z ${!bug_tracker_user} ]]
        then
        #use environment variables
            echo "using env variables"
            echo "java -jar $cxflowjar --project --cx-team=$Checkmarx_Team --cx-project=$Checkmarx_Project --bug-tracker=$Bug_Tracker --bug-tracker-impl=$Bug_Tracker --app=$Jira_Project --jira.project=$Jira_Project --jira.issuetype=$Jira_Issue_Type --branch=$Branch --repo-name=$repo_Name --namespace=$Namespace --spring.config.location=$configPath"
            nohup java -jar $cxflowjar --project --cx-team=$Checkmarx_Team --cx-project=$Checkmarx_Project --bug-tracker=$Bug_Tracker --bug-tracker-impl=$Bug_Tracker --app=$Jira_Project --jira.project=$Jira_Project --jira.issuetype=$Jira_Issue_Type --branch=$Branch --repo-name=$repo_Name --namespace=$Namespace --${Bug_Tracker}.url=${!bug_tracker_url} --${Bug_Tracker}.token=${!bug_tracker_token} --${Bug_Tracker}.username=${!bug_tracker_user} --spring.config.location=$configPath > $filename
        else
        #pull everything from config
            echo "using a config file"
            echo "java -jar $cxflowjar --project --cx-team=$Checkmarx_Team --cx-project=$Checkmarx_Project --bug-tracker=$Bug_Tracker --bug-tracker-impl=$Bug_Tracker --app=$Checkmarx_Project --jira.project=$Jira_Project --jira.issuetype=$Jira_Issue_Type --branch=$Branch --repo-name=$repo_Name --namespace=$Namespace --spring.config.location=$configPath"
            nohup java -jar $cxflowjar --project --cx-team=$Checkmarx_Team --cx-project=$Checkmarx_Project --bug-tracker=$Bug_Tracker --bug-tracker-impl=$Bug_Tracker --app=$Checkmarx_Project --jira.project=$Jira_Project --jira.issuetype=$Jira_Issue_Type --branch=$Branch --repo-name=$repo_Name --namespace=$Namespace --spring.config.location=$configPath > $filename
        fi
    
        #do some basic error handling
        if grep -q ERROR $filename;
        then
            echo "$currDate Bug Tracking for $Checkmarx_Project has failed with the following errors" >> batchprocessorErrors.log
            grep ERROR $filename >> batchprocessorErrors.log

            #send out slack notification
            if [[ ! -z $SLACK_WEBHOOK_URL ]]
            then
            echo "Sending slack notification"
            errmsg="$currDate Bug Tracking for $Checkmarx_Project has failed during processing."
            send_notification 'ERROR' "Message Title" "$errmsg"
            errdetails=$(grep ERROR $filename)
            send_notification 'ERROR' "Message Title" "$errdetails"
            fi

        fi

    fi


    ((++count))
done < $map

total=$(expr $count - 1)
echo "Found {$total} entries in the projectMap. Ticket creation jobs have completed"

#Send Completion Notification
if [[ ! -z $SLACK_WEBHOOK_URL ]]
    currDate=$(date +'%F %H:%M%:%S')
    msg="$currDate Batch Processor has completed"
    send_notification 'good' "Message Title" "$msg"
fi

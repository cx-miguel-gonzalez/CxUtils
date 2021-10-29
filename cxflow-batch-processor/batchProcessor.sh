#make sure the map and cxflowjar variables are set with the names you have in your file structure

map="./config/projectMap.csv"
cxflowjar="cx-flow-1.6.25.jar"
#map_repo="https://github.com/mgonzalezcx/cxflowbatchmode.git"

#get the projectMap from the repository.
echo "cloning the repository"

if [[ ! -d "config" ]] 
then
    mkdir config
    git clone git@github.com:mgonzalezcx/cxflowbatchmode.git ./config
else
    cd config
    git pull
    cd ..
fi

echo "Validating mapping file projectMap.csv"
#set the count
count=0
while IFS==, read -r Checkmarx_Project Checkmarx_Team Bug_Tracker Jira_Instance Jira_Project Jira_Issue_Type SCM_Instance Repo_Name Branch Namespace Config end; do
    #check headers
    echo $Checkmarx_Project
    if [[ $count == 0 ]]
    then 
        if [[ $Checkmarx_Project == "Checkmarx_Project" && $Checkmarx_Team == "Checkmarx_Team" && $Bug_Tracker == "Bug_Tracker" 
            && $Bug_Tracker_Instance == "Bug_Tracker_Instance" && $Jira_Project == "Jira_Project" && $Jira_Issue_Type == "Jira_Issue_Type" 
            && $SCM_Instance == "SCM_Instance" && $Repo_Name == "Repo_Name" && $Branch == "Branch" && $Namespace == "Namespace" && $Config == "Config" ]]
        then
            echo "Headers successfully validated"
        else
            echo "Please update the projectMap.csv file to have correct column order"
            exit 1
        fi
    else
        filename="$Checkmarx_Project.log"
        if [[ $Bug_Tracker == "Jira" ]]
        then
        #grab the correct Jira credentials
        bug_tracker_url=jira_url_$Bug_Tracker_Instance
        bug_tracker_token=jira_token_$Bug_Tracker_Instance
        bug_tracker_user=jira_user_$Bug_Tracker_Instance
        #add check to see if environment variables exist
            if [[ ! -z $bug_tracker_url || ! -z $bug_tracker_token || ! -z $bug_tracker_user ]]
            then
            #use environment variables
                echo "environment variables set for $Jira_Instance"
                #echo "java -jar $cxflowjar --project --cx-team=$Checkmarx_Team --cx-project=$Checkmarx_Project --bug-tracker=$Bug_Tracker --app=$Jira_Project --jira.project=$Jira_Project --jira.issuetype=$Jira_Issue_Type --spring.config.location=$Config"
                echo "java -jar $cxflowjar --project --cx-team=$Checkmarx_Team --cx-project=$Checkmarx_Project --bug-tracker=$Bug_Tracker --bug-tracker-impl=$Bug_Tracker --app=$Checkmarx_Project --jira.project=$Jira_Project --jira.issuetype=$Jira_Issue_Type --branch=$Branch --repo-name=$repo_Name --namespace=$Namespace --$Bug_tracker.url=$bug_tracker_url --$Bug_tracker.token=$bug_tracker_token --$Bug_tracker.username=$bug_tracker_user --spring.config.location=$Config"
                nohup java -jar $cxflowjar --project --cx-team=$Checkmarx_Team --cx-project=$Checkmarx_Project --bug-tracker=$Bug_Tracker --bug-tracker-impl=$Bug_Tracker --app=$Checkmarx_Project --jira.project=$Jira_Project --jira.issuetype=$Jira_Issue_Type --branch=$Branch --repo-name=$repo_Name --namespace=$Namespace --$Bug_tracker.url=$bug_tracker_url --$Bug_tracker.token=$bug_tracker_token --$Bug_tracker.username=$bug_tracker_user --spring.config.location=$Config > $filename
            else
            #pull everything from config
                #run the batch command
                echo "environment variables set for $Jira_Instance"
                echo "java -jar $cxflowjar --project --cx-team=$Checkmarx_Team --cx-project=$Checkmarx_Project --bug-tracker=$Bug_Tracker --bug-tracker-impl=$Bug_Tracker --app=$Checkmarx_Project --jira.project=$Jira_Project --jira.issuetype=$Jira_Issue_Type --branch=$Branch --repo-name=$repo_Name --namespace=$Namespace --spring.config.location=$Config"
                nohup java -jar $cxflowjar --project --cx-team=$Checkmarx_Team --cx-project=$Checkmarx_Project --bug-tracker=$Bug_Tracker --bug-tracker-impl=$Bug_Tracker --app=$Checkmarx_Project --jira.project=$Jira_Project --jira.issuetype=$Jira_Issue_Type --branch=$Branch --repo-name=$repo_Name --namespace=$Namespace --spring.config.location=$Config > $filename
            fi
#        else
#        echo "java -jar $cxflowjar --project --cx-team=$Checkmarx_Team --cx-project=$Checkmarx_Project --bug-tracker=$Bug_Tracker --bug-tracker-impl=$Bug_Tracker --branch=$Branch --repo-name=$repo_Name --namespace=$Namespace --app=$Checkmarx_Project --spring.config.location=$Config"
#        nohup java -jar $cxflowjar --project --cx-team=$Checkmarx_Team --cx-project=$Checkmarx_Project --bug-tracker=$Bug_Tracker --bug-tracker-impl=$Bug_Tracker --branch=$Branch --repo-name=$Repo_Name --namespace=$Namespace --app=$Checkmarx_Project --spring.config.location=$Config > $filename
#        fi
    fi
    ((++count))
done < $map

total=$(expr $count - 1)
echo "Found {$total} entries in the projectMap. Completed all ticket creation jobs"




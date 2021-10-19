#make sure the map and cxflowjar variables are set with the names you have in your file structure

map="./projectMap.csv"
cxflowjar="cx-flow-1.6.25.jar"

echo "Validating mapping file projectMap.csv"
#set the count
count=0
while IFS==, read -r Checkmarx_Project Checkmarx_Team Jira_Project Jira_Issue_Type Config end; do
    #check headers
    echo $Checkmarx_Project
    if [[ $count == 0 ]]
    then 
        if [[ $Checkmarx_Project == "Checkmarx_Project" && $Checkmarx_Team == "Checkmarx_Team" && $Jira_Project == "Jira_Project" && $Jira_Issue_Type == "Jira_Issue_Type" && $Config == "Config" ]]
        then
            echo "Headers successfully validated"
        else
            echo "Please update the projectMap.csv file to have correct column order"
            exit 1
        fi
    else
        echo "java -jar $cxflowjar --project --cx-team=$Checkmarx_Team --cx-project=$Checkmarx_Project --app=$Jira_Project --jira-project-field=$Jira_Project --jira-issuetype-field=$Jira_Issue_Type -- --spring.config.location=$Config"
        nohup java -jar $cxflowjar --project --cx-team=$Checkmarx_Team --cx-project=$Checkmarx_Project --app=$Jira_Project --jira-project-field=$Jira_Project --jira-issuetype-field=$Jira_Issue_Type --spring.config.location=$Config > batchprocess.log

    fi
    ((++count))
   
#done < $map
done < $map

total=$(expr $count - 1)
echo "Found {$total} entries in the projectMap. Completed all ticket creation jobs"




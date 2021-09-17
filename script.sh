#!/bin/bash
# Ask the user for their name

if ! command -v terraform &> /dev/null
then
    echo -e 'terraform command could not be found.Please install terraform first.\nhttps://releases.hashicorp.com/terraform/'
    exit
fi

if ! command -v jq &> /dev/null
then
    echo -e 'jq command could not be found.Please install terraform first.\nbrew install jq'
    exit
fi

echo "Enter your organization name in TFC:"
read org_name

#1. Set up TOKEN env variable.Make sure you have a TFE_TOKEN env variable in order to authenticate to TF.

echo "Please enter Terraform cloud user token:"
read TOKEN
export TFE_TOKEN=$TOKEN

#2. Get a list of all you workspaces IDs

pages=$(curl -s \
--header "Authorization: Bearer $TFE_TOKEN" \
--header "Content-Type: application/vnd.api+json" \
"https://app.terraform.io/api/v2/organizations/"$org_name"/workspaces?page%5Bsize%5D=100" | jq '.meta.pagination."total-pages"')

for i in $(seq 1 $pages)
do curl -s \
--header "Connection: keep-alive" \
--header "Authorization: Bearer $TFE_TOKEN" \
--header "Content-Type: application/vnd.api+json" \
"https://app.terraform.io/api/v2/organizations/"$org_name"/workspaces?page%5Bsize%5D=100&page%5Bnumber%5D="$i"" | jq -r '.data[] .id'  
done >> list.txt

#3.Create a main.tf file based on the workspace ID


echo -e 'provider "tfe" {} \r\n' > main.tf

#4 Inside the Terraform configruation folder you need to do terraform init. 
terraform init

for i in $(cat list.txt)
do echo 'resource "tfe_workspace" "'$i'" { 
     organization = "'$org_name'"  
     name = "name"
     }
     ' >> main.tf
done



#5.Now it is time to perforn terraform import to quickly import the workspaces do the following

start=`date +%s`
for i in $(cat list.txt)
do terraform import tfe_workspace.$i $i
done

tier=$(curl -s \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request GET \
  "https://app.terraform.io/api/v2/organizations/"$org_name"/subscription" | jq -r '.included[] .attributes.name')

if [ "$tier" = "Business" ]; then 
    for i in $(jq -r '.resources[] .instances[] .attributes.agent_pool_id' terraform.tfstate)
    do ws=$(grep -B6 $i terraform.tfstate | grep ws- | awk -F '"' '{print $4}'); sed  "s/resource \"tfe_workspace\" \"$ws\" {/resource \"tfe_workspace\" \"$ws\" { | agent_pool_id = \"$i\"/" main.tf | tr '|' '\n' > main1.tf
    done
    mv -f main1.tf main.tf
fi



terraform plan -no-color --destroy  > main1.tf 


echo -e 'provider "tfe" {} \r\n' > main2.tf
cat main1.tf | sed "s/ -//g" | sed "s/> null//g" | sed -E '/^ +id +=|^ +operations +=/d' | sed -E '/^tfe_workspace.ws/d' | sed -E '/^────|^Plan:|^Note:|^guarantee/d' | sed '/Terraform used the selected providers/,/perform the following actions:/d' | sed '/# /d' >> main2.tf


mv -f main2.tf main.tf

rm -f main1.tf


# Pottential issue: When you are dealing with a lot of workspaces , lets say over 200, while adding them there might be a problem like throtling
<<COMMENT
│ Error: Error getting client
│ 
│   with provider["registry.terraform.io/hashicorp/tfe"],
│   on /Users/yhalachev/repos/API_tests/yordanh_paid/цлоне/tfe_workspace_config_creator/main.tf line 1, in provider "tfe":
│    1: provider "tfe" {} 
│ 
│ Error getting client: Failed to request discovery document: Get "https://app.terraform.io/.well-known/terraform.json": dial tcp: lookup app.terraform.io on 8.8.8.8:53:
│ read udp 192.168.0.102:59535->8.8.8.8:53: i/o timeout
COMMENT

cat main.tf | grep 'resource "tfe_workspace"' | awk -F '"' '{print $4}' > actual.txt
skipped=$(echo "$(cat list.txt ; cat actual.txt)" | sort | uniq -u)
echo "$(cat list.txt ; cat actual.txt)" | sort | uniq -u > skipped.txt

while [ ! -z "$skipped"];do
    
    for i in $(cat skipped.txt)
    do echo 'resource "tfe_workspace" "'$i'" { 
    organization = "'$org_name'"  
    name = "name"
    }
    ' >> main.tf;terraform import tfe_workspace.$i $i
    done
    if [ "$tier" = "Business" ]; then 
        for i in $(jq -r '.resources[] .instances[] .attributes.agent_pool_id' terraform.tfstate)
        do ws=$(grep -B6 $i terraform.tfstate | grep ws- | awk -F '"' '{print $4}'); sed  "s/resource \"tfe_workspace\" \"$ws\" {/resource \"tfe_workspace\" \"$ws\" { | agent_pool_id = \"$i\"/" main.tf | tr '|' '\n' > main1.tf
        done
        mv -f main1.tf main.tf
    fi
    terraform plan -no-color --destroy  > main1.tf 

    echo -e 'provider "tfe" {} \r\n' > main2.tf
    cat main1.tf | sed "s/ -//g" | sed "s/> null//g" | sed -E '/^ +id +=|^ +operations +=/d' | sed -E '/^tfe_workspace.ws/d' | sed -E '/^────|^Plan:|^Note:|^guarantee/d' | sed '/Terraform used the selected providers/,/perform the following actions:/d' | sed '/# /d' >> main2.tf. 
    
    mv -f main2.tf main.tf

    rm -f main1.tf
    

    cat main.tf | grep 'resource "tfe_workspace"' | awk -F '"' '{print $4}' > actual.txt
    skipped=$(echo "$(cat list.txt ; cat actual.txt)" | sort | uniq -u)
    echo "$(cat list.txt ; cat actual.txt)" | sort | uniq -u > skipped.txt

done

end=`date +%s`

runtime=$((end-start))

echo -e 'Your configuration is ready. The time it took to do the imports was '$(( $runtime / 60 ))' minutes and '$(( $runtime % 60 ))' seconds. You have '$(cat main.tf | grep 'resource "tfe_workspace"' | wc -l )' workspaces defined'

#!/bin/bash
# Ask the user for their name

if ! command -v terraform &> /dev/null
then
    echo -e 'terraform command could not be found.Please install terraform first.\nhttps://releases.hashicorp.com/terraform/'
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

for i in {1..$pages}
do curl -s \
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


terraform plan -no-color --destroy  > main1.tf 


echo -e 'provider "tfe" {} \r\n' > main2.tf
cat main1.tf | sed "s/ -//g" | sed "s/> null//g" | sed -E '/^ +id +=|^ +operations +=/d' | sed -E '/^tfe_workspace.ws/d' | sed -E '/^────|^Plan:|^Note:|^guarantee/d' | sed '/Terraform used the selected providers/,/perform the following actions:/d' | sed '/# /d' >> main2.tf


mv -f main2.tf main.tf

rm -f main1.tf
end=`date +%s`

runtime=$((end-start))

echo -e 'Your configuration is ready. The time it took to do the imports was '$runtime'. You have '$(cat list.txt | wc -l )' workpsaces'
 

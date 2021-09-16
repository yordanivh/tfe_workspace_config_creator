# tfe_workspace_config_creator

This script is designed to help spawn a tfe_workspace configuration for your organization in Terraform Cloud(TFC).This could be very helpfull in situations where you have to change the settings of multiple workspaces at once as well as for backup purposes.

**Caveats:**
Every workspace that changes the VCS setting may require a automatic plan in order to setup the webhook. In cases where a big number of workspaces change their 
VCS setting the triggered plan will clog the run queue in TFC.

## Prerequisites

1. You will need to have a TFC user token that will be used for API calls and with the TFE provider
2. You will need to have terraform lattest version installed - it can be downloaded from here

## How to use this script

1. Download to a folder where you wish your terraform configuration to reside.
2. Run the script, make sure it is executable, if not do : `chmod +x script.sh`
3. You will be prompted for your TFC organization name.
4. You will be prompted for a TFC user token - this step will add a TFE_TOKEN env variable 
5. The script is running `terraform import` so depending on the number of workspace it can take a bit longer to execute.

## End result
You should ahve a main.tf file containing the configuration and terraform.tfstate file containing the real-life resources.
Now you can make any changes you would like.



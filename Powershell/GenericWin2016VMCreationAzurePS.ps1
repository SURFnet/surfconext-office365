#####################################################################################################################################################################
#                                                                                                                                                                   #
# This script can be used to create a Windows Server 2016 VM on Microsoft Azure with PowerShell. These steps will guide you through the configuration of:           #
#                                                                                                                                                                   #
#                - Resource group                                                                                                                                   #
#                - Network components                                                                                                                               #
#                - Virtual Machine configuration                                                                                                                    #
#                - Virtual Machine                                                                                                                                  #
#                - Backup Vault                                                                                                                                     #
#                - Virtual Machine Backup                                                                                                                           #
#                                                                                                                                                                   #
#                                                                                                                                                                   #
# Created by: Nick Boszhard (2AT)                                                                                                                                   #
# Version 1.0 (13-07-2017)                                                                                                                                          #
#                                                                                                                                                                   #
#####################################################################################################################################################################

$Environment = "AzureCloud"
$TenantId = "ADD YOUR TENANTID"
$SubscriptionId = "ADD YOUR SUBSCRIPTIONID"
$SubscriptionName = "ADD YOUR SUBSCRIPTION NAME"
$Location = "ADD YOUR LOCATION (we used westeurope)"
$ResourceGroupName = "ADD YOUR RESOURCEGROUP NAME"

#### Logon to Azure ####
Login-AzureRmAccount -TenantId $TenantId -SubscriptionId $SubscriptionId
Get-AzureRmSubscription -SubscriptionId $SubscriptionId -TenantId $TenantId 

#### Get All VM Images Publishers ####
Get-AzureRmVMImagePublisher -Location $Location

#### Get Microsoft VM Images ####
Get-AzureRmVMImageOffer -Location $Location -PublisherName "MicrosoftWindowsServer"

#### Get Windows Server Images ####
Get-AzureRmVMImageSku -Location $Location -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer"

#### Create New ResourceGroup on Azure ####
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location

#### Check if the ResourceGroup is created ####
Get-AzureRmResourceGroup -ResourceGroupName $ResourceGroupName




############################################# CREATE NETWORK COMPONENTS #############################################
$ServerSubnet = "ADD SUBNET (for example: 192.168.1.0/24)"
$ServerSubnetName = "ADD SUBNET NAME"
$ServerVnetName = "ADD VNET NAME"
$ServerVnetAddresPrefix = "ADD VNET ADDRESS PREFIX (for example: 192.168.0.0/16)"
$ServerAllocationMethod = "Static"
$ServerIdleTimeout = "4"
$ServerPublicDNSName = "ADD YOUR PUBLIC DNS NAME (For Example: Servermypublicdns$(Get-Random))"
$ServerNetworkSecGrpRDP = "ADD YOUR NETWORK SECURITY RULE NAME FOR RDP TRAFFIC"
$ServerNetworkSecGrpWWW = "ADD YOUR NETWORK SECURITY RULE NAME FOR WWW TRAFFIC"
$ServerNetworkSecurityGroupName = "ADD YOUR NETWORK SECURITY GROUP NAME"
$ServerPubNicName = "ADD YOUR PUBLIC NIC NAME"
 
Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Network
 
#### Create a subnet configuration ####
$ServerSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $ServerSubnetName -AddressPrefix $ServerSubnet
 
#### Create a virtual network ####
$ServerVnet = New-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName -Location $Location -Name $ServerVnetName -AddressPrefix $ServerVnetAddresPrefix -Subnet $ServerSubnetConfig
 
#### Create a public IP address and specify a DNS name ####
$ServerPublicIp = New-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod $ServerAllocationMethod -IdleTimeoutInMinutes $ServerIdleTimeout -Name $ServerPublicDNSName
 
#### Create an inbound network security group rule for port 3389 ####
$ServerNsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name $ServerNetworkSecGrpRDP  -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
 
#### Create an inbound network security group rule for port 80 ####
$ServerNsgRuleWeb = New-AzureRmNetworkSecurityRuleConfig -Name $ServerNetworkSecGrpWWW -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix *  -DestinationPortRange 80 -Access Allow
 
#### Create a network security group ####
$ServerNetworkSecurityGroup = New-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $Location -Name $ServerNetworkSecurityGroupName -SecurityRules $ServerNsgRuleRDP,$ServerNsgRuleWeb
 
#### Create a virtual network card and associate with public IP address and NSG ####
$ServerPubNic = New-AzureRmNetworkInterface -Name $ServerPubNicName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $ServerVnet.Subnets[0].Id -PublicIpAddressId $ServerPublicIp.Id -NetworkSecurityGroupId $ServerNetworkSecurityGroup.Id




############################################# CREATE A VIRTUAL MACHINE CONFIGURATION #############################################
$ServerVMName = "ADD YOUR VM NAME"
$ServerVMSize = "ADD YOUR VM SIZE (For example: Standard_DS2)"
 
#### Define a credential object ####
$cred = Get-Credential

Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Compute

#### Create a virtual machine configuration ####
$vmConfig = New-AzureRmVMConfig -VMName $ServerVMName -VMSize $ServerVMSize | Set-AzureRmVMOperatingSystem -Windows -ComputerName $ServerVMName -Credential $cred | Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version latest | Add-AzureRmVMNetworkInterface -Id $ServerPubNic.Id




############################################# CREATE A VIRTUAL MACHINE #############################################

$Location = "ADD YOUR LOCATION (we used westeurope)"
$ResourceGroupName = "ADD YOUR RESOURCEGROUP NAME"
 
#### Create a virtual machine ####
New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $vmConfig 




################################################## CREATE VM BACKUP ##################################################
$RecoveryResourceVault = "ENTER BACKUP VAULT NAME"
$BackupPolicy = "ENTER BACKUP POLICY NAME"
$WorkloadType = "AzureVM"
$Server1 = "ENTER VM NAME"

Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.RecoveryServices"

#### Create Backup vault ####
New-AzureRmRecoveryServicesVault -Name $RecoveryResourceVault -ResourceGroupName $ResourceGroupName -Location $Location

#### Set backup redundancy #### 
$Vault = Get-AzureRmRecoveryServicesVault –Name $RecoveryResourceVault
Set-AzureRmRecoveryServicesBackupProperties  -Vault $Vault -BackupStorageRedundancy LocallyRedundant

Get-AzureRmRecoveryServicesVault -Name $RecoveryResourceVault | Set-AzureRmRecoveryServicesVaultContext

#### Show available backup policies ####
Get-AzureRmRecoveryServicesBackupProtectionPolicy -WorkloadType $WorkloadType

#### Create a new backup policy with the default schedule and retention policy ####
$schPol = Get-AzureRmRecoveryServicesBackupSchedulePolicyObject -WorkloadType $WorkloadType
$retPol = Get-AzureRmRecoveryServicesBackupRetentionPolicyObject -WorkloadType $WorkloadType
New-AzureRmRecoveryServicesBackupProtectionPolicy -Name $BackupPolicy -WorkloadType $WorkloadType -RetentionPolicy $retPol -SchedulePolicy $schPol

#### Enable the backup ###
$pol=Get-AzureRmRecoveryServicesBackupProtectionPolicy -Name $BackupPolicy
Enable-AzureRmRecoveryServicesBackupProtection -Policy $pol -Name $Server1 -ResourceGroupName $ResourceGroupName
# Enable-AzureRmRecoveryServicesBackupProtection -Policy $pol -Name "Win2016SURFnet" -ResourceGroupName $ResourceGroupName
# Enable-AzureRmRecoveryServicesBackupProtection -Policy $pol -Name "Windows10Client" -ResourceGroupName $ResourceGroupName

#### Adjust the backup retention policy ####
$retPol = Get-AzureRmRecoveryServicesBackupRetentionPolicyObject -WorkloadType $WorkloadType
$retPol.DailySchedule.DurationCountInDays = 30
$retPol.WeeklySchedule.DurationCountInWeeks = 4
$retPol.MonthlySchedule.DurationCountInMonths = 1
$retPol.YearlySchedule.DurationCountInYears = 1

$pol= Get-AzureRmRecoveryServicesBackupProtectionPolicy -Name $BackupPolicy
Set-AzureRmRecoveryServicesBackupProtectionPolicy -Policy $pol  -RetentionPolicy $RetPol

#### TRIGGER A BACKUP ###

#### RUN ONE AT A TIME! CHECK JOB STATUS BEFORE STARTING A NEW JOB ####

### Check running jobs ####
$joblist = Get-AzureRmRecoveryservicesBackupJob
$joblist[0]

#### Start backupjob ####
$namedContainer = Get-AzureRmRecoveryServicesBackupContainer -ContainerType $WorkloadType -Status "Registered" -FriendlyName $Server1
$item = Get-AzureRmRecoveryServicesBackupItem -Container $namedContainer -WorkloadType $WorkloadType
$job = Backup-AzureRmRecoveryServicesBackupItem -Item $item



################################################################################################################################################
#                                                                                                                                              #
# This script can be used to create a Windows 10 Ent VM on Microsoft Azure with PowerShell, without a visual studio subscription.              #
# Please follow the steps in the guide below to prepare your VHD, for the use on Microsoft Azure.                                              #
#                                                                                                                                              #
# NOTE THAT THIS PROCEDURE IS UNSUPPORTED BY MICROSOFT. USE AT YOUR OWN RISK!                                                                  #
#                                                                                                                                              #
# These steps will guide you through the configuration of:                                                                                     #
#                                                                                                                                              #
#                - Resource group                                                                                                              #
#                - Network components                                                                                                          #
#                - Windows 10 Ent VHD                                                                                                          #
#                - Storage account                                                                                                             #
#                - Virtual Machine configuration                                                                                               #
#                - Virtual Machine                                                                                                             #
#                - Backup Vault                                                                                                                #
#                - Virtual Machine Backup                                                                                                      #
#                                                                                                                                              #
#                                                                                                                                              #
# Created by: Nick Boszhard (2AT)                                                                                                              #
# Version 1.0 (13-07-2017)                                                                                                                     #
#                                                                                                                                              #
################################################################################################################################################

################################################## CREATE WINDOWS 10 ENTERPRISE CLIENT FROM VHD ##################################################
############### CHECK VHD PREPARATION STEPS ON: https://wiki.surfnet.nl/download/attachments/60686794/Prepare%20your%20VHD%20for%20Windows%2010.pdf ################

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

################################################## CREATE NETWORK COMPONENTS ##################################################
$ClientSubnetName = "ENTER YOUR SUBNET NAME"
$ClientVnetName = "ENTER YOUR VNET NAME"
$ClientVnetAddresPrefix = "ENTER YOUR VNET ADDRESS PREFIX (For example: 10.0.0.0/24)"
$ClientSubnet = "ENTER YOUR SUBNET (For example: 10.0.0.0/24)"
$ClientSubnetName = "ENTER YOUR SUBNET NAME"
$ClientAllocationMethod = "Static"
$ClientIdleTimeout = "4"
$ClientPublicDNSName = "ENTER YOUR PUBLIC DNS NAME (For example: Clientmypublicdns$(Get-Random))"
$ClientNetworkSecGrpRDP = "ENTER YOUR NETWORK SECURITY RULE NAME FOR RDP TRAFFIC"
$ClientNetworkSecGrpWWW = "ENTER YOUR NETWORK SECURITY RULE NAME FOR WWW TRAFFIC"
$ClientNetworkSecurityGroupName = "ENTER YOUR NETWORK SECURITY GROUP NAME"
$ClientPubNicName = "ENTER YOUR PUBLIC NIC NAME"
$ClientNicName = "ENTER YOUR NIC NAME"

Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Network

#### Create a subnet configuration ####
$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $ClientSubnetName -AddressPrefix $ClientSubnet

#### Create a virtual network ####
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName -Location $Location -Name $ClientVnetName -AddressPrefix $ClientVnetAddresPrefix -Subnet $subnetConfig

#### Create a public IP address and specify a DNS name ####
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod $ClientAllocationMethod -IdleTimeoutInMinutes $ClientIdleTimeout -Name $ClientPublicDNSName

#### Create an inbound network security group rule for port 3389 ####
$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name $ClientNetworkSecGrpRDP  -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow

#### Create an inbound network security group rule for port 80 ####
$nsgRuleWeb = New-AzureRmNetworkSecurityRuleConfig -Name $ClientNetworkSecGrpWWW  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access Allow

#### Create a network security group ####
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $Location -Name $ClientNetworkSecurityGroupName -SecurityRules $nsgRuleRDP,$nsgRuleWeb

#### Create a virtual network card and associate with public IP address and NSG ####
$nic = New-AzureRmNetworkInterface -Name $ClientNicName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

#### Define a credential object ####
$cred = Get-Credential

################################################## UPLOAD VHD AND CREATE IMAGE ##################################################
$sourceVhd = "ENTER THE SOURCE VHD LOCATION (For example: C:\Users\Public\Documents\Hyper-V\Virtual hard disks\******.vhd)"
$destinationVhd = "ENTER THE DESTINATION (Looks like: https://******.blob.core.windows.net/vhd/*****.vhd)"
$NumberOfUploaderThreads = "5"
$StorageAccountName = "ENTER YOUR STORAGE ACCOUNT NAME"
$StorageAccountLabel = "ENTER YOUR STORAGE ACCOUNT LABEL"
  
#### Define a credential object ####
$cred = Get-Credential
  
#### Create storage account ####
New-AzureStorageAccount -StorageAccountName $StorageAccountName -Label $StorageAccountLabel -Location $Location
  
#### Upload VHD ####
Add-AzureRmVhd -LocalFilePath $sourceVHD -Destination $destinationVHD -ResourceGroupName $ResourceGroupName -NumberOfUploaderThreads $NumberOfUploaderThreads
  
#### Create Image from uploaded VHD ####
$storageAccountResourceId = "ENTER YOUR STORAGE ACCOUNT RESOURCE ID (Look like: /subscriptions/5abca34e-******-****-*****/resourceGroups/*******/providers/Microsoft.Storage/storageAccounts/*****)"
$diskName = "ENTER YOUR DISKNAME"
$diskSize = "ENTER DISK SIZE IN GB (For example: 35)"
$imageName = "ENTER IMAGE NAME"
$osType = "Windows"
$AccountType = "StandardLRS"
 
Select-AzureRmSubscription -SubscriptionId $SubscriptionId
  
#### Create Managed Disk in the target subscription using the VHD file in the source subscription ####
$diskConfig = New-AzureRmDiskConfig -AccountType $AccountType -Location $Location -CreateOption Import -SourceUri $destinationVhd -StorageAccountId $storageAccountResourceId -DiskSizeGB $diskSize
$osDisk = New-AzureRmDisk -DiskName $diskName -Disk $diskConfig -ResourceGroupName $ResourceGroupName
  
#### Create an image in the target subscription using the Managed Disk created in the same subscription ####
$imageConfig = New-AzureRmImageConfig -Location $Location
$imageConfig = Set-AzureRmImageOsDisk -Image $imageConfig -OsType $osType -OsState Generalized -ManagedDiskId $osDisk.Id
$image = New-AzureRmImage -ImageName $imageName -ResourceGroupName $ResourceGroupName -Image $imageConfig
  
#### Delete the Managed Disk created in Step 1 ####
Remove-AzureRmDisk -ResourceGroupName $ResourceGroupName -DiskName $diskName

$ClientVMName = "ENTER THE VM NAME"
$ClientVMSize = "ENTER THE VM SIZE (For example: Standard_DS2_v2)"
$DiskSizeInGB = "ENTER DISK SIZE IN GB (For example: 35)"
 
Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Compute
$cred = Get-Credential
 
#### Set VM CONFIG ####
$vm = New-AzureRmVMConfig -VMName $ClientVMName -VMSize $ClientVMSize
 
#### SET IMAGE TO BE USED ####
$vm = Set-AzureRmVMSourceImage -VM $vm -Id $image.Id
 
#### SET VM CREATION PARAMETERS ####
$vm = Set-AzureRmVMOSDisk -VM $vm -DiskSizeInGB $DiskSizeInGB -CreateOption FromImage -Caching ReadWrite
 
#### SET VM OPERATING SYSTEM PARAMETERS ####
$vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $ClientComputerName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
 
#### SET VM NETWORK COMPONENTS ####
$vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $ClientPubNicName.Id
 
#### CREATE VM ####
New-AzureRmVM -VM $vm -ResourceGroupName $ResourceGroupName -Location $location
 
#### CHECK IF THE VM IS PROVISIONED ####
$vmList = Get-AzureRmVM -ResourceGroupName $ResourceGroupName
$vmList.Name


################################################## CREATE VM BACKUP ##################################################
$RecoveryResourceVault = "ENTER BACKUP VAULT NAME"
$BackupPolicy = "ENTER BACKUP POLICY NAME"
$WorkloadType = "AzureVM"
$Client1 = "ENTER VM NAME"

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
Enable-AzureRmRecoveryServicesBackupProtection -Policy $pol -Name $Client1 -ResourceGroupName $ResourceGroupName

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
$namedContainer = Get-AzureRmRecoveryServicesBackupContainer -ContainerType $WorkloadType -Status "Registered" -FriendlyName $Client1
$item = Get-AzureRmRecoveryServicesBackupItem -Container $namedContainer -WorkloadType $WorkloadType
$job = Backup-AzureRmRecoveryServicesBackupItem -Item $item
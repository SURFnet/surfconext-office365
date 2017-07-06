########################## DESCRIPTION ############################################
# This script includes several steps that you can run to:
#
# 1. Install the ADDS Role and DNS on your server
# 2. Create a group managed service account for ADFS
# 3. Install the ADFS Role on your server
# 4. Install the IIS Role on your server
# 5. Create the (mandatory) ADFS Claim Descriptions on your ADFS server/farm to use SURFconext with Office365
# 6. Create a SURFconext relying party trust on your ADFS server/farm with the (mandatory) claims rules for SURFconext with Office365
# 7. Configure the SURFconext federation on Office365
# 8. Set modern authentication on Exchange Online to be able to use rich clients
# 
# You can use parts of this script or run every step on the servers you want to configure. Be aware that every step has its own variables where you will have to set your own configuration options
#
# 
###################################################################################


########################################### INSTALL ADDS ROLE AND DNS ########################################### 
$ComputerName = "YOUR COMPUTER NAME"
$DomainName = "YOUR DOMAIN NAME"
$DatabasePath = “C:\Windows\NTDS”
$DomainMode = "Win2012R2"
$DomainNetbiosName = "YOUR DOMAIN NETBIOSNAME"
$ForestMode = "Win2012R2"
$Logpath = “C:\Windows\NTDS”
$SysvolPath = “C:\Windows\SYSVOL”


#### Get Windows features to check if the ADDS role is available ####
Get-windowsfeature

#Installing the Active Directory Domain Service
Install-windowsfeature AD-Domain-Services

#### Import the required modules for the ADDS Deployment ####
Import-Module ADDSDeployment

#### Install new Domain Controller in a new Forest ####
Install-ADDSForest -DomainName $DomainName -NoDnsOnNetwork -DatabasePath $DatabasePath -DomainMode $DomainMode -DomainNetbiosName $DomainNetbiosName -ForestMode $ForestMode -LogPath $Logpath -SysvolPath $SysvolPath -CreateDnsDelegation:$false -InstallDns:$true -NoRebootOnCompletion:$false -Force:$true

#### Install ADDS Tools ####
Import-Module ServerManager
Add-WindowsFeature RSAT-ADDS-Tools

########################################### INSTALL ADFS ROLE ########################################### 
$gMSAName = "gMSA-ADFS"
$DNSHostName = "YOUR ADFS DNS HOSTNAME (EG: adfs.yourdomain.com)" 
$ServPrincName = "host/YOURADFSDNSHOSTNAME (EG: host/adfs.yourdomain.com)"
$Path = "SERVICE ACCOUNT PATH (EG: CN=Managed Service Accounts,DC=yourdomain,DC=com"

 
#### To create a group managed service account, you have to create a KDS Root Key ####
#### Create KDS Root Key (The -10 is only usefull in a testing environment and will ensure immediately effectiveness) ####
Add-KdsRootKey –EffectiveTime (Get-Date).AddHours(-10)

#### Create new Group Managed Service Account
New-ADServiceAccount -Name $gMSAName -DNSHostName $DNSHostName -ServicePrincipalNames $ServPrincName -Path $Path

#### Install IIS Role ####
Install-WindowsFeature -name Web-Server -IncludeManagementTools

#### Install ADFS Role ####
Install-windowsfeature adfs-federation –IncludeManagementTools


########################################### RUN AND FINISH THE AAD CONNECT TOOL BEFORE YOU CONTINUE ###########################################
########################################### GET THE AAD CONNECT MANUAL FROM THIS LINK: https://wiki.surfnet.nl/....... ###########################################


########################################### Create ADFS Claim Descriptions ###########################################

#### ADD UID CLAIM DESCRIPTION ####
Add-ADFSClaimDescription -Name urn:mace:dir:attribute-def:uid -ClaimType urn:mace:dir:attribute-def:uid -ShortName uid -IsAccepted $false -IsOffered $false

#### ADD MAIL CLAIM DESCRIPTION ####
Add-ADFSClaimDescription -Name urn:mace:dir:attribute-def:mail -ClaimType urn:mace:dir:attribute-def:mail -ShortName mail -IsAccepted $false -IsOffered $false

#### ADD DISPLAYNAME CLAIM DESCRIPTION ####
Add-ADFSClaimDescription -Name urn:mace:dir:attribute-def:displayName -ClaimType urn:mace:dir:attribute-def:displayName -ShortName displayName -IsAccepted $false -IsOffered $false

#### ADD schacHomeOrganization CLAIM DESCRIPTION ####
Add-ADFSClaimDescription -Name schacHomeOrganization -ClaimType urn:mace:terena.org:attribute-def:schacHomeOrganization -ShortName schacHomeOrganization -IsAccepted $true -IsOffered $true

#### ADD eduPersonAffiliation CLAIM DESCRIPTION ####
Add-ADFSClaimDescription -Name urn:mace:dir:attribute-def:eduPersonAffiliation -ClaimType urn:mace:dir:attribute-def:eduPersonAffiliation -ShortName eduPersonAffiliation -IsAccepted $true -IsOffered $true

#### ADD eduPersonEntitlement CLAIM DESCRIPTION ####
Add-ADFSClaimDescription -Name urn:mace:dir:attribute-def:eduPersonEntitlement -ClaimType urn:mace:dir:attribute-def:eduPersonEntitlement -ShortName eduPersonEntitlement -IsAccepted $false -IsOffered $false

#### ADD employeeNumber CLAIM DESCRIPTION ####
Add-ADFSClaimDescription -Name urn:mace:dir:attribute-def:employeeNumber -ClaimType urn:mace:dir:attribute-def:employeeNumber -ShortName employeeNumber -IsAccepted $false -IsOffered $false

#### ADD ImmutableID CLAIM DESCRIPTION ####
Add-ADFSClaimDescription -Name ImmutableID -ClaimType ImmutableID -ShortName ImmutableID -IsAccepted $false -IsOffered $false


#### CREATE SURFCONEXT RELYING PARTY TRUST ####
$RelyingPartyTrustName = "SURFconext"
$MetaDataURL = "https://engine.surfconext.nl/authentication/sp/metadata"
$ClaimIssuanceFile = "C:\Users\Nick\Desktop\HartingCollege\ClaimIssuanceRules.txt"
$ACPName = "Permit everyone"

Add-ADFSRelyingPartyTrust -Name $RelyingPartyTrustName -MetadataUrl $MetaDataURL -IssuanceTransformRulesFile $ClaimIssuanceFile -AutoUpdateEnabled:$true -MonitoringEnabled:$true -AccessControlPolicyName $ACPName

########################################### CONFIGURE THE SURFCONEXT FEDERATION ###########################################

Connect-MsolService

$dom = "YOUR DOMAIN NAME"
$slo = "https://engine.surfconext.nl/logout"
$idp = "YOUR FEDERATION SERVICE IDENTIFIER URL"
$crt = "MIID3zCCAsegAwIBAgIJAMVC9xn1ZfsuMA0GCSqGSIb3DQEBCwUAMIGFMQswCQYDVQQGEwJOTDEQMA4GA1UECAwHVXRyZWNodDEQMA4GA1UEBwwHVXRyZWNodDEVMBMGA1UECgwMU1VSRm5ldCBCLlYuMRMwEQYDVQQLDApTVVJGY29uZXh0MSYwJAYDVQQDDB1lbmdpbmUuc3VyZmNvbmV4dC5ubCAyMDE0MDUwNTAeFw0xNDA1MDUxNDIyMzVaFw0xOTA1MDUxNDIyMzVaMIGFMQswCQYDVQQGEwJOTDEQMA4GA1UECAwHVXRyZWNodDEQMA4GA1UEBwwHVXRyZWNodDEVMBMGA1UECgwMU1VSRm5ldCBCLlYuMRMwEQYDVQQLDApTVVJGY29uZXh0MSYwJAYDVQQDDB1lbmdpbmUuc3VyZmNvbmV4dC5ubCAyMDE0MDUwNTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKthMDbB0jKHefPzmRu9t2h7iLP4wAXr42bHpjzTEk6gttHFb4l/hFiz1YBI88TjiH6hVjnozo/YHA2c51us+Y7g0XoS7653lbUN/EHzvDMuyis4Xi2Ijf1A/OUQfH1iFUWttIgtWK9+fatXoGUS6tirQvrzVh6ZstEp1xbpo1SF6UoVl+fh7tM81qz+Crr/Kroan0UjpZOFTwxPoK6fdLgMAieKSCRmBGpbJHbQ2xxbdykBBrBbdfzIX4CDepfjE9h/40ldw5jRn3e392jrS6htk23N9BWWrpBT5QCk0kH3h/6F1Dm6TkyG9CDtt73/anuRkvXbeygI4wml9bL3rE8CAwEAAaNQME4wHQYDVR0OBBYEFD+Ac7akFxaMhBQAjVfvgGfY8hNKMB8GA1UdIwQYMBaAFD+Ac7akFxaMhBQAjVfvgGfY8hNKMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBAC8L9D67CxIhGo5aGVu63WqRHBNOdo/FAGI7LURDFeRmG5nRw/VXzJLGJksh4FSkx7aPrxNWF1uFiDZ80EuYQuIv7bDLblK31ZEbdg1R9LgiZCdYSr464I7yXQY9o6FiNtSKZkQO8EsscJPPy/Zp4uHAnADWACkOUHiCbcKiUUFu66dX0Wr/v53Gekz487GgVRs8HEeT9MU1reBKRgdENR8PNg4rbQfLc3YQKLWK7yWnn/RenjDpuCiePj8N8/80tGgrNgK/6fzM3zI18sSywnXLswxqDb/J+jgVxnQ6MrsTf1urM8MnfcxG/82oHIwfMh/sXPCZpo+DTLkhQxctJ3M="
$sso = "THE PASSIVE LOGON URI YOU RECEIVED FROM SURFCONEXT"

Set-MsolDomainAuthentication –DomainName $dom -Authentication Managed
Set-MsolDomainAuthentication –DomainName $dom -FederationBrandName $dom -Authentication Federated -PassiveLogOnUri $sso -SigningCertificate $crt -IssuerUri $idp -LogOffUri $slo -PreferredAuthenticationProtocol Samlp

########################################### SET MODERN AUTHENTICATION TO BE ABLE TO USE RICH CLIENTS SUCH AS OUTLOOK ###########################################

$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection

Import-PSSession $Session

Set-OrganizationConfig -OAuth2ClientProfileEnabled $true



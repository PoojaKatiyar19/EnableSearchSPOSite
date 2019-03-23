Add-Type -Path "C:\Program Files\SharePoint Online Management Shell\Microsoft.Online.SharePoint.PowerShell\Microsoft.SharePoint.Client.dll"
Add-Type -Path "C:\Program Files\SharePoint Online Management Shell\Microsoft.Online.SharePoint.PowerShell\Microsoft.SharePoint.Client.Runtime.dll"

Import-Module -Name ".\CheckSiteExists.ps1"

$xmlFile = ".\Configurations.xml"
$xmlConfig = [System.Xml.XmlDocument](Get-Content $xmlFile)
$RootPath = $xmlConfig.Settings.LogsSettings.RootPath

$csvlocation = $RootPath + "Sites.csv"
$sites = Import-csv -header URL $csvlocation
Write-Host "Number of sites: " $($sites.URL.Count) -ForegroundColor DarkYellow

$searchFeatureId = "9c0834e1-ba47-4d49-812b-7d4fb6fea211"
        
$userId = $xmlConfig.Settings.ConfigurationSettings.UserID
$Password = $xmlConfig.Settings.ConfigurationSettings.Password
$pwd = $(ConvertTo-SecureString $Password -AsPlainText -Force)
$creds = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($userId, $pwd)  

#region DisableFeature
#This function is to disable any feature. FeatureId needs to be supplied here.
 function DisableFeature()
 {
    try
    {
        $site = $ctx.Site
        $site.Features.Remove($FeatureId, $true)
        $ctx.Load($site)
        $ctx.ExecuteQuery()
        Write-Host "Deactivated Workflow feature"
    }
    catch
    {
        Write-Host "Error in deactivating site feature : $($_.Exception.Message)" -ForegroundColor Red
    }

 }

 #endregion

#region ActivateSearchFeature
 function ActivateSearchFeature()
 {
    try
    {
        Write-Host "Search Feature is not active, activating now..."
        $siteFeature = $site.Features.Add($searchFeatureId, $true, [Microsoft.SharePoint.Client.FeatureDefinitionScope]::None)
        #Below line sets "Allow this site to appear in search results" to True
        $site.RootWeb.NoCrawl = $false
        $site.RootWeb.Update()
        $siteFeature.Retrieve("DisplayName")
        $ctx.Load($site)  
        $ctx.Load($siteFeature)  
        $ctx.ExecuteQuery()
            
        if($siteFeature.DefinitionId -ne $null)
        {
            Write-Host $($URL) " :Search Feature activated"
        }
    }
    catch
    {
        Write-Host $($URL): "Error in activating site feature : $($_.Exception.Message)" -ForegroundColor Red
    }    
}

#endregion

#region main code to call the functions.

foreach($site in $sites)
{

        $URL = $site.URL     
        $ctx = New-Object Microsoft.SharePoint.Client.ClientContext($URL)
        $ctx.credentials = $creds
        $site = $ctx.Site
        $checkSearchFeature = $site.Features.GetById($searchFeatureId)

        $ctx.Load($checkSearchFeature)               
        $ctx.ExecuteQuery()

        $SiteExists = Check-SiteExists -SiteURL $URL -Credentials $creds

        if($SiteExists -eq $true)
        {
            if($checkSearchFeature.DefinitionId -eq $null)
            {  
                Write-Host "Activating Search feature for: " $($URL) -ForegroundColor Cyan
                ActivateSearchFeature; 
            }
            else
            {
                
                Write-Host $($URL): `r`n "Search feature is already activated"
            }
        }
        else
        {
            Write-Host $($URL): `r`n "Site does not exist!"
        }
}

#endregion

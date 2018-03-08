function Update-BuildDef
{
    <#
    .SYNOPSIS
    As part of certain release activities, it is nessasary to retrieve a set of Tfs work items.
    This function will retrieve the set on basis of the WIQL query passed to it.

    .PARAMETER WiqlQuery
    This is the query that will determine the workitems selected and returned to the caller.

    .EXAMPLE
    Get-TfsWorkItems "SELECT System.ID, System.Title from workitems"

    http://papptfs17.binckbank.nv:8080/tfs/Binck/Delivery/_apis/build/definitions/12?api-version=2.0

    #>
    param(
        [Parameter(Mandatory)]
        [string]$buildDefUrl,
        [Parameter(Mandatory)]
        [string]$TfsCollection,
        [Parameter(Mandatory)]
        [string]$Tfsproject,
        [Parameter(Mandatory)]
        [string]$buildDefName
    )
    
    $response = Invoke-WebRequest $buildDefUrl -UseDefaultCredentials

    # This assumes the working directory is the location of the assembly:
    #[void][System.Reflection.Assembly]::LoadFile("C:\dev\PowerShell\Tfs-BuildDefinitions\TfsBuildUpdater\newtonsoft.json.11.0.1\lib\net45\Newtonsoft.Json.dll") #T800
    [void][System.Reflection.Assembly]::LoadFile("D:\Dev\github\TfsBuildUpdater\release\newtonsoft.json.11.0.1\lib\net45\Newtonsoft.Json.dll") #work
    $buildDefinition = [Newtonsoft.Json.JsonConvert]::DeserializeObject($response.Content)
    #Write-Host "BuildDef name=" $buildDefinition.name.ToString()

    $UpdateRequired = $false

    Write-Host "`n-----------------------------------------------"
    Write-Host "Build def name   : $buildDefName"
    Write-Host "Location         : $TfsCollection\$Tfsproject"
    #foreach($bldTask in $buildDefinition.inputs.PSObject.Properties)
    foreach($bld in  $buildDefinition.build)
    {
        Write-Host "`nBuild task name=" $bld.displayName.ToString()
        if($bld.displayName.ToString().ToLower().Contains("nuget restore"))
        {
            $NuGetVersionFound = $false            
            #Write-Host "NuGet restore found!"
            foreach($in in $bld.inputs)
            {
                #Write-Host "input=" $in.name.ToString()
                if(($in.name.ToString().ToLower().Contains("nugetversion")) -and  ($in.value.ToString() -ne "4.0.0.2283")) 
                {
                    Write-Host "`nnugetversion needs attention! Current version=:" $in.value.ToString()-ForegroundColor Yellow
                    Write-Host "nugetversion should be : 4.0.0.2283" -ForegroundColor Yellow
                    $in.value = "'4.0.0.2283'"
                    Write-Host "nugetversion will be updated to 4.0.0.2283" -ForegroundColor Cyan
                    $NuGetVersionFound = $true
                }
            }
            if ($NuGetVersionFound -eq $false)
            {
                Write-Host "No NuGet version info found! Needs manual interaction" -ForegroundColor Red
            }
        }

        #now check the Vstest versions stuff
        if($bld.displayName.ToString().ToLower().Contains("test assemblies"))
        {
            foreach($in in $bld.inputs)
            {
                if(($in.name.ToString().ToLower() -eq "vstestversion") -and ($in.value.ToString().ToLower() -ne "latest"))
                {
                    Write-Host "`nVsTest settings needs attention! Should be vsTestVersion = latest" -ForegroundColor Yellow      
                    Write-Host "Current values are: "
                    Write-Host "Displayname : " $in.name
                    Write-Host "Value       : " $in.value.ToString()
                    $in.value = "'latest'"
                    Write-Host "VsTest version will be updated to 'latest'" -ForegroundColor Cyan
                }
            }

            foreach($tsk in $bld.task)
            {
                if(($tsk.name.ToString().ToLower() -eq "versionspec") -and ($tsk.value.ToString().ToLower() -ne "2.*"))
                {
                    Write-Host "`nVsTest settings needs attention! Should be VersionSpec 2.*" -ForegroundColor Yellow      
                    Write-Host "Current values are: "
                    Write-Host "Displayname  : " $tsk.name
                    Write-Host "Value        : " $tsk.value.ToString()
                    $tsk.value = "'2.*'"
                    Write-Host "versionSpec will be updated to '2.*'" -ForegroundColor Cyan
                }
            }
        }

        #now check the Vstest versions stuff
        if($bld.displayName.ToString().ToLower().Contains("npm"))
        {
            foreach($in in $bld.inputs)
            {
                if(($in.name.ToString().ToLower() -eq "command") -and ($in.value.ToString().ToLower() -eq "run extract"))
                {
                    Write-Host "`nNpm settings needs attention! Please investigate." -ForegroundColor Yellow      
                    Write-Host "Current values are: "
                    Write-Host "Command     : " $in.name.ToString()
                    Write-Host "Value       : " $in.value.ToString()
                    Write-Host "Value NOT updated!" -ForegroundColor Cyan
                }
            }
        }
    }
    
    <#
    #Here follows the commit section...
    $serialized = [Newtonsoft.Json.JsonConvert]::SerializeObject($buildDefinition)
    $postData = [System.Text.Encoding]::UTF8.GetBytes($serialized)
    # The TFS2015 REST endpoint requires an api-version header, otherwise it refuses to work properly.
    $headers = @{ "Accept" = "api-version=2.3-preview.2" }
    $response = Invoke-WebRequest -UseDefaultCredentials -Uri $buildDefUrl -Headers $headers `
                -Method Put -Body $postData -ContentType "application/json"
    Write-Host "result code=" $response.StatusDescription
    #>
}

#Update-BuildDef
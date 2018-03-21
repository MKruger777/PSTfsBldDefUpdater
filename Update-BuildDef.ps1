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
    <#
        Note that the following 2 files should exits in the directory where the script is executing from!
        #Newtonsoft.Json.xml
        #Newtonsoft.Json.dll
    #>
    $JsonPath = Join-Path -Path $PSScriptRoot -ChildPath "Newtonsoft.Json.dll"
    [void][System.Reflection.Assembly]::LoadFile($JsonPath)
    $buildDefinition = [Newtonsoft.Json.JsonConvert]::DeserializeObject($response.Content)

    $SearchFolderVal = '''$(Build.SourcesDirectory)\\$(ProjectFolder)'''
    $SearchFolderPropExist = $false
    
    Write-Host "`n-----------------------------------------------"
    Write-Host "Build def name   : $buildDefName"
    Write-Host "Location         : $TfsCollection\$Tfsproject"
    
    if ($buildDefinition.type.ToString().ToLower() -eq 'xaml') 
    {
        Write-Host "XAML build definitions are no longer supported in Tfs2018! This build definition will be ignored - please investigate." -ForegroundColor Red
    }
    else 
    {
        foreach ($bld in  $buildDefinition.build) 
        {
            #VS-Test changes
            if ($bld.displayName.ToString().ToLower().Contains("test assemblies")) 
            {
                Write-Host "Display name : "$bld.displayName.ToString()
                $bld.displayName = "Test Assemblies"
                $SearchFolderPropExist = SearchPathExists $bld

                if($SearchFolderPropExist -eq $true)
                {
                    foreach ($in in $bld.inputs) 
                    {
                        #locate the input var searchFolder and update it
                        if (($in.name.ToString().ToLower() -contains "searchfolder")) 
                        {
                            Write-Host "search path found! It will now be updated ..." -ForegroundColor Yellow
                            $in.value = $SearchFolderVal
                        }
                    }
                }
                else 
                {
                    #the input var searchFolder does not exist and will be inserted
                    Write-Host "Search path filter NOT found! It will be inserted now ..." -ForegroundColor Red
                    $bld.inputs.Add("searchFolder", $SearchFolderVal);
                }
            }
            #end VS-Test changes

            # nuget snoop
            if($bld.displayName.ToString().ToLower().Contains("nuget restore"))
            {
                $NuGetVersionFound = $false            
                #Write-Host "NuGet restore found!"
                foreach($in in $bld.inputs)
                {
                    foreach($tsk in $bld.task)
                    {
                        if(($tsk.name.ToString().ToLower() -eq "versionspec") -and ($tsk.value.ToString().ToLower() -ne "0.*"))
                        {
                            Write-Host "NuGet versionSpec needs attention!" -ForegroundColor Yellow
                            Write-Host "Current values are: "
                            Write-Host "Displayname  : " $tsk.name
                            Write-Host "Value        : " $tsk.value.ToString()
                            $tsk.value = "'0.*'"
                            Write-Host "versionSpec will be updated to '0.*'" -ForegroundColor Cyan
                        }
                    }

                    if(($in.name.ToString().ToLower().Contains("nugetversion")))
                    {
                        if(($in.value.ToString() -eq "4.0.0.2283"))
                        {
                            Write-Host "NuGet version (4.0.0.2283) found and OK!" -ForegroundColor Green
                            $NuGetVersionFound = $true
                        }
                        else 
                        {
                            Write-Host "`nnugetversion needs attention! Current version=:" $in.value.ToString()-ForegroundColor Yellow
                            Write-Host "nugetversion should be : 4.0.0.2283" -ForegroundColor Yellow
                            $in.value = "'4.0.0.2283'"
                            Write-Host "nugetversion will be updated to 4.0.0.2283" -ForegroundColor Cyan
                            $NuGetVersionFound = $true        
                        }
                    }
                }
                if ($NuGetVersionFound -eq $false)
                {
                    Write-Host "No NuGet version property was NOT found!" -ForegroundColor Red
                    Write-Host "Version prop will now be inserted and set to '4.0.0.2283'" -ForegroundColor Cyan
                    $bld.inputs.Add("nuGetVersion", "'4.0.0.2283'");
                }
            }
            #end NuGet section
        }
        
        #Here follows the commit section...
        $serialized = [Newtonsoft.Json.JsonConvert]::SerializeObject($buildDefinition)
        $postData = [System.Text.Encoding]::UTF8.GetBytes($serialized)
        # The TFS2015 REST endpoint requires an api-version header, otherwise it refuses to work properly.
        $headers = @{ "Accept" = "api-version=2.3-preview.2" }
        $response = Invoke-WebRequest -UseDefaultCredentials -Uri $buildDefUrl -Headers $headers `
                    -Method Put -Body $postData -ContentType "application/json"
        Write-Host "result code=" $response.StatusDescription
    }
}

function SearchPathExists($bld) 
{
    $exists = $false
    foreach ($in in $bld.inputs) 
    {
        if (($in.name.ToString().ToLower() -contains "searchfolder")) 
        {
            #Write-Host "search path found!"
            $exists = $true
            break
        }
    }
    return $exists     
}
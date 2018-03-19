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
    #Write-Host "BuildDef name=" $buildDefinition.name.ToString()

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
        }
        
        #     #Here follows the commit section...
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
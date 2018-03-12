
function Invoke-TfsBldDefUpdater
{
        <#
        .SYNOPSIS
        As part of certain release activities, it is nessasary to retrieve a set of Tfs work items.
        This function will retrieve the set on basis of the WIQL query passed to it.

        .PARAMETER WiqlQuery
        This is the query that will determine the workitems selected and returned to the caller.

        .EXAMPLE
        Get-TfsWorkItems "SELECT System.ID, System.Title from workitems"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TfsUri,        
        [Parameter(Mandatory)]
        [string]$TfsCollection
    )

    ."D:\Dev\github\PSTfsBldDefUpdater\Update-BuildDef.ps1"
    ."D:\Dev\github\PSTfsBldDefUpdater\Get-TfsProjects.ps1"

    #$Script:base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "T800\morne","en55denwlgpdxw2t4bwkdq6apfbugspjaxbhjhrxvymex5tqb2aa")))

    $TfsProjects = New-Object System.Collections.Generic.List[System.Object]
    $TfsProjects = Get-TfsProjects -TfsUri $TfsUri -TfsCollection $TfsCollection

    $wiqlUrl = "$TfsUri/$TfsCollection/_apis/projects?api-version=2.0"
    $TfsProjects = Invoke-RestMethod -UseDefaultCredentials -uri $wiqlUrl -Method Get -ContentType 'application/Json'
    #$TfsProjects = Invoke-RestMethod -UseDefaultCredentials -uri $wiqlUrl -Method Get -ContentType 'application/Json'-Headers @{Authorization=("Basic {0}" -f $Script:base64AuthInfo)}

    #Write-Host "Tfs projects found for collection $TfsCollection = " $TfsProjects.Count
    if($TfsProjects.Count -gt 0)
    {
        Write-Host "`n$TfsCollection collecion projects are:" 
        foreach($TfsProj in $TfsProjects.value)
        {
            Invoke-TfsProjBldDefUpdate -TfsUri $TfsUri -TfsCollection $TfsCollection -TfsProject $TfsProj.name
        }
    }
}

function Invoke-TfsProjBldDefUpdate
{
    param(
        [Parameter(Mandatory)]
        [string]$TfsUri,        
        [Parameter(Mandatory)]
        [string]$TfsCollection,
        [Parameter(Mandatory)]
        [string]$Tfsproject
    )
    
    #http://papptfs17.binckbank.nv:8080/tfs/Binck/Delivery/_apis/build/definitions/12?api-version=2.0 # example

    
    $url = "$TfsUri/$TfsCollection/$Tfsproject/_apis/build/definitions?api-version=2.0"
    
    $TfsProjBldDefs = New-Object System.Collections.Generic.List[System.Object]    
    $TfsProjBldDefs = Invoke-RestMethod -UseDefaultCredentials -uri $url -Method Get -ContentType 'application/Json'

    #Write-Host "Tfs build definitions found for collection $TfsCollection = " $TfsProjBldDefs.Count
    if($TfsProjBldDefs.Count -gt 0)
    {
        foreach($TfsProjBldDef in $TfsProjBldDefs.value)
        {
            $TfsBldDefUrl = "$TfsUri/$TfsCollection/$Tfsproject/_apis/build/definitions/$($TfsProjBldDef.ID)?api-version=2.0"
            Write-Host $TfsBldDefUrl
            Update-BuildDef -buildDefUrl $TfsBldDefUrl -TfsCollection $TfsCollection -TfsProject $TfsProj.name -buildDefName $TfsProjBldDef.Name
        }
    }
}

Invoke-TfsBldDefUpdater -TfsUri "http://papptfs17.binckbank.nv:8080/tfs" -TfsCollection 'Binck'
#Invoke-TfsBldDefUpdater -TfsUri "http://t800:8080/tfs" -TfsCollection 'DefaultCollection'

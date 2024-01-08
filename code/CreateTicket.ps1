<# 

This script calls the 4me API and creates a ticket. Use the following mandatory arguments:

    -Category <incident,rfc,rfi,compliment,complaint,reservation,other> 
    -Subject "<ENTER SUBJECT HERE. PLEASE KEEP THE DOUBLE TICS, THEY ARE CLEANED OUT AFTERWARDS>" 
    -ServiceInstance <service instance ID> 
    -Impact <incident,rfc,rfi,compliment,complaint,reservation,other> | when using TOP, downtime start is automatically added
    -Note '<NOTE HERE. PLEASE KEEP THE SINGLE TICS, THEY ARE CLEANED OUT AFTERWARDS>'

Example: .\QA-CreateTicket.ps1 -Category incident -Subject "subject here" -ServiceInstance 128401 -Impact medium -Note 'i am a note'

#>

# Catching arguments
[CmdletBinding()]
param(

    [Parameter(Mandatory,Position=0)]
    [string]$Category,

    [Parameter(Mandatory,Position=1)]
    [string]$Subject,

    [Parameter(Mandatory,Position=2)]
    [string]$ServiceInstance,

    [Parameter(Mandatory,Position=3)]
    [string]$Impact,

    [Parameter(Mandatory,Position=4)]
    [string]$Note

    )

# Catching config and converting it to a dataset
$cfg_path = "config.txt"
$cfg = Get-Content $cfg_path | Out-String | ConvertFrom-StringData

# Checking if we have the correct directories created
if (Test-Path -Path C:\PRTGout) {
    
    Write-Host "Path for PRTGout exists, skipping directory creation." -ForegroundColor Green 

} else {

    Write-Host "PRTGout folder not created yet, creating one." -ForegroundColor Red
    New-Item -Path "C:\" -Name "PRTGout" -ItemType "directory"

}

# Configuration of API access, change this in the config.txt
$APIURL = $cfg.apiurl
$BearerAuthToken = $cfg.apikey
$4MEAccountName = $cfg.accountname
$TeamID = $cfg.teamid
$Source = "PRTG Network Monitor"

# In case of TOP impact, this is important
$downTimeStart = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"

# Header for HTTP authentication to the API
$Header = @{

        "authorization" = "Bearer $BearerAuthToken"
        "X-4me-Account" = "$4MEAccountName"

    }

# Filtering through all tickets to find the one with our subject.
Invoke-WebRequest -Uri $APIURL/v1/requests/open -Method GET -Headers $Header -OutFile C:\PRTGout\alltickets.json
$ticketData = Get-Content 'C:\PRTGout\alltickets.json' | Out-String | ConvertFrom-Json
$selectedTicket = $ticketData | where-object { $_.subject -eq "$Subject" }
$postID = $selectedTicket.id

if($postID) {

    # Update the newly acquired information to the old ticket
    $ticketBody = @{
        "note" = "$Note"
    }

    $json = $ticketBody | ConvertTo-Json
    Invoke-RestMethod -Uri $APIURL/v1/requests/$postID -Method PATCH -Body $json -Headers $Header

} else {
    # Create a new ticket when there is none
    # Not a clean way to clean up the strings, but it works

    $Subject = $Subject -replace '["]'
    $Note = $Note -replace "[']"

    $ticketBody = @{

        "source" = $Source
        "category" = "$Category"
        "subject" = $Subject
        "team_id" = $TeamID
        "service_instance_id" = "$ServiceInstance"
        "impact" = "$Impact"
        "downtime_start_at" = "$downTimeStart"
        "note" = $Note
        "urgent" = "false"

    }

    $json = $ticketBody | ConvertTo-Json
    Invoke-RestMethod -Uri $APIURL/v1/requests -Method POST -Body $json -Headers $Header
    Write-Host "Ticket created"
}

# Deleting the file we created to catch the tickets.
Remove-Item C:\PRTGout\alltickets.json
<# 

This script calls the 4me API and marks a ticket as urgent. Use the following mandatory arguments:

    -Subject "<ENTER SUBJECT HERE. PLEASE KEEP THE DOUBLE TICS, THEY ARE CLEANED OUT AFTERWARDS>" 
    -StateUrgent <true or false>

Example: .\MarkTicketUrgent.ps1 -Subject "subject here" -StateUrgent true

#>

# Catching arguments
[CmdletBinding()]
param(

    [Parameter(Mandatory,Position=0)]
    [string]$Subject,

    [Parameter(Mandatory,Position=1)]
    [string]$StateUrgent

    )

# Checking if we have the correct directories created
if (Test-Path -Path C:\PRTGout) {
    
    Write-Host "Path for PRTGout exists, skipping directory creation." -ForegroundColor Green 

} else {

    Write-Host "PRTGout folder not created yet, creating one." -ForegroundColor Red
    New-Item -Path "C:\" -Name "PRTGout" -ItemType "directory"

}
# Catching config and converting it to a dataset
$cfg_path = "config.txt"
$cfg = Get-Content $cfg_path | Out-String | ConvertFrom-StringData

# Configuration of API access, change this in the config.txt
$APIURL = $cfg.apiurl
$BearerAuthToken = $cfg.apikey
$4MEAccountName = $cfg.accountname

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

# Changing the urgence state of the ticket
$ticketBody = @{
    "urgent" = $StateUrgent
}

$json = $ticketBody | ConvertTo-Json
Invoke-RestMethod -Uri $APIURL/v1/requests/$postID -Method PATCH -Body $json -Headers $Header
Write-Host "Ticket updated."

# Deleting the file we created to catch the tickets.
Remove-Item C:\PRTGout\alltickets.json
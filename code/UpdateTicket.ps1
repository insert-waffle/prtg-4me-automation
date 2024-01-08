<#

This script calls the 4me API and posts an update to the ticket. Use the following arguments.
If the difference between downtime start and end is less than or equal to 10 minutes, the ticket gets closed automatically.

    -Subject "<ENTER SUBJECT HERE. PLEASE KEEP THE DOUBLE TICS, THEY ARE CLEANED OUT AFTERWARDS>" 
    -Note '<NOTE HERE. PLEASE KEEP THE SINGLE TICS, THEY ARE CLEANED OUT AFTERWARDS>'
    -DownTimeOver true | false

Example: .\UpdateTicket.ps1 -Subject "enter subject here" -Note 'enter note here'
    
#>

[CmdletBinding()]
param(

    [Parameter(Mandatory,Position=1)]
    [string]$Subject,

    [Parameter(Mandatory,Position=2)]
    [string]$Note,

    [Parameter(Position=3)]
    [string]$DownTimeOver

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

# Static strings, can be changed > This message is the one the script checks on, to see if the back up-notification has been posted.
$upMSG = "*reported as back online*"

# Configuration of API access, change this in the config.txt
$APIURL = $cfg.apiurl

$BearerAuthToken = $cfg.apikey
$4MEAccountName = $cfg.accountname
$TeamID = $cfg.teamid

# Header for HTTP authentication to the API
$Header = @{
        "authorization" = "Bearer $BearerAuthToken"
        "X-4me-Account" = "$4MEAccountName"
    }

# Not a clean way to clean up the strings, but it works
$Subject = $Subject -replace '["]'
$Note = $Note -replace "[']"

# Filtering through all tickets to find the one with our subject.
Invoke-WebRequest -Uri $APIURL/v1/requests/open -Method GET -Headers $Header -OutFile C:\PRTGout\alltickets.json
$ticketData = Get-Content 'C:\PRTGout\alltickets.json' | Out-String | ConvertFrom-Json
$selectedTicket = $ticketData | where-object { $_.subject -eq "$Subject" }
$postID = $selectedTicket.id

# Finding all notes for our ticket
$ticketData = Invoke-WebRequest -Uri $APIURL/v1/requests/$postID/notes -Method GET -Headers $Header
$cleanTicketData = ConvertFrom-Json $ticketData.content
$selectedTicket = $cleanTicketData
$text = $selectedTicket.text

# If there already is a note with the "back online" message and the note is the same, skip the next one.
if ( $text -like "$upMSG" -and $note -like "$UpMSG" ) {
    
    Write-Host "Back up message found, skipping this one." -ForegroundColor Green 

} else {
    
    if ( $DownTimeOver -eq "true" ) {

        # Downtime is over
        # Fetching the downtime start
        Invoke-WebRequest -Uri $APIURL/v1/requests/$postID -Method GET -Headers $Header -OutFile C:\PRTGout\downtimecheck_ticket.json
        $downCheckTicket = Get-Content 'C:\PRTGout\downtimecheck_ticket.json' | Out-String | ConvertFrom-Json

        # Figuring out the difference between downtime start and end, if this differency is lower than 10 minutes; close the ticket
        $DownTimeEnd = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
        $timeBetween = NEW-TIMESPAN –Start $downCheckTicket.downtime_start_at –End $DownTimeEnd
        $minutesBetween = $timeBetween.Minutes
        $hoursBetween = $timeBetween.Hours
        $daysBetween = $timeBetween.Days

        # We have to check if the days and hours between are also equal to 0, otherwise the difference between 18:20 and 19:25 is 5 minutes and not 1 hour and 5 minutes.
        if ($minutesBetween -le 10 -and $hoursBetween -eq 0 -and $daysBetween -eq 0) {

            # The downtime is less than / equal to 10 minutes, we'll automatically close the ticket.
            $ticketID = $ticket.id
            $ticketBody = @{
                   "downtime_end_at" = $DownTimeEnd
                   "member" = $cfg.memberId
                   "completed_at" = $DownTimeEnd
                   "completion_reason" = "solved"
                   "status" = "completed"
				   "urgent" = "false"
                   "note" = $Note + " | Automatically closed by PRTG, downtime was less than 10 minutes. Total downtime recorded was: "+ $daysBetween + " days " + $hoursBetween + " hours and " + $minutesBetween + " minute(s)"
            }

        } else {
            
            # The downtime is greater than 10 minutes, keep the ticket open, but post the uptime note.
            $ticketBody = @{
                "note" = $Note + " | Downtime ended, but the ticket was not closed automatically because the downtime was greater than 10 minutes. Please review what happened. Total downtime recorded was: "+ $daysBetween + " days " + $hoursBetween + " hours and " + $minutesBetween + " minute(s)"
                "downtime_end_at" = $DownTimeEnd
				"urgent" = "false"
            }

        }

        # We have to remove the active ticket data, otherwise all goes to hell when running the script again in different circumstances.
        Remove-Item C:\PRTGout\downtimecheck_ticket.json

    } else {

        # Downtime is not over, just post the note in the ticket.
        $ticketBody = @{
            "note" = "$Note"
        }

    }

    $json = $ticketBody | ConvertTo-Json
    $response = Invoke-RestMethod -Uri $APIURL/v1/requests/$postID -Method PATCH -Body $json -Headers $Header

}

# Deleting the file we created to catch the tickets.
Remove-Item C:\PRTGout\alltickets.json

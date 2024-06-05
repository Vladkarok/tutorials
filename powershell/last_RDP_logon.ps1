# Requires run as administrator
# Specify the username to check for RDP logon events
$usernameToCheck = "exampleUserName"  # Change this to the specific username

# Define the Event ID and Logon Type for RDP sessions
$eventId = 4624
$logonType = 10

# Query the Security logs for RDP logon events for the specified user
$events = Get-EventLog -LogName Security -InstanceId $eventId | Where-Object {
    $_.ReplacementStrings[8] -eq $logonType -and
    $_.ReplacementStrings[5] -eq $usernameToCheck
} | Sort-Object TimeGenerated -Descending

# Check if we found any events and display the most recent one
if ($events) {
    $lastEvent = $events[0]
    Write-Host "$usernameToCheck last connected via RDP on $($lastEvent.TimeGenerated)"
} else {
    Write-Host "No RDP logon events found for $usernameToCheck"
}

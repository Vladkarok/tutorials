# Requires run as administrator
# Specify the account names to search for, separated by commas without spaces
$accountNames = "exampleUserName"

# Split the account names into an array
$accountNamesArray = $accountNames -split ','

# Loop through each account name and get the event log details
foreach ($accountName in $accountNamesArray) {
    Write-Output "-----------------------------------------------"
    Write-Output "For account name `"$accountName`":"

    Get-EventLog -LogName Security -InstanceId 4720 | 
        Where-Object { $_.Message -like "*New Account:*Account Name:*$accountName*" } | 
        ForEach-Object {
            $message = $_.Message
            $createdBy = [regex]::Match($message, "Account Name:\s+(\w+)").Groups[1].Value
            $timeGenerated = $_.TimeGenerated
            Write-Output "Account created at: $timeGenerated"
            Write-Output "Account created by: $createdBy"
        }

    Write-Output "-----------------------------------------------"
}

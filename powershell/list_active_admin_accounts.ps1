# Get the local Administrators group
$adminGroup = [ADSI]"WinNT://./Administrators,group"

# Create a custom object to store user information
$adminUsers = @()

# Loop through each member of the Administrators group
foreach ($member in $adminGroup.psbase.Invoke("Members")) {
    $memberObj = $member.GetType().InvokeMember("Adspath", 'GetProperty', $null, $member, $null)
    $user = [ADSI]$memberObj

    # Check if the account is a user account and not a group or computer account
    if ($user.SchemaClassName -eq "User") {
        # Get the user flags to check if the account is disabled
        $userFlags = $user.Properties.Item("UserFlags").Value

        # If userFlags is not null, perform the bitwise check
        if ($null -ne $userFlags) {
            $isDisabled = ($userFlags -band 2) -ne 0
        } else {
            $isDisabled = $false
        }

        # Only add the user if the account is not disabled
        if (-not $isDisabled) {
            # Create a custom object for each user
            $adminUsers += [PSCustomObject]@{
                Name = $user.Name
                ADSPath = $user.ADSPath
                ObjectCategory = $user.ObjectCategory
            }
        }
    }
}

# Display the list of users with administrator permissions
$adminUsers | Format-Table -AutoSize

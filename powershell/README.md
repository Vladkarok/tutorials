# Powershell scripts

Here are some windows powershell scripts that chatGPT (it was a lot of correction) and me created for windows.

## List and description

| Script name | Administrator permissions | Description |
|-|-|-|
| [last_RDP_logon.ps1](/powershell/last_RDP_logon.ps1) | Yes | Specify in script the needed username and it will show when the last time this local user logged on the server like <br> `exampleUsername last connected via RDP on 05/14/2024 09:30:19` |
| [list_active_admin_accounts.ps1](/powershell/list_active_admin_accounts.ps1)| No | Prints the local accounts with Administration permissions enabled |
| [who_created_user.ps1](/powershell/who_created_user.ps1)| Yes | Specify in script the needed local username or usernames separated by comma `,` without spaces and it will show which account and when created this user/users |

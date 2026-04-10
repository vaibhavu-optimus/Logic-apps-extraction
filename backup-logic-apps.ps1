$tenantId = "b5db11ac-8f37-4109-a146-5d7a302f5881"
$subscriptionId = "8fd68313-6401-4bed-ac85-c28f9743fc8a"
$resourceGroupName = "rg-metrovan"
$clonedRepoDir = "."
$branch = "main" # $null = the script will always ask for a branch name when run

Write-Host "Let's ensure Azure Logic Apps are backed up to a Git repository!"

Set-Location $clonedRepoDir
if ($null -eq $branch) {
  $branches = -split (git branch) | Where-Object { $_ –ne "*" }
  $branch = Read-Host -Prompt "Enter name of a new or existing branch (existing branches: $($branches -join ", "))"
}
if ((git rev-parse --abbrev-ref HEAD) -eq $branch) {
  # The branch is already checked out
}
else {
  if ($branches -contains $branch) {
    git checkout $branch
  }
  else {
    git checkout -b $branch
  }
}

$_ = Connect-AzAccount -Tenant $tenantId -Subscription $subscriptionId

$logicApps = Get-AzLogicapp -ResourceGroupName $resourceGroupName

foreach ($logicApp in $logicApps) {
  $file = $clonedRepoDir + "\" + $logicApp.Name + ".json"
  if (-not (Test-Path $file)) {
    # If file does not yet exist, create it
    New-Item -Path $file -ItemType File
    @{ definition = $null; parameters = @{ '$connections' = [ordered]@{ type = "Object"; value = $null } } } | ConvertTo-Json | Out-File $file
  }
  $json = Get-Content $file | ConvertFrom-Json 

  $json.Definition = ($logicApp.Definition.ToString() | ConvertFrom-Json)
  $json.Parameters.'$connections'.Value = ($logicApp.Parameters.'$connections'.Value.ToString() | ConvertFrom-Json)

  $json | ConvertTo-Json -Depth 100 | Out-File $file

  Write-Host "Processed $($logicApp.Name)"
}

$_ = Disconnect-AzAccount

git add .
$changedFiles = git diff --staged --name-only

if ($changedFiles.Length -eq 0) {
  Write-Host "No changes detected."
}
else {
  Write-Host "Committing the following files:`n$($changedFiles -join "`n")"
  $commitMessage = Read-Host -Prompt "Enter commit message"
  git commit -m $commitMessage
  git push
}

Read-Host -Prompt "Press Enter to exit"
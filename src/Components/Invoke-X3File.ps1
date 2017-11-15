function Invoke-X3File {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true, ParameterSetName = "InstallTarget")]
      [switch]$Install,
      [Parameter(Mandatory = $true, ParameterSetName = "UninstallTarget")]
      [switch]$Uninstall,
      [Parameter(Mandatory = $true)]
      [string]$Path,
      [Parameter(Mandatory = $true, ParameterSetName = "InstallTarget")]
      [string]$Destination,
      [Parameter(Mandatory = $false, ParameterSetName = "InstallTarget")]
      [ValidateSet('File','Directory')]
      [string]$Type = "Directory",
      [Parameter(Mandatory = $false, ParameterSetName = "InstallTarget")]
      [switch]$Recurse = $false
   )

   process {
      # $totalFileSize = $Source.Items | Where-Object -FilterScript {$_ -is [System.IO.FileInfo]} `
      #                                | Measure-Object -Sum -Property Length;
      # $currentFileSize = 0;

      # Write-Progress -Id 101 -Activity "Deploying files" -Status "Copying..." -PercentComplete (($currentFileSize / $totalFileSize) * 100)
      # foreach ($fsObject in $Source) {
      #    Write-Progress -Id 101 -Activity "Deploying files" -Status "Copying..." -PercentComplete (($currentFileSize / $totalFileSize) * 100)
      #    $relativePath = $fsObject.FullName.SubString($Source.BasePath);
      #    if ($fsObject -is [System.IO.FileInfo]) {
      #       Copy-Item -Path $fsObject.FullName -Destination (Join-Path -Path $Destination -ChildPath $relativePath)
      #       $currentFileSize += $fsObject.Length;
      #    } else { 
      #       New-Item -Path (Join-Path -Path $Destination -ChildPath $relativePath) -ItemType Directory
      #    }
      # }
      # Write-Progress -Id 101 -Activity "Deploying files" -Status "Done" -Completed


   }
}
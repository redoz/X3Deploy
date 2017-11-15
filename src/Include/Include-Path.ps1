function Include-Path {
   [OutputType([X3IncludeResult[]])]
   [CmdletBinding()]
   param([Parameter(Mandatory = $true)]
         [string[]]$Source,
         [string[]]$Exclude = @(),
         [Switch]$Recurse = $false)

   process {
      foreach ($sourcePath in $Source) {
         $items = [System.IO.FileSystemInfo[]]@((Get-ChildItem -Path $sourcePath -Recurse:$Recurse -Exclude $Exclude))
         if (Test-Path $sourcePath -PathType Leaf) {
            $basePath = [System.IO.Path]::GetDirectoryName($sourcePath);
         } else {
            $basePath = $sourcePath;
         }
         
         Write-Output -InputObject ([X3IncludeResult]::new($basePath, $items))
      }
   }
}
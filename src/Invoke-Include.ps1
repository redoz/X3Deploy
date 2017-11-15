function Invoke-Include {
   [OutputType([string[]])]
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [X3Include]$Directive,
      [Parameter()]
      [string]$DestinationPath
   )

   [void](New-Item -ItemType Container -Path $DestinationPath)
   $command = Get-Command -Verb Include -Noun $Directive.Type
   if ($command -eq $null) {
      throw ("Unable to resolve command: Include-" + $Directive.Type)
   }

   $commandArguments = $Include.Arguments;
   [X3IncludeResult[]]$resultList = & $command @commandArguments

   foreach ($result in $resultList) {
      foreach ($item in $result.Items) {
         $relativePath = $item.FullName.Substring($result.BasePath.Length)
         $destination = (Join-Path -Path $DestinationPath -ChildPath $relativePath)
         Copy-Item -LiteralPath $item.FullName -Destination $destination
      }
   }
}

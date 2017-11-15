function Invoke-X3Directory {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true, ParameterSetName = "InstallTarget")]
      [switch]$Install,
      [Parameter(Mandatory = $true, ParameterSetName = "UninstallTarget")]
      [switch]$Uninstall,
      [Parameter(Mandatory = $true)]
      [string]$Path
   )

   process {
      if ($PSCmdlet.ParameterSetName -eq 'InstallTarget') {
         New-Item -Path $Path -ItemType Directory 
      } else {
         Remove-Item -Path $Path -Recurse -Force
      }
   }
}
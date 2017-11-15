function Invoke-X3Service {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [string]$Path,
      [Parameter(Mandatory = $true, ParameterSetName = "InstallTarget")]
      [string]$Name,
      [Parameter(Mandatory = $false, ParameterSetName = "InstallTarget")]
      [pscredential]$RunAs = $null,
      [Parameter(Mandatory = $false, ParameterSetName = "InstallTarget")]
      [switch]$Start
   )

   begin {}
   process {

   }
   end{}
}
function Require-Module {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory=$true)]
      [string]$Name,
      
      [Parameter()]
      [System.Version]$MinimumVersion,

      [Parameter()]
      [System.Version]$MaximumVersion
   )

   Install-Module @PSBoundParameters -Confirm:$false -Scope CurrentUser
   Import-Module @PSBoundParameters -Scope CurrentUser
}
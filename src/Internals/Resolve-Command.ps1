function Resolve-Command {
   [CmdletBinding()]
   param([Parameter(Mandatory = $true, Position = 0)][X3Command]$Command)

   begin{}
   process {
      $realCommandName = 'Invoke-X3' + $Command.Type;
      $psCommand = Get-Command -Name $realCommandName -ErrorAction SilentlyContinue
      if ($psCommand -eq $null) {
         $positionMessage = Get-PositionMessage -Extent $Command.ErrorPosition
         # TODO use Find-Command to see if we can locate it in a module not imported and suggest that
         Write-Error -Message ("Unable to find command '{0}'`r`n{1}" -f $realCommandName,$positionMessage) -Category ObjectNotFound -RecommendedAction "Make sure to import the relevant module."
      }
      return $psCommand;
   }
   end {}
}
function Get-PositionMessage {
   param(
      [Parameter(Mandatory=$true)]
      [System.Management.Automation.Language.IScriptExtent]$Extent
   )

   $invocationInfo = [System.Management.Automation.InvocationInfo]::Create($MyInvocation.MyCommand, $Extent);
   return $invocationInfo.PositionMessage
}
function Invoke-Error { 
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [ValidateNotNull()]
      [string]$Message, 

      [System.Management.Automation.Language.IScriptExtent]$Extent = $null,

      [System.Exception]$Exception = $null
   )
   begin{}
   process{
      $errorMessage = $Message
      if ($Extent -ne $null)
      {
         $errorMessage += [Environment]::NewLine + (Get-PositionMessage -Extent $Extent)
      }
      
      if ($Exception -ne $null) {
         Write-Error -Message $errorMessage -Exception $Exception
      } else { 
         throw $errorMessage
         #Write-Error -Message $errorMessage

      }
   }
   end{}
}
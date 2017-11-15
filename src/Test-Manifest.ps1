using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language




function Test-Manifest {
   [CmdletBinding()]
   param([Parameter(Mandatory = $true, Position = 0)][X3Manifest]$Manifest,
         [Parameter()][Switch]$PassThru = $false)

   process {
      # validate manifest
      $manifest.Install | Test-Command
      
      if ($PassThru.IsPresent) {
         $Manifest
      }
   }
}

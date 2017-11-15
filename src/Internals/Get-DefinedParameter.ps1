using namespace System.Management.Automation;
using namespace System.Collections.Generic;

function Get-DefinedParameter {
   [OutputType([Dictionary[string, ParameterMetadata]])]
   [CmdletBinding()]
   param (
      [Parameter(Mandatory = $true)]
      [CommandInfo]$Command
   )
   begin {}
   process {
      if ($Command.CmdletBinding) {
         # get list of common properties
         $excludeParameterList = & {
            Function Dummy {[CmdletBinding()]param()process{}}
            $dummyCommand = Get-Command -Name Dummy -CommandType Function
            @($dummyCommand.Parameters.Keys)
         }
      } else {
         $excludeParameterList = @()
      }
      $ret = [Dictionary[string, ParameterMetadata]]::new($Command.Parameters, $Command.Parameters.Comparer)
      foreach ($excludeParameter in $excludeParameterList) {
         $null = $ret.Remove($excludeParameter);
      }
      return $ret;
   }
   end {}
}

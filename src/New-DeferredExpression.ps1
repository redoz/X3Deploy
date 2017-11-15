using namespace System.Collections.Generic;
using namespace System.Management.Automation.Language;
function New-DeferredExpression {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [ValidateNotNull()]
      [scriptblock]$Script,

      [Parameter()]
      [System.Management.Automation.Language.IScriptExtent]$ErrorPosition = $null
   )

   [Tuple[String,VariableExpressionAst][]]$referenceList = [VariableReferenceFinder]::FindAll($Script.Ast, @(), $true);

   $capturedVariableList = [List[PSVariable]]::new()
   foreach ($reference in $referenceList) {
      $capturedVariable = $null;

      for ($scope = 1; $capturedVariable -eq $null; $scope++) {
         try {
            $capturedVariable = Get-Variable -Name ($reference.Item1) -Scope ($scope.ToString([System.Globalization.CultureInfo]::InvariantCulture)) -ErrorAction Stop
            $capturedVariableList.Add($capturedVariable);
            break;
         }
         catch [System.Management.Automation.ItemNotFoundException] {
         }
         catch [System.ArgumentOutOfRangeException] {
            $positionMessage = Get-PositionMessage -Extent $reference.Item2.Extent
            #$invocationInfo = [System.Management.Automation.InvocationInfo]::Create($MyInvocation.MyCommand, $reference.Item2);
            Write-Error -Exception ([System.Management.Automation.ItemNotFoundException]::new("Cannot find a variable with the name '$($reference.Item1)'. `r`n$positionMessage", $_.Exception)) -Category ObjectNotFound
         }
      }
   }

   return [X3DeferredExpression]::new($ErrorPosition, $Script, $capturedVariableList.ToArray());
}
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

function Write-Literal([Parameter(Mandatory = $true)]$Value, [System.Collections.Generic.Dictionary[string, object]]$ExternalLiterals) {
   if ($Value -eq $null) {
      return '$null'
   } 
   if ($Value -is [type]) {
      return '[{0}]' -f $Value.FullName
   } elseif ($Value -is [scriptblock]) {
      # TODO rewrite any "$using:" scoped variables
      return [CodeGen]::Write($Value.Ast, [CodeGenOptions]::None)
      # return $DeferredVariableRewriter.Rewrite($Value.Ast)
   } elseif ($Value -is [bool]) {
      return '${0}' -f $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture).ToLowerInvariant()
   } elseif ($Value -is [byte] -or $Value -is [sbyte] -or $Value -is [int16] -or $Value -is [uint16] -or $Value -is [int32] -or $Value -is [uint32] -or $Value -is [int64] -or $Value -is [uint64]) {
      return '{0}' -f $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
   } elseif ($Value -is [string]) {
      return '"{0}"' -f $Value.Replace("``", '``').Replace("`"",'`"').Replace("`r", '`r').Replace("`n", '`n').Replace("`t", '`t')
   } elseif ($Value -is [hashtable]) {
      return (($Value.GetEnumerator() | ForEach-Object `
               -Begin { '@{' } `
               -Process { 
                  $_.Name + ' = ' + (Write-Literal -Value $_.Value -ExternalLiterals $ExternalLiterals) 
               } `
               -End { '}' }
            ) -join [Environment]::NewLine)
   } elseif ($Value -is [X3DeferredExpression]) {
      if ($ExternalLiterals -eq $null) {
         throw "Cannot write X3DeferredExpression as literal."
      }
      if ($Value.CapturedVariables.Count -gt 0) {
         $identifier = 'S'+ (New-Guid).ToString('n');
         $ExternalLiterals.Add($identifier, $Value)
         $ast = [DeferredVariableRewriter]::Rewrite($Value.Script.Ast);
         $scriptValue = [CodeGen]::Write($ast, [CodeGenOptions]::None); # $DeferredVariableRewriter.Rewrite($Value.Script.Ast);
         return '({0}.InvokeWithContext($X3Deploy.Literals.{1}.Functions, $X3Deploy.Literals.{1}.Variables, $null))' -f $scriptValue,$identifier 
      } else {
         $ast = [DeferredVariableRewriter]::Rewrite($Value.Script.Ast);
         return [AstUtils]::WriteArgument($ast);
         # return [CodeGen]::Write($ast, [CodeGenOptions]::SkipContainer);
      }
   } elseif ($Value -is [PSVariable]) {      
      return "[PSVariable]::new('{0}',{1})" -f $Value.Name,(Write-Literal -Value $Value.Value -ExternalLiterals $ExternalLiterals)
   } else {
      if ($ExternalLiterals -eq $null) {
         throw "Cannot write $($Value.GetType().Name) as literal."
      }      
      $identifier = 'L' + (New-Guid).ToString('n');
      $ExternalLiterals.Add($identifier, $Value)
      return '$X3Deploy.Literals.{0}' -f $identifier
   }
}
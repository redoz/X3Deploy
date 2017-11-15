using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

function Write-Invocation {
   param(
      [Parameter(Mandatory=$true)]
      [X3Command]$Command,
      [Dictionary[string, object]]$ExternalLiterals
   )
   $resolvedCommand = Resolve-Command -Command $Command;
   # $commandArguments = $Command.Arguments | Foreach-Object -Begin {$tmpArgs = @{}} -Process {$tmpArgs.Add($_.Name, $_.Value)} -End {$tmpArgs}

   return $resolvedCommand.Name + ' ' + `
          (($Command.Arguments| ForEach-Object -Process { 
             $literal = '-' + $_.Name;
             $parameter = $resolvedCommand.Parameters[$_.Name]
             if ($parameter.ParameterType -eq [SwitchParameter]) {
                if ($_.Value -isnot [bool] -or (-not $_.Value)) {
                  $literal += ':' + (Write-Literal -Value $_.Value -ExternalLiterals $ExternalLiterals) 
                }
             } else {
               $literal += ' ' + (Write-Literal -Value $_.Value -ExternalLiterals $ExternalLiterals) 
             }
             $literal
          } ) -join ' ')
}


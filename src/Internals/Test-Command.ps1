using namespace System.Management.Automation;


function Test-Command {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
      [X3Command]$Command,

      [Parameter()]
      [Switch]$PassThru = $false
   )

   begin{}
   process {
      $psCommand = Resolve-Command -Command $Command

      # this is crazy but I think it will work:
      # replicate the command signature as a function and invoke it in a seperate runspace and catch any binding errors
      $functionTemplate = @'
function {0} {{
   {1}
   return $PsCmdlet.ParameterSetName;
}}
'@;

      $excludeParameters = @()
      if ($psCommand.CmdletBinding) {
         # get list of common properties
         $excludeParameters = & {
            Function Dummy {[CmdletBinding()]param()process{}}
            $dummyCommand = Get-Command -Name Dummy -CommandType Function
            @($dummyCommand.Parameters.Keys)
         }
      }
      
      $parameterDefintionList = @($psCommand.Parameters.Values | Where-Object -FilterScript { $excludeParameters -notcontains $_.Name} | ForEach-Object -Process {
         $ret = ''
         [ParameterMetadata]$parameterInfo = $_;
         foreach ($parameterSetKvp in $parameterInfo.ParameterSets.GetEnumerator())  {
            $parameterSetName = $parameterSetKvp.Key
            [ParameterSetMetadata]$parameterSetMetadata = $parameterSetKvp.Value
            $ret += "[Parameter(Mandatory = `${0}, Position = {1}, ValueFromPipeline = `${2}, ValueFromPipelineByPropertyName = `${3}, ValueFromRemainingArguments = `${4}, ParameterSetName = '{5}')]"  -f  (`
               $parameterSetMetadata.IsMandatory.ToString().ToLowerInvariant(),`
               $parameterSetMetadata.Position.ToString([System.Globalization.CultureInfo]::InvariantCulture),`
               $parameterSetMetadata.ValueFromPipeline,`
               $parameterSetMetadata.ValueFromPipelineByPropertyName.ToString().ToLowerInvariant(),`
               $parameterSetMetadata.ValueFromRemainingArguments.ToString().ToLowerInvariant(),`
               $parameterSetName)

         }
         # TODO add validation attributes (but only if the value for this parameter is not a X3DeferredExpression)
         $ret += [Environment]::NewLine + '[';
         if ($parameterInfo.SwitchParameter) {
            $ret += 'switch'
         } else {
            $ret += $parameterInfo.ParameterType.FullName
         }
         $ret += ']$' + $parameterInfo.Name

         return $ret;
      });

      $parameterDefinition = ''
      if ($psCommand.CmdletBinding) {
         $parameterDefinition += '[CmdletBinding()]' + [Environment]::NewLine
      }

      if ($parameterDefintionList.Count -gt 0) {
         $parameterDefinition += 'param(' + [Environment]::NewLine + ($parameterDefintionList -join (',' + [Environment]::NewLine * 2)) + [Environment]::NewLine + ')'
      } 

      $functionDefinition = $functionTemplate -f $psCommand.Name, $parameterDefinition
      Write-Debug -Message ("Facade created:`r`n" + $functionDefinition)
      [PowerShell]$powershell = [PowerShell]::Create();
      try {
         $null = $powershell.AddScript($functionDefinition, $false);
         $null = $powershell.Invoke();
         $null = $powershell.AddCommand($psCommand.Name, $false);
         foreach ($argument in $Command.Arguments) {
            # TODO check how this works out with Switch parameters
            if ($argument.Value -is [X3DeferredExpression]) {
               $parameter = $null
               $argumentValue = $null;
               if ($psCommand.Parameters.TryGetValue($argument.Name, [ref]$parameter)) {
                   if ($parameter.ParameterType -eq [String]) {
                      $argumentValue = "Dummy";
                   } elseif ($parameter.ParameterType -eq [System.Object]) {
                     $argumentValue = "Dummy";
                   } elseif ($parameter.ParameterType.IsValueType) {
                     $argumentValue = 0;
                   }
                   # TODO support other types?
               }
               $null = $powershell.AddParameter($argument.Name, $argumentValue);
            } else {
               $null = $powershell.AddParameter($argument.Name, $argument.Value);
            }
         }
         # check whether we should add a -$Command.Target switch parameter
         # first check if the command has one
         if ($psCommand.Parameters.ContainsKey($Command.Target)) {
            # then make sure it wasn't manually provided
            if (-not ($Command.Arguments | Where-Object -Property Name -EQ -Value $Command.Target))
            {
               $null = $powershell.AddParameter($Command.Target);
            }
         }
         try {
            $null = $powershell.Invoke()
         } catch [MethodInvocationException] {
            if ($_.Exception.InnerException -is [System.Management.Automation.ParameterBindingException]) {
               [ParameterBindingException]$ex = $_.Exception.InnerException;
               $errorMessage = $ex.Message
               $errorExtent = $null;
               if ($ex.ErrorId -eq 'MissingMandatoryParameter') {
                  $errorExtent = $Command.ErrorPosition
               } elseif ($ex.ParameterName -ne $null) {
                  [X3Argument]$errorArg = $Command.Arguments | Where-Object -Property Name -EQ -Value $ex.ParameterName
                  $errorExtent = $errorArg.ErrorPosition
               }
               Invoke-Error -Message $errorMessage -Extent $errorExtent
            } else { 
               throw $_
            }
         }
      } finally {
         $powershell.Dispose();
      }
   }
   end {}
}
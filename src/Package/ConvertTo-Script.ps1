using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

function ConvertTo-Script {
   [OutputType([string])]
   [CmdletBinding()]
   param([Parameter(Mandatory = $true)]
         [X3Manifest]$Manifest,
         [ValidateSet('Install')]
         [X3TargetType]$Target = 'Install',
         [Parameter(Mandatory = $true)]
         $Path,
         $Indent = '   ')

   process {
      $ret = [System.Text.StringBuilder]::new()
      [int]$depth = 0
      if ($Target -eq [X3TargetType]::Install) { 
         [System.Collections.Generic.Dictionary[string, object]]$externalLiterals = [Dictionary[string, object]]::new();

         # generate documentation
         $scriptDocTemplate = @"
<#
.SYNOPSIS
Install package

{0}
#>         
"@         
         $parameterDocTemplate = @"
.PARAMETER {0}
{1}
"@
         $parameterDocList =  $Manifest.Parameters | ForEach-Object -Process {
            if ([string]::IsNullOrWhiteSpace($_.Description)) {
               $parameterDescription = $_.Title
            } else {
               $parameterDescription = $_.Description
            }
            $parameterDocTemplate -f $_.Name,$parameterDescription
         }
         $null = $ret.AppendFormat($scriptDocTemplate, ($parameterDocList -join ([System.Environment]::NewLine * 2))).AppendLine();

         # set up variable rewriter
         # $variableMapping = [System.Tuple[[string[]],[string]][]]@($Manifest.Parameters | ForEach-Object -Process { [Tuple[[string[]],[string]]]::new(@('X3Deploy','Parameter',$_.Name), $_.Name) })
         # [DeferredVariableRewriter]$deferredVariableRewriter = [DeferredVariableRewriter]::new($variableMapping)

         # generate param block
         $null = $ret.AppendLine('param(');
         $depth++
         for ($parameterNum = 0; $parameterNum -lt $Manifest.Parameters.Count; $parameterNum++) {
            $parameterDirective = $Manifest.Parameters[$parameterNum];
            $null = $ret.Append($Indent * $depth);
            $null = $ret.Append('[Parameter(Mandatory = $').Append($parameterDirective.Mandatory.ToString().ToLowerInvariant());
            $null = $ret.AppendLine(')]');
            $null = $ret.Append($Indent * $depth);
            $null = $ret.Append('[').Append($parameterDirective.Type).Append(']');
            $null = $ret.Append('$').Append($parameterDirective.Name);
            if ($parameterDirective.Default -ne $null) {
               $null = $ret.Append(' = ')
               $null = $ret.Append((Write-Literal -Value $parameterDirective.Default))
            }
            if ($parameterNum -lt $Manifest.Parameters.Count - 1) {
               $null = $ret.Append(',');
            }
            $null = $ret.AppendLine();
         }
         $depth--
         $null = $ret.AppendLine(')').AppendLine();

         # boostrap own module
         
         $myModule = Get-Module -Name X3Deploy
         $installedModule = Get-Module -Name X3Deploy -ListAvailable
         
         $null = $ret.AppendLine("# boostrap own module").Append("Import-Module -Name ");
         if ($installedModule -eq $null -or $installedModule.Version -ne $myModule.Version) {
            $null = $ret.Append($myModule.Path);
         } else {
            $null = $ret.Append("X3Deploy -RequiredVersion ").Append($myModule.Version.ToString(3));
         }
         $null = $ret.AppendLine().AppendLine();
         
         # create deployment context
         $includeStatements = ($Manifest.Includes | ForEach-Object -Process { 
               ($Indent * 2) + '{0} = [X3IncludeResult]::FromBasePath((Join-Path -Path $PSScriptRoot -ChildPath {0}))' -f $_.Name 
            }) -join [Environment]::NewLine
         
         # TODO might be better to write the AST instead of mapping these, but this is easier/quicker
         $parameterStatements = ($Manifest.Parameters | ForEach-Object -Process { 
               ($Indent * 2) + '{0} = ${0}' -f $_.Name 
            }) -join [Environment]::NewLine

         $null = $ret.AppendLine("# create deployment context").AppendFormat(@'
$X3Deploy = [PSCustomObject][Ordered]@{{
   Include = [PSCustomObject][Ordered]@{{
{0}
   }}
   Literals = (Import-CliXml -Path $PSScriptRoot\Install-Package.Literals.xml)
}}
'@, $includeStatements, $parameterStatements).AppendLine();         

         $literalInjectionPosition = $ret.Length

         # generate module import block
         $null = $ret.AppendLine().AppendLine("# required modules")
         foreach ($requireDirective in $Manifest.Requires) {
            # TODO FIX THIS
            #$invocation = Write-Invocation -Verb Require -Noun $requireDirective.Type -Name $requireDirective.Name -Arguments $requireDirective.Arguments -ExternalLiterals $externalLiterals -DeferredVariableRewriter $deferredVariableRewriter
            $null = $ret.AppendLine($invocation).AppendLine()
         }

         # generate install steps
         $null = $ret.AppendLine().AppendLine("# install steps")
         foreach ($installDirective in $Manifest.Install) { 
            $invocation = Write-Invocation -Command $installDirective -ExternalLiterals $externalLiterals
            $null = $ret.AppendLine($invocation).AppendLine()
         }

         # create literals object for serialization
         $literalInjection = @()
         $literals = [PSObject]::new();
         foreach ($externalizedLiteral in $externalLiterals.GetEnumerator()) {
            if ($externalizedLiteral.Value -is [X3DeferredExpression]) {
               # this is so dirty, had no idea Clixml was so useless
               $literalInjection += "`$X3Deploy.Literals.{0}.Functions = [System.Collections.Generic.Dictionary[string,ScriptBlock]]::new()" -f $externalizedLiteral.Key
               $literalPSVariables = @($externalizedLiteral.Value.CapturedVariables | ForEach-Object -Process { Write-Literal -Value $_ })
               $literalInjection += "`$X3Deploy.Literals.{0}.Variables = [System.Collections.Generic.List[PSVariable]]::new([PSVariable[]]@({1}))" -f $externalizedLiteral.Key,($literalPSVariables -join ',')
               Add-Member -InputObject $literals -MemberType NoteProperty -Name $externalizedLiteral.Key -Value @{}
            } else {
               Add-Member -InputObject $literals -MemberType NoteProperty -Name $externalizedLiteral.Key -Value $externalizedLiteral.Value
            }
         }
         Export-Clixml -Path (Join-Path -Path $Path -ChildPath "Install-Package.Literals.xml") -InputObject $literals -Encoding UTF8         
         $null = $ret.Insert($literalInjectionPosition, ($literalInjection -join [System.Environment]::NewLine));
      }
      $ret.ToString();
   }
}
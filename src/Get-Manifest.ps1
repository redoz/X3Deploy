using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language


function Get-Manifest {
   [CmdletBinding()]
   param([Parameter(Mandatory = $true, Position = 0)][string]$Name,
         [Parameter(Mandatory = $true, Position = 1)][scriptblock]$Definition,
         [string]$Path,
         [switch]$PassThru = $false,
         [switch]$Force = $false)

   process {
      Set-Variable -Name X3Deploy -Value $null

      $manifestAst = $Definition.Ast.Parent.Parent;
      $preProcessor = [ManifestPreProcessor]::new();
      
      [CommandAst]$newManifestAst = $preProcessor.Rewrite($manifestAst);
      
      [PipelineAst]$pipelineAst = [PipelineAst]::new([X3Extent]::Null, [CommandBaseAst[]]@($newManifestAst))
      [StatementBlockAst]$statementBlockAst = [StatementBlockAst]::new([X3Extent]::Null, [StatementAst[]]@($pipelineAst) , $null)
      [NamedBlockAst]$endBlockAst = [NamedBlockAst]::new([X3Extent]::Null, [TokenKind]::End, $statementBlockAst, $true);
      $scriptBlockAst = [ScriptBlockAst]::new([X3Extent]::Null, $null, $null, $null, $null, $null, $endBlockAst.Copy(), $null);
      
      $newDefinition = $scriptBlockAst.GetScriptBlock();

      $code = [CodeGen]::Write($scriptBlockAst, [CodegenOptions]::None);
      Set-Content -Path c:\temp\manifest.ps1 -Value $code

      # create manifest
      [X3Manifest]$manifest = . $newDefinition.GetNewClosure()
      
      # validate manifest
      # TODO maybe move this to Test-Manifest
      Test-Manifest -Manifest $manifest
      
      if ($PassThru.IsPresent) {
         $manifest
      } else {
         # create temp staging folder
         if ($Path -eq '') {
            $outputPath = [System.IO.Path]::GetDirectoryName($MyInvocation.ScriptName);
         } else {
            $outputPath = $Path;
         }
         $stagingPath = Join-Path -Path $outputPath -ChildPath ("{0}_staging_{1}" -f $manifest.Name,([Guid]::NewGuid().ToString('n')))
         [void](New-Item -ItemType Container -Path $stagingPath)
         # move all includes into said folder
         foreach ($include in $manifest.Includes) {
            Invoke-Include -Directive $include -DestinationPath (Join-Path -Path $stagingPath -ChildPath $include.Name)
         }

         # generate install script
         $installScript = ConvertTo-Script -Manifest $manifest -Target Install -Path $stagingPath
         Set-Content -Path (Join-Path -Path $stagingPath -ChildPath 'Install-Package.ps1') -Value $installScript -Encoding UTF8

         # create archive
         $archivePath = Join-Path -Path $outputPath -ChildPath ($manifest.Name + '.zip');
         if ((Test-Path -LiteralPath $archivePath -PathType Leaf) -and $Force.IsPresent) {
            Remove-Item -LiteralPath $archivePath -Force
         }
         Compress-Archive -Path (Join-Path -Path $stagingPath -ChildPath '*') -CompressionLevel Optimal -DestinationPath $archivePath

         # remove temp staging folder
         start $stagingPath
         # Remove-Item -Path $stagingPath -Recurse -Force
      }
   }
}

# Manifest -PassThru {
#    Require {}
#    Include {
#    }
#    Parameters {}
#    Install {
#       File {
#          Foo = "Bar"
#       }
#    }
# }
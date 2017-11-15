$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest


# internal
. $PSScriptRoot\Types.ps1
. $PSScriptRoot\Join-ScriptExtent.ps1

. $PSScriptRoot\Language\BaseAstVisitor.ps1
. $PSScriptRoot\Language\UsingExpressionAstFinder.ps1
. $PSScriptRoot\Language\VariableReferenceFinder.ps1
. $PSScriptRoot\Language\ManifestPreProcessor.ps1

. $PSScriptRoot\Internals\Get-DefinedParameter.ps1
. $PSScriptRoot\Internals\Get-PositionMessage.ps1
. $PSScriptRoot\Internals\Resolve-Command.ps1
. $PSScriptRoot\Internals\Test-Command.ps1
. $PSScriptRoot\Internals\Invoke-Error.ps1

# package related scripts
. $PSScriptRoot\Package\DeferredVariableRewriter.ps1
. $PSScriptRoot\Package\Write-Literal.ps1
. $PSScriptRoot\Package\Write-Invocation.ps1
. $PSScriptRoot\Package\ConvertTo-Script.ps1
. $PSScriptRoot\Package\CodeGen.ps1
. $PSScriptRoot\Package\AstUtils.ps1

. $PSScriptRoot\Invoke-Include.ps1
. $PSScriptRoot\Include\Include-Path.ps1

. $PSScriptRoot\New-DeferredExpression.ps1

# external
. $PSScriptRoot\Test-Manifest.ps1
. $PSScriptRoot\New-Manifest.ps1
. $PSScriptRoot\Get-Manifest.ps1

# components
$componentList = Get-Item -Path $PSScriptRoot\Components\*.ps1
foreach ($component in $componentList) {
   . $component
}

Export-ModuleMember -Function New-Manifest, New-Parameter, New-Include, New-Require, New-Install, New-DeferredExpression, Test-Manifest, New-Argument, Test-Command
Export-ModuleMember -Function Get-Manifest

# components
Export-ModuleMember -Function Invoke-X3File
using namespace System.Management.Automation;
using namespace System.Management.Automation.Language;

Describe 'AstComparer' {
   BeforeAll {
      . $PSScriptRoot\AstComparer.ps1
      $DebugPreference = "SilentlyContinue"
   }

   function CompareAgainstSelf($ast) {
      $result = [AstComparer]::Compare($ast, $ast)
      It "Should be equal" {
         # TODO This should parse $script into an AST and compare those instead of the text
         $result | Should Be $null
      } 
   }

   function AstEquals([Ast]$expected, [Ast]$actual) {
      $result = [AstComparer]::Compare($expected, $actual)
      It "Should be equal" {
         # TODO This should parse $script into an AST and compare those instead of the text
         $result | Should Be $null
      } 
   }

   function AstNotEquals([Ast]$expected, [Ast]$actual) {
      $result = [AstComparer]::Compare($expected, $actual)
      It "Should not be equal" {
         # TODO This should parse $script into an AST and compare those instead of the text
         $result | Should Not Be $null
      } 
      return $result
   }

   Context 'Empty Script Block' {
      CompareAgainstSelf({}.Ast)
   }

   Context 'Nested Empty Script Block' {
      CompareAgainstSelf({{}}.Ast)
   }

   Context 'Script Block With Empty Param Block' {
      CompareAgainstSelf({param()}.Ast)
   }

   Context 'Script Block With Param Block Containing Single Parameter' {
      CompareAgainstSelf({param($a)}.Ast)
   }

   Context 'Script Block With Param Block Containing Single Parameter with Type Information' {
      CompareAgainstSelf({param([string]$a)}.Ast)
   }

   Context 'Script Block With Param Block Containing Single Parameter with Type Information and ParameterAttribute' {
      CompareAgainstSelf({param([Parameter(Mandatory=$true,Position=0)][string]$a)}.Ast)
   }

   Context 'Script Block With Single Variable Reference' {
      CompareAgainstSelf({$_}.Ast)
   }

   Context 'Script Block With Using Scoped Variable Reference' {
      CompareAgainstSelf({$using:foo}.Ast)
   }

   Context 'Script Block With Using Scoped Variable Reference and Member Access' {
      CompareAgainstSelf({$using:foo.Bar}.Ast)
   }

   Context 'Script Block With Global Scoped Variable Reference' {
      CompareAgainstSelf({$global:foo}.Ast)
   }

   Context 'Script Block With Global Scoped Variable Reference and Member Access' {
      CompareAgainstSelf({$global:foo.Bar}.Ast)
   }

   Context 'Script Block With Command With No Parameters' {
      CompareAgainstSelf({Get-Date}.Ast)
   }

   Context 'Script Block With Command With Positional Parameters' {
      CompareAgainstSelf({Get-Date 0 'abc' "abc" $true $null}.Ast)
   }

   Context 'Script Block With Command With Named Parameters' {
      CompareAgainstSelf({Get-Date -Year 100 -Month 10 -Day 2}.Ast)
   }

   Context 'Script Block With Command With Switch Parameter' {
      CompareAgainstSelf({Get-Date -Debug}.Ast)
   }

   
   Context 'Script Block With Command With Negated Switch Parameter' {
      CompareAgainstSelf({Get-Date -Debug:$false}.Ast)
   }

   Context 'Script Block With Pipeline' {
      CompareAgainstSelf({Get-Date | Select-Object -Property Year}.Ast)
   }

   Context 'Script Block With Pipeline Wrapped in Member Access' {
      CompareAgainstSelf({(Get-Date | Select-Object -Property Year).Year}.Ast)
   }

   Context 'Script Block With Empty HashTable Literal' {
      CompareAgainstSelf({@{}}.Ast)
   }

   Context 'Script Block With Empty Array Literal' {
      CompareAgainstSelf({@()}.Ast)
   }

   Context 'Script Block With Array Literal' {
      CompareAgainstSelf({@(1,2,"ab",'ab')}.Ast)
   }

   Context 'Script Block With Param Block Containing Single Parameter' {
      $result = AstNotEquals -Expected {param($a)}.Ast -Actual {param($b)}.Ast
   }

   Context 'Script Block With Pipeline Wrapped in Member Access' {
      $result = AstNotEquals -Expected {(Get-Date | Select-Object -Property Year).Year}.Ast -Actual {(Get-Date | Select-Object -Property Month).Year}.Ast
   }

   Context 'ManifestPreProcessor'  {
      $tokens = $null; $errors = $null;
      $ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path -Path ("$PSScriptRoot\..\..\src\Language\ManifestPreProcessor.ps1")), [ref]$tokens, [ref]$errors)
      CompareAgainstSelf($ast);
   }
}

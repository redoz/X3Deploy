using namespace System.Management.Automation;
using namespace System.Management.Automation.Language;

Describe 'CodeGen' {
   BeforeAll {
      . $PSScriptRoot\..\..\src\Package\CodeGen.ps1
      . $PSScriptRoot\..\Utils\AstComparer.ps1
      $DebugPreference = "SilentlyContinue"
   }

   function RoundTrip($ast) {
      $script = [CodeGen]::Write($ast, [CodeGenOptions]::None)
      $name = $ast.Extent.Text
      if ($ast.Extent.StartLineNumber -ne $ast.Extent.EndLineNumber) {
         $name = '...';
      }
      It "Should Equal '$name'" {
         $tokens = $null; $errors = $null;
         $actual = [System.Management.Automation.Language.Parser]::ParseInput($script, [ref]$tokens, [ref]$errors)      
         # unwrap junk from ParseInput(...)
         $actual = $actual.EndBlock.Statements[0].PipelineElements[0].Expression.ScriptBlock;
         [AstComparer]::Compare($ast, $actual) | Should Be $null
      } 
   }

   function RoundTripRaw($ast) {
      $script = [CodeGen]::Write($ast, [CodeGenOptions]::SkipContainer)
      It "Ast Should Be Equal" {
         $tokens = $null; $errors = $null;
         $actual = [System.Management.Automation.Language.Parser]::ParseInput($script, [ref]$tokens, [ref]$errors)      
         [AstComparer]::Compare($ast, $actual) | Should Be $null
      }  
   }

   Context 'Empty Script Block' {
      RoundTrip({}.Ast)
   }

   Context 'Nested Empty Script Block' {
      RoundTrip({{}}.Ast)
   }

   Context 'Script Block With Empty Param Block' {
      RoundTrip({param()}.Ast)
   }

   Context 'Script Block With Param Block Containing Single Parameter' {
      RoundTrip({param($a)}.Ast)
   }

   Context 'Script Block With Param Block Containing Single Parameter with Type Information' {
      RoundTrip({param([string]$a)}.Ast)
   }

   Context 'Script Block With Param Block Containing Single Parameter with Type Information and ParameterAttribute' {
      RoundTrip({param([Parameter(Mandatory=$true,Position=0)][string]$a)}.Ast)
   }

   Context 'Script Block With Single Variable Reference' {
      RoundTrip({$_}.Ast)
   }

   Context 'Script Block With Using Scoped Variable Reference' {
      RoundTrip({$using:foo}.Ast)
   }

   Context 'Script Block With Using Scoped Variable Reference and Member Access' {
      RoundTrip({$using:foo.Bar}.Ast)
   }

   Context 'Script Block With Global Scoped Variable Reference' {
      RoundTrip({$global:foo}.Ast)
   }

   Context 'Script Block With Global Scoped Variable Reference and Member Access' {
      RoundTrip({$global:foo.Bar}.Ast)
   }

   Context 'Script Block With Command With No Parameters' {
      RoundTrip({Get-Date}.Ast)
   }

   Context 'Script Block With Command With Positional Parameters' {
      RoundTrip({Get-Date 0 'abc' "abc" $true $null}.Ast)
   }

   Context 'Script Block With Command With Named Parameters' {
      RoundTrip({Get-Date -Year 100 -Month 10 -Day 2}.Ast)
   }

   Context 'Script Block With Command With Switch Parameter' {
      RoundTrip({Get-Date -Debug}.Ast)
   }

   
   Context 'Script Block With Command With Negated Switch Parameter' {
      RoundTrip({Get-Date -Debug:$false}.Ast)
   }

   Context 'Script Block With Pipeline' {
      RoundTrip({Get-Date | Select-Object -Property Year}.Ast)
   }

   Context 'Script Block With Pipeline Wrapped in Member Access' {
      RoundTrip({(Get-Date | Select-Object -Property Year).Year}.Ast)
   }

   Context 'Script Block With Empty HashTable Literal' {
      RoundTrip({@{}}.Ast)
   }

   Context 'Script Block With Empty Array Literal' {
      RoundTrip({@()}.Ast)
   }

   Context 'Script Block With Array Literal' {
      RoundTrip({@(1,2,"ab",'ab')}.Ast)
   } 


   Context 'Array Type' {
      RoundTrip({[string[]]}.Ast)
   }

   Context 'If Statement' {
      RoundTrip({
         if ($true) {
            Write-Host -Object "true"
         } elseif ($false) {
            Write-Host -Object "false"
         } else {
            Write-Host -Object "else"
         }
      }.Ast)
   }

   Context 'Invokation' {
      RoundTrip({ & {} }.Ast)
   }

   Context 'String With Escaped Chars' {
      RoundTrip({"`$null" }.Ast)
   }

   Context 'Generic Type' {
      RoundTrip({ [System.Tuple[[string[]],[string]][]] }.Ast)
   }

   Context 'Generic Typed Variable' {
      RoundTrip({ [System.Tuple[[string[]],[string]][]]$var }.Ast)
   }


   Context 'Switch' {
      RoundTrip({ 
         switch ($foo) {
            "bar" {1}
            "foo" {2}
            3     {3}
            default {X}
         }
       }.Ast)
   }

   Context 'Enum' {
      RoundTrip({ 
         enum Bar {
            Foo = 3
            Bar= 3
         }
       }.Ast)
   }

   Context 'Expandable string' {
      RoundTrip({ "`$null = $foo" }.Ast)
   }

   $ps1Files = Get-ChildItem -Path "$PSScriptRoot\..\..\" -Filter "*.ps1" -Recurse
   $resolvedPath = (Resolve-Path -Path "$PSScriptRoot\..\..\").Path
   foreach ($ps1File in $ps1Files) {
      Context $ps1File.FullName.SubString($resolvedPath.Length) {
         $tokens = $null; $errors = $null
         $ast = [System.Management.Automation.Language.Parser]::ParseFile($ps1File.FullName, [ref]$tokens, [ref]$errors)

         RoundTripRaw($ast);
      }
   }
}

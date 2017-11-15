using namespace System.Management.Automation;
using namespace System.Management.Automation.Language;

Describe 'AstUtils' {
   BeforeAll {
      . $PSScriptRoot\..\..\src\Types.ps1
      . $PSScriptRoot\..\..\src\Package\CodeGen.ps1
      . $PSScriptRoot\..\..\src\Package\AstUtils.ps1
      $DebugPreference = "SilentlyContinue"
   }

   Context 'Variable reference' {
      $wrap = [AstUtils]::WrapArgument({$foo}.Ast);
      [string]$code = [CodeGen]::Write($wrap, [CodeGenOptions]::None)
      It "Should render without curlys or parenthesis" {
         $code | Should -Be '$foo'
      }
   }

   Context 'Variable reference with member access' {
      $wrap = [AstUtils]::WrapArgument({$foo.Bar}.Ast);
      [string]$code = [CodeGen]::Write($wrap, [CodeGenOptions]::None)
      It "Should render without curlys or parenthesis" {
         $code | Should -Be '$foo.Bar'
      }
   }

   Context 'Variable reference with method call' {
      $wrap = [AstUtils]::WrapArgument({$foo.Bar()}.Ast);
      [string]$code = [CodeGen]::Write($wrap, [CodeGenOptions]::None)
      It "Should render without parenthesis" {
         $code | Should -Be '$foo.Bar()'
      }
   }

   Context 'Static Member access' {
      $wrap = [AstUtils]::WrapArgument({[DateTime]::Now}.Ast);
      [string]$code = [CodeGen]::Write($wrap, [CodeGenOptions]::None)
      It "Should render with parenthesis" {
         $code | Should -Be '([DateTime]::Now)'
      }
   }

   Context 'Static Member access with method call' {
      $wrap = [AstUtils]::WrapArgument({[DateTime]::Now.AddDays(1)}.Ast);
      [string]$code = [CodeGen]::Write($wrap, [CodeGenOptions]::None)
      It "Should render with parenthesis" {
         $code | Should -Be '([DateTime]::Now.AddDays(1))'
      }
   }
}

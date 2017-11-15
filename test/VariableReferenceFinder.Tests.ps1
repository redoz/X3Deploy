
Describe "VariableReferenceFinder" {
   BeforeAll {
      . $PSScriptRoot\..\src\Language\VariableReferenceFinder.ps1
   }
   Context 'Empty ScriptBlock' {
      $result = [VariableReferenceFinder]::FindAll({}.Ast, @())

      It "Should find zero references" {
         $result.Count | Should Be 0
      }
   }

   Context 'Simple Reference' {
      $result = [VariableReferenceFinder]::FindAll({$foo}.Ast, @())

      It 'Should find ''$foo'' references' {
         $result.Count | Should Be 1
         $result[0].Item1 | Should Be 'foo'
      }
   }

   Context 'Reference with Indexing' {
      $result = [VariableReferenceFinder]::FindAll({$foo['bar']}.Ast, @())

      It 'Should find ''$foo'' references' {
         $result.Count | Should Be 1
         $result[0].Item1 | Should Be 'foo'
      }
   }

   Context 'Nested Reference' {
      $result = [VariableReferenceFinder]::FindAll({$foo.bar}.Ast, @())

      It 'Should find ''$foo'' references' {
         $result.Count | Should Be 1
         $result[0].Item1 | Should Be 'foo'
      }
   }

   Context 'Simple Reference Inside Nested ScriptBlock' {
      $result = [VariableReferenceFinder]::FindAll({ &{ $foo.bar } }.Ast, @())

      It 'Should find ''$foo'' references' {
         $result.Count | Should Be 1
         $result[0].Item1 | Should Be 'foo'
      }
   }

   Context 'Assignment' {
      $result = [VariableReferenceFinder]::FindAll({$foo = "abc"}.Ast, @())

      It 'Should not find ''$foo'' references' {
         $result.Count | Should Be 0
      }
   }

   Context 'Assignment with Reference' {
      $result = [VariableReferenceFinder]::FindAll({$foo = "abc"; Write-Host $foo}.Ast, @())

      It "Should find zero references" {
         $result.Count | Should Be 0
      }
   }

   Context 'Reference with Subseqnent Assignment' {
      $result = [VariableReferenceFinder]::FindAll({Write-Host $foo;$foo = "abc"}.Ast, @())

      It 'Should find ''$foo'' references' {
         $result.Count | Should Be 1
         $result[0].Item1 | Should Be 'foo'
      }
   }
}
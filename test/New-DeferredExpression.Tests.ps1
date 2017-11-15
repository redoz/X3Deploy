
Describe "New-DeferredExpression" {
   BeforeAll {
      . $PSScriptRoot\..\src\Types.ps1
      . $PSScriptRoot\..\src\New-DeferredExpression.ps1
   }

   Context 'Non Existing'  {
      It "Should throw" {
         { New-DeferredExpression -Script {$moo} } | Should Throw 
      }
   }

   Context 'Declared in ScriptBlock'  {
      $result = New-DeferredExpression -Script {$foo = "var";$foo}

      It "Should not return null" {
         $result | Should Not Be $null
      }

      It "Should not contain any captured references" {
         $result.CapturedVariables | Should BeNullOrEmpty
      }
   }

   
   Context 'Declared in Outer Scope'  {
      $foo = "bar"
      $result = New-DeferredExpression -Script {$foo}

      It "Should not return null" {
         $result | Should Not Be $null
      }

      It "Should contain captured reference to `$foo" {
         $result.CapturedVariables.Count | Should Be 1
         $result.CapturedVariables[0].Name | Should Be 'foo'
         $result.CapturedVariables[0].Value | Should Be 'bar'
      }
   } 

   Context 'Declared in Nested Scope'  {
      $foo = "bar"
      $result = & { New-DeferredExpression -Script {$foo} }

      It "Should not return null" {
         $result | Should Not Be $null
      }

      It "Should contain captured reference to `$foo" {
         $result.CapturedVariables.Count | Should Be 1
         $result.CapturedVariables[0].Name | Should Be 'foo'
         $result.CapturedVariables[0].Value | Should Be 'bar'
      }
   }

   Context 'With Hidden Name'  {
      $Script = "bar"
      $result = & { New-DeferredExpression -Script {$Script} }

      It "Should not return null" {
         $result | Should Not Be $null
      }

      It "Should contain captured reference to `$Script" {
         $result.CapturedVariables.Count | Should Be 1
         $result.CapturedVariables[0].Name | Should Be 'Script'
         $result.CapturedVariables[0].Value | Should Be 'bar'
      }
   }
}
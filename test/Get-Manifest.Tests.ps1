
Describe 'Get-Manifest' {
   BeforeAll {
      # TODO clean this up, seems wrong
      Import-Module -Name $PSScriptRoot\..\src\X3Deploy.psd1
      
   }

   Context 'Empty manifest definition' {
      $manifest = Manifest 'TestManifest' {
         Require {}
         Include {}
         Parameters {}
         Install {}
      } -PassThru

      It "Manifest should not be null" {
         $manifest | Should Not Be $null
      }

      It "Manifest name should equal 'TestManifest'" {
         $manifest.Name | Should Be 'TestManifest'
      }

      It "Manifest should of type [X3Manifest]" {
         $manifest.GetType().Name | Should Be 'X3Manifest'
      }

      It "Manifest.Requires should be empty" {
         $manifest.Requires.Count -eq 0 | Should Be $true
      }

      It "Manifest.Includes should be empty" {
         $manifest.Includes.Count -eq 0 | Should Be $true
      }

      It "Manifest.Parameters should be empty" {
         $manifest.Parameters.Count -eq 0 | Should Be $true
      }

      It "Manifest.Install should be empty" {
         $manifest.Install.Count -eq 0 | Should Be $true
      }
   }
}
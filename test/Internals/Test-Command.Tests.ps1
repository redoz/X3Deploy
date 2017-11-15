Describe 'Test-Command' {
   BeforeAll {
      # TODO clean this up, seems wrong
      Import-Module -Name $PSScriptRoot\..\..\src\X3Deploy.psd1 -Force
   }   
   Context 'Single parameter set' {
      Function global:Invoke-X3Single {
         param([string]$One, [string]$Two)
      }
      
      $command = New-Install -Type Single -Name 'x' -Arguments @((New-Argument -Name One -Value "One"),(New-Argument -Name Twox -Value "Two"))
      $exception = $null
      try {
         Test-Command -Command $command
      } catch {
         $exception = $_
      }
      
      It "Should throw" {
         $exception | Should -Not -BeNullOrEmpty
      }
      
   }
   Context 'Multiple parameter set' {
      
   }


}
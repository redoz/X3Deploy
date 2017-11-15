. ..\Get-Manifest.ps1

$x = Manifest 'PackageThisShit' -PassThru {
   Require {
      Module 'Pester' {
         MinimumVersion = '4.0'
      }
   }
   # Include {
   #    1..10 | ForEach-Object {
   #       Path 'AppBinaries' {
   #          ConstantStringArrayProcessed = "foo","bar" | ForEach-Object -Process {$_.ToUpperInvariant()}
   #          ConstantStringProcessed = "foo" | ForEach-Object -Process {$_.ToUpperInvariant()}
   #          ConstantString = "foo" 
   #          ConstantNumber = 4
   #          GetDateResult = Get-Date
   #          GetDateWithFormatting = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
   #          ProcessedGetDateResult = Get-Date | ForEach-Object -Process {$_.ToString("yyyy-MM-dd")}
   #          ScriptBlock = {
   #             return "foo";
   #          }            
   #       }
   #    }   
   # }
   Parameters {
      Parameter 'ccc' {
         Title = 'Connection String' 
         Description = 'Conection string for main MSSQL database'
         Mandatory = $true
      }
   }
   Install {}
}
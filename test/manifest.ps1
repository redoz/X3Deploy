param($Source = "C:\dev\tmx\Tmx.Storage\src\Tmx.Storage.ServiceHost\bin\", [string]$Version = "0.0.0")

Import-Module -Name 'C:\dev\X3Deploy\src\X3Deploy.psd1' -Force -Verbose

Manifest "Tmx.Storage_$Version" -Force -Verbose -Debug {
   # required powershell modules
   Require {
      # Module 'Pester' {
      #    MinimumVersion = '4.0'
      # }
   }

   # these files will be made available to the Install steps
   Include {
      Path 'AppBinaries' {
         Source = $Source
         Recurse = $true
      }
   }  

   # parameters that should be specified when deploying package 
   Parameters {
      Parameter 'Destination' {
         Title = 'Destination Path' 
         Description = 'This is where the service will be installed'
         Default = 'c:\TheMediaExchange_Install\Storage\'
      }
      Parameter 'ConnectionString' {
         Title = 'Connection String' 
         Description = 'Conection string for main MSSQL database'
         Default = 'Server=myServerAddress;Database=myDataBase;User Id=myUsername;Password=myPassword;'
      }
      Parameter 'LogFolder' {
         Title = 'Log Folder' 
         Description = 'Path where log files are created'
         Default = { Join-Path -Path $X3Deploy.Parameter.Destination -ChildPath "Logs" }
      }
   }

   # steps to be taken
   Install {
      FileCopy 'Copying application files' {
         SourcePath = Defer { $X3Deploy.Include.AppBinaries.Path }
         DestinationPath = Defer { $X3Deploy.Parameter.Destination }
         Recurse = $true
         Type = "Directory"
      }

      # XPathTransform 'Configuring Connection String' {
      #    Path = Defer {Join-Path -Verbose $Destination -ChildPath 'app.config' }
      #    XPath = 'x:configuration/x:connectionString/value()'
      #    Namespace = @{
      #       'x' = 'http://schemas.example.com/configuration-schema'
      #    }
      #    Value = Defer { $X3Deploy.Parameter.ConnectionString }
      # }

      # XPathTransform 'Configuring Log Path' {
      #    Path = Defer {Join-Path -Verbose $Destination -ChildPath 'app.config' }
      #    XPath = 'x:configuration/x:logPath/value()'
      #    Namespace = @{
      #       'x' = 'http://schemas.example.com/configuration-schema'
      #    }
      #    Value = Defer { $X3Deploy.Parameter.LogPath }
      # }
   }

   Test {
      Service 'Main Service' {
         
      }
   }

   Uninstall {
      Service {

      }
   }
}
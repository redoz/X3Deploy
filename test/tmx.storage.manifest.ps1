param($Source = "C:\dev\tmx\Tmx.Storage\src\Tmx.Storage.ServiceHost\bin\", [string]$Version = "0.0.0")

Import-Module -Name 'C:\dev\psdeploy\src\X3Deploy.psd1' -Force -Verbose

Manifest "Tmx.Storage_$Version" -Force {
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
         Default = 'c:\tmx\tmx.storage\'
      }

      Parameter 'ConnectionString' {
         Target = 'Install'
         Title = 'Connection String' 
         Description = 'Conection string for main MSSQL database'
         Default = 'Server=myServerAddress;Database=myDataBase;User Id=myUsername;Password=myPassword;'
      }
      Parameter 'LogPath' {
         Title = 'Log Folder' 
         Description = 'Path where log files are created'
         Default = "c:\AppData\tmx\tmx.storage\logs\"
      }
      Parameter 'Credential' {
         Target = 'Install'
         Type = 'Credential'
         Title = 'Service Credentials' 
      }      
   }

   # steps to be taken
   Install {
      File 'Deploying application files' {
         Path = $using:AppBinaries.Path
         Destination = $using:Destination
         Recurse = $true
         Type = "Directory"
      }

      Directory 'Create log folder' {
         Path = $using:LogPath
      }
      
      XmlPoke 'Configuring Connection String' {
         Path = Join-Path -Path $using:Destination -ChildPath 'app.config'
         XPath = 'x:configuration/x:connectionString/value()'
         Namespaces = @{
            'x' = 'http://schemas.example.com/configuration-schema'
         }
         Value = $using:ConnectionString
      }

      XmlPoke 'Configuring Log Path' {
         Path = Join-Path -Path $using:Destination -ChildPath 'app.config'
         XPath = 'x:configuration/x:logPath/value()'
         Namespaces = @{
            'x' = 'http://schemas.example.com/configuration-schema'
         }
         Value = $using:LogPath
      }

      Service 'Installing Service' {
         Name = "Tmx.Storage"
         Path = Join-Path -Path $using:Destination -ChildPath "Tmx.Storage.ServiceHost.exe"
         RunAs = $using:Credential
         Start = $true
      }
   }

   # Uninstall {
   #    Service {
   #       Name = "Tmx.Storage"
   #       Stop = $true
   #    }
   #    File 'Remove application binaries' {
   #       Path = Defer { $X3Deploy.Parameter.Destination }
   #       Force = $true
   #    }
   # }
}
Set-StrictMode -Version Latest

function New-Parameter {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]$Name,

      [ValidateNotNullOrEmpty()]
      [string]$Title = $Name,

      [string]$Description = '',

      [ValidateSet('String', 'Integer', 'Float', 'Boolean', 'Guid')]
      [ValidateNotNullOrEmpty()]
      [string]$Type = 'String',

      [switch]$Mandatory = $false,

      $Default = $null,

      [Switch]$Hidden = $false
   )


   [pscustomobject][ordered]@{
      __Type      = "PARAMETER"
      Name        = $Name
      Title       = $Title
      Description = $Description
      Type        = $Type
      Mandatory   = $Mandatory.IsPresent
      Default     = $Default
      Hidden      = $Hidden.IsPresent
   }
}

function New-XPathTransform {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      $Target,

      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      $XPath,

      [Parameter(Mandatory = $false)]
      [System.Collections.Generic.Dictionary[string,string]]$Namespace = @{},

      [Parameter(Mandatory = $true)]
      [ValidateScript({$_ -is [string] -or $_ -is [ScriptBlock]})]
      $Value
   )
}

function New-ReplaceTransform {
   [CmdletBinding()]
   param($Target,
      [Switch]$Regex = $false
   )
}

function New-RegistryTransform {
   [CmdletBinding()]
   param($Target
   )
}

function New-Manifest {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [string[]]$Files
   )
}

function Get-Manifest {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [string]$Path
   )    
}

function Get-Parameter {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [string]$Path
   )

   $manifest = Get-Manifest -Path $Path
   
   return $manifest.Parameters
}


function Start-Deployment {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [string]$Source,
      [Parameter(Mandatory = $true)]
      [string]$Destination
   )

   DynamicParam {
      $parameters = Get-Parameter -Path $Source

      $dynamicParameters = new-objectSystem.Management.Automation.RuntimeDefinedParameterDictionary

      foreach ($parameter in $parameters) {
         $parameterAttribute = New-Object System.Management.Automation.ParameterAttribute
         $parameterAttribute.Mandatory = $parameter.Mandatory
         $parameterAttribute.HelpMessage = $parameter.Description

         $attributeCollection = New-Object -TypeName System.Collections.ObjectModel.Collection[System.Attribute]
         $attributeCollection.Add($ageAttribute)
         $parameterDefinition = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter($parameter.Name, [Int16], $attributeCollection)

         $dynamicParameters.Add($parameter.Name, $parameterDefinition)
      }
      return $dynamicParameters
   }

   Begin {}
   Process {
      # download file to temp folder (optional in case the manifest refers to a URI)
      # extract archive into temp folder
      # apply configuration
      # uninstall previous version
      # 
   }
   End {}
}

<#

New-Manifest -Files c:\temp\foo.bar\bin\release\ `
             -Parameters @(
                New-Parameter -Name ConnectionString -Title 'Connection String' -Description 'Connection string for database.' -Type String -Mandatory -Default '....'
                New-Parameter -Name LogPath -Title 'Log Path' -Description 'Folder for log files.' -Type String -Mandatory
             ) `
             -Transforms @(
                New-XPathransform -Target 'app.config' -XPath 'x:configuration/x:connectionString/value()' -Namespace @{x = "some-kind-of-schema-uri"} -Value {$ConnectionString}
             )


#>
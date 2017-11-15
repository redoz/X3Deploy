function New-Manifest {
   [OutputType('X3Manifest')]
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]$Name,
      [Parameter()]
      [X3Require[]]$Require,
      [Parameter()]
      [X3Include[]]$Include,
      [Parameter()]
      [X3Parameter[]]$Parameters,
      [Parameter()]
      [X3Install[]]$Install,
      [Parameter()]
      [System.Management.Automation.Language.IScriptExtent]$ErrorPosition = [X3Extent]::Null
   )

   process {
      
      if ($Require -eq $null) {$Require = @()}
      if ($Include -eq $null) {$Include = @()}
      if ($Parameters -eq $null) {$Parameters = @()}
      if ($Install -eq $null) {$Install = @()}

      $Require | ForEach-Object -Process {

      }
      
      $Include | ForEach-Object -Process {
         $command = Get-Command -Verb Include -Noun $_.Type
         if ($command -eq $null) {
            throw [System.Management.Automation.CommandNotFoundException]::new(("Command not found: Include-{0}" -f $_.Type))
         }
         
      }
      [X3Manifest]::new($ErrorPosition, $Name, $Require, $Include, $Parameters, $Install);
   }
}



function New-Parameter {
   [OutputType('X3Parameter')]
   [CmdletBinding()]
   param(
      [Parameter()]
      [X3TargetType[]]$Target = @(),

      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]$Name,

      [ValidateNotNullOrEmpty()]
      [string]$Title = $Name,

      [string]$Description = '',

      [ValidateSet('String', 'Integer', 'Float', 'Boolean', 'Guid', 'Credential')]
      [ValidateNotNullOrEmpty()]
      [string]$Type = 'String',

      [switch]$Mandatory = $false,

      $Default = $null,

      [Switch]$Hidden = $false,

      [Parameter()]
      [System.Management.Automation.Language.IScriptExtent]$ErrorPosition = [X3Extent]::Null
   )

   return [X3Parameter]::new($ErrorPosition, $Target, $Name, $Title, $Description, $Type, $Mandatory.IsPresent, $Hidden.IsPresent, $Default);
}
function New-Include { 
   [OutputType('X3Include')]
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]$Type,

      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]$Name,

      # [ValidateNotNullOrEmpty()]
      [X3Argument[]]$Arguments,

      [Parameter()]
      [System.Management.Automation.Language.IScriptExtent]$ErrorPosition = [X3Extent]::Null
   )
   process {
      [X3Include]::new($ErrorPosition, $Type, $Name, $Arguments);
   }
}

function New-Require { 
   [OutputType('X3Include')]
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [ValidateSet('Module')]
      [string]$Type,

      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]$Name,

      [ValidateNotNull()]
      [X3Argument[]]$Arguments,

      [Parameter()]
      [System.Management.Automation.Language.IScriptExtent]$ErrorPosition = [X3Extent]::Null
   )
   process {
      [X3Require]::new($ErrorPosition, $Type, $Name, $Arguments);
   }
}


function New-Install { 
   [OutputType('X3Install')]
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]$Type,

      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]$Name,

      [ValidateNotNullOrEmpty()]
      [X3Argument[]]$Arguments,

      [Parameter()]
      [System.Management.Automation.Language.IScriptExtent]$ErrorPosition = [X3Extent]::Null
   )
   process {
      [X3Install]::new($ErrorPosition, $Type, $Name, $Arguments);
   }
}
function New-Argument {
   [OutputType('X3Argument')]
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]$Name,

      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [object]$Value,

      [Parameter()]
      [System.Management.Automation.Language.IScriptExtent]$NameErrorPosition = [X3Extent]::Null,

      [Parameter()]
      [System.Management.Automation.Language.IScriptExtent]$ValueErrorPosition = [X3Extent]::Null
   )
   process {
      [X3Argument]::new($NameErrorPosition, $Name, $ValueErrorPosition, $Value);
   }   
}
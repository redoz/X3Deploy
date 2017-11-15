function Invoke-X3XmlPoke {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory = $true)]
      [string]$Path,
      [Parameter(Mandatory = $true)]
      [string]$XPath,
      [hashtable]$Namespaces = @{},
      [Parameter(Mandatory = $true)]
      $Value
   )

   begin {}
   process {

   }
   end{}
}
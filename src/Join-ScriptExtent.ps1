using namespace System.Management.Automation.Language;

function Join-X3ScriptExtent {
   param(
      [IScriptExtent[]]$Extent
   )

   [IScriptExtent[]]$nonNullExtents = @($Extent | Where-Object -FilterScript  { $_ -ne $null -and $_ -ne [X3Extent]::Null })

   if ($nonNullExtents.Count -eq 0)
   {
      return [X3Extent]::Null;
   } elseif ($nonNullExtents.Count -eq 1) {
      return $nonNullExtents[0];
   }

   $startOffset = [Linq.Enumerable]::Min($nonNullExtents.StartOffset -as [int[]])
   $endOffset   = [Linq.Enumerable]::Max($nonNullExtents.EndOffset -as [int[]])

   [X3ScriptPosition]$startScriptPosition = [X3ScriptPosition]::FromFile($nonNullExtents[0].File, $startOffset);
   [X3ScriptPosition]$endScriptPosition = [X3ScriptPosition]::FromFile($nonNullExtents[0].File, $endOffset);

   $text = [System.IO.File]::ReadAllText($startScriptPosition.File).Substring($startOffset, ($endOffset - $startOffset))

   return [X3Extent]::new($nonNullExtents[0].File, 
                          $startScriptPosition, 
                          $endScriptPosition, 
                          $startScriptPosition.LineNumber, 
                          $startScriptPosition.ColumnNumber, 
                          $endScriptPosition.LineNumber, 
                          $endScriptPosition.ColumnNumber, 
                          $text, 
                          $startOffset, 
                          $endOffset);
   
}
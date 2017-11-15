using namespace System.Collections.Generic;
using namespace System.Management.Automation.Language;

class X3Base {
   [IScriptExtent]$ErrorPosition;

   X3Base([IScriptExtent]$errorPosition){
      if ($errorPosition -eq $null) {
         $this.ErrorPosition = [X3Extent]::Null;
      } else {
         $this.ErrorPosition = $errorPosition;
      }
   }
}

class X3DeferredExpression : X3Base {
   [ScriptBlock]$Script;
   [IReadOnlyCollection[PSVariable]]$CapturedVariables;

   X3DeferredExpression([IScriptExtent]$errorPosition, [ScriptBlock]$script, [PSVariable[]]$capturedVariables) : base($errorPosition) {
      $this.Script = $script;
      $this.CapturedVariables = $capturedVariables;
   }

   [string]ToString() {
      return $this.Script.ToString();
   }
}

class X3Manifest : X3Base {
   [string]$Name;
   [IReadOnlyCollection[X3Require]]$Requires;
   [IReadOnlyCollection[X3Include]]$Includes;
   [IReadOnlyCollection[X3Parameter]]$Parameters;
   [IReadOnlyCollection[X3Install]]$Install;

   X3Manifest([IScriptExtent]$errorPosition,
              [string]$name,
              [X3Require[]]$requires,
              [X3Include[]]$includes,
              [X3Parameter[]]$parameters,
              [X3Install[]]$install) : base($errorPosition) {

      $this.Name = $name;
      $this.Requires = $requires;
      $this.Includes = $includes;
      $this.Parameters = $parameters;
      $this.Install = $install;
   }
}


class X3Require : X3Base {
   [string]$Type;
   [string]$Name;
   [IReadOnlyList[X3Argument]]$Arguments;

   X3Require([IScriptExtent]$errorPosition, [string]$type, [string]$name, [X3Argument[]]$arguments) : base($errorPosition) {
      $this.Type = $type;
      $this.Name = $name;
      $this.Arguments = $arguments;
   }
}

class X3Include : X3Base {
   [string]$Type;
   [string]$Name;
   [IReadOnlyList[X3Argument]]$Arguments;

   X3Include([IScriptExtent]$errorPosition, [string]$type, [string]$name, [X3Argument[]]$arguments) : base($errorPosition) {
      $this.Type = $type;
      $this.Name = $name;
      $this.Arguments = $arguments;
   }
}

enum X3ParameterType {
   String
   Integer
   Float
   Boolean
   Guid
   Credential
}

class X3Parameter : X3Base {
   [X3TargetType[]]$Target;
   [string]$Name;
   [string]$Title;
   [string]$Description;
   [string]$Type;
   [string]$Mandatory;
   [string]$Hidden;
   [object]$Default;

   X3Parameter([IScriptExtent]$errorPosition, [X3TargetType[]]$Target, [string]$name, [string]$title, [string]$description, [X3ParameterType]$type, [bool]$mandatory, [bool]$hidden, [object]$default) : base($errorPosition) {
      $this.Target = $Target;
      $this.Name = $name;
      $this.Title = $title;
      $this.Description = $description;
      $this.Type = $type;
      $this.Mandatory = $mandatory;
      $this.Hidden = $hidden;
      $this.Default = $default;
   }
}

enum X3TargetType {
   Install
   Uninstall
   Test
}

class X3Command : X3Base {
   [X3TargetType]$Target;
   [string]$Type;
   [string]$Name;
   [IReadOnlyList[X3Argument]]$Arguments;

   X3Command([IScriptExtent]$errorPosition, [X3TargetType]$target, [string]$type, [string]$name, [X3Argument[]]$arguments) : base($errorPosition) {
      $this.Target = $target;
      $this.Type = $type;
      $this.Name = $name;
      $this.Arguments = $arguments;
   }
}

class X3Install : X3Command {
   X3Install([IScriptExtent]$errorPosition, [string]$type, [string]$name, [X3Argument[]]$arguments) : base($errorPosition, [X3TargetType]::Install, $type, $name, $arguments) {
   }
}

class X3IncludeResult {
   static [X3IncludeResult]FromBasePath([string]$basePath) {
      return [X3IncludeResult]::new($basePath, (Get-ChildItem -Recurse -LiteralPath $basePath))
   }
   
   [string]$BasePath;
   [IReadOnlyCollection[System.IO.FileSystemInfo]]$Items;

   X3IncludeResult([string]$basePath, [System.IO.FileSystemInfo[]]$items) {
      $this.BasePath = $basePath;
      $this.Items = $items;
   }
}

class X3Argument : X3Base {
   [string]$Name;
   [IScriptExtent]$NameErrorPosition;
   [object]$Value;
   [IScriptExtent]$ValueErrorPosition;

   X3Argument([IScriptExtent]$nameErrorPosition, [string]$name, [IScriptExtent]$valueErrorPosition, [object]$value) : base((Join-X3ScriptExtent -Extent @($nameErrorPosition,$valueErrorPosition))) {
      $this.NameErrorPosition = $nameErrorPosition;      
      $this.Name = $name;
      $this.ValueErrorPosition = $valueErrorPosition;
      $this.Value = $value;
   }
}

class X3ScriptPosition : IScriptPosition {
   static [IScriptPosition]$Null = [X3ScriptPosition]::new($null, 0, 0, 0, '');

   static [X3ScriptPosition]FromFile([string]$path, [int]$offset) {
      [string]$contents = [System.IO.File]::ReadAllText($path);
      [int]$lineNum = 0;
      [int]$columnNum = -1;
      [string]$lineValue = '';

      $lastFound = $offset

      while ($lastFound -ge 0) {
         $lineNum += 1
         $prevCr = $contents.LastIndexOf("`r", $lastFound - 1);
         $prevLf = $contents.LastIndexOf("`n", $lastFound - 1);

         $lineStart = 0
         if ($prevCr -ge 0) {
            if ($prevLf -eq $prevCr + 1) {
               # found CRLF at $prevCr
               $lineStart = $prevCr + 2;
               $lastFound = $prevCr
            } elseif ($prevLf -gt $prevCr) {
               # found LF at $prevLf
               $lineStart = $prevLf + 1
               $lastFound = $prevLf
            } else { 
               # found CR at $prevCr
               $lineStart = $prevCr + 1
               $lastFound = $prevCr
            }
         } elseif ($prevLf -ge 0) {
            # found LF at $prevLf
            $lineStart = $prevLf + 1
            $lastFound = $prevLf
         } else {
            # no more lines
            $lineStart = 0
            $lastFound = -1
         }

         if ($columnNum -eq -1) {
            $columnNum = $offset - $lineStart + 1
            $lineEnd = $contents.IndexOfAny([char[]]@("`r","`n"), $lineStart)
            if ($lineEnd -ge 0) {
               $lineValue = $contents.Substring($lineStart, $lineEnd - $lineStart);
            } else { 
               $lineValue = $contents.Substring($lineStart);
            }
         }
      }

      return [X3ScriptPosition]::new($path, $lineNum, $columnNum, $offset, $lineValue);
   }

   hidden [string]$File;
   hidden [int]$LineNumber;
   hidden [int]$ColumnNumber;
   hidden [int]$Offset;
   hidden [string]$Line;

   X3ScriptPosition([string]$file, 
                    [int]$lineNumber,
                    [int]$columnNumber,
                    [int]$offset,
                    [string]$line) {
      $this.File = $file;
      $this.LineNumber = $lineNumber;
      $this.ColumnNumber = $columnNumber;
      $this.Offset = $offset;
      $this.Line = $line;
   }

   [string]get_File() {return $this.File;}
   [int]get_LineNumber() {return $this.LineNumber;}
   [int]get_ColumnNumber() {return $this.ColumnNumber;}
   [int]get_Offset() {return $this.Offset;}
   [string]get_Line() {return $this.Line;}
   [string]GetFullScript() {
      if ([string]::IsNullOrEmpty($this.File)) {
         return ''
      }
      return (Get-Content -Path $this.File -ErrorAction SilentlyContinue) 
   }
}

class X3Extent : IScriptExtent {
   static [IScriptExtent]$Null = [X3Extent]::FromLiteral($null);

   static [IScriptExtent]FromLiteral([string]$text) {
      return [X3Extent]::new($null,
                             [X3ScriptPosition]::Null,
                             [X3ScriptPosition]::Null,
                             0,
                             0,
                             0,
                             0,
                             $text,
                             0,
                             0);
   }

   hidden [string]$File;
   hidden [IScriptPosition]$StartScriptPosition;
   hidden [IScriptPosition]$EndScriptPosition;
   hidden [int]$StartLineNumber;
   hidden [int]$StartColumnNumber;
   hidden [int]$EndLineNumber;
   hidden [int]$EndColumnNumber;
   hidden [string]$Text;
   hidden [int]$StartOffset;
   hidden [int]$EndOffset;

   X3Extent([string]$file, 
            [IScriptPosition]$startScriptPosition, 
            [IScriptPosition]$endScriptPosition, 
            [int]$startLineNumber, 
            [int]$startColumnNumber, 
            [int]$endLineNumber, 
            [int]$endColumnNumber, 
            [string]$text, 
            [int]$startOffset, 
            [int]$endOffset) {
      $this.File = $file;
      $this.StartScriptPosition = $startScriptPosition;
      $this.EndScriptPosition = $endScriptPosition;
      $this.StartLineNumber  = $startLineNumber;
      $this.StartColumnNumber = $startColumnNumber;
      $this.EndLineNumber = $endLineNumber;
      $this.EndColumnNumber = $endColumnNumber;
      $this.Text = $text;
      $this.StartOffset = $startOffset;
      $this.EndOffset = $endOffset;
   }

   [string]get_File() {return $this.File;}
   [IScriptPosition]get_StartScriptPosition() { return $this.StartScriptPosition; }
   [IScriptPosition]get_EndScriptPosition() { return $this.EndScriptPosition; }
   [int]get_StartLineNumber() { return $this.StartLineNumber; }
   [int]get_StartColumnNumber() { return $this.StartColumnNumber; }
   [int]get_EndLineNumber() { return $this.EndLineNumber; }
   [int]get_EndColumnNumber() { return $this.EndColumnNumber; }
   [string]get_Text() { return $this.Text; }
   [int]get_StartOffset() { return $this.StartOffset; }
   [int]get_EndOffset() { return $this.EndOffset; }
}
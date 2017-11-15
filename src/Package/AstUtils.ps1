using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

class AstUtils { 
   static [Ast]Unwrap([ScriptBlockAst]$ast) {
      if ($ast.EndBlock -eq $null -or $ast.EndBlock.Statements.Count -gt 1) {
         throw "Cannot unwrap ScriptBlock.";
      }

      $inner = $ast.EndBlock.Statements[0];

      if ($inner -is [PipelineAst] -and $inner.PipelineElements.Count -eq 1) {
         $inner = $inner.PipelineElements[0];
      }

      if ($inner -is [CommandExpressionAst]) {
         $inner = $inner.Expression;
      } 

      return $inner;
   }

   static [Ast]WrapArgument([ScriptBlockAst]$ast) {
      if ($ast.EndBlock -eq $null) {
         throw "Cannot wrap ScriptBlock without EndBlock.";
      }
      if ($ast.EndBlock.Statements.Count -eq 1) {
         $inner = [AstUtils]::Unwrap($ast);
         if ($inner -is [VariableExpressionAst] -or ($inner -is [MemberExpressionAst] -and $inner.Expression -is [VariableExpressionAst])) {
            return $inner;
         } elseif ($inner -is [PipelineBaseAst]) {
            return [ParenExpressionAst]::new([X3Extent]::Null, $inner.Copy());
         } elseif ($inner -is [CommandBaseAst]) {
            return [ParenExpressionAst]::new([X3Extent]::Null, 
                                             [PipelineAst]::new([X3Extent]::Null, $inner.Copy()));
         } elseif ($inner -is [CommandElementAst]) {
            return [ParenExpressionAst]::new([X3Extent]::Null, 
                                             [PipelineAst]::new([X3Extent]::Null, 
                                                                [CommandAst]::new([X3Extent]::Null, 
                                                                                  [CommandElementAst[]]@($inner.Copy()), 
                                                                                  [TokenKind]::Unknown,
                                                                                  $null)));
         } else {
            throw "Not supported yet: $($inner.GetType().Name)"
         }
      } else {
         return [ParenExpressionAst]::new([X3Extent]::Null, 
                                          [PipelineAst]::new([X3Extent]::Null,
                                                             [CommandAst]::new([X3Extent]::Null,
                                                                               @([ScriptBlockExpressionAst]::new([X3Extent]::Null, $ast.Copy())),
                                                                               [TokenKind]::Ampersand,
                                                                               $null)));
      }
   }

   static [string]WriteArgument([Ast]$ast) {
      $ast = [AstUtils]::WrapArgument($ast);
      return [CodeGen]::Write($ast, [CodeGenOptions]::None);
   }
}
# class DeferredVariableRewriter : AstVisitor {
#    hidden [System.Tuple[[string[]],[string]][]]$variableMap;
#    hidden [System.Collections.Generic.List[System.Tuple[[IScriptExtent],[string]]]]$extents;

#    DeferredVariableRewriter([System.Tuple[[string[]],[string]][]]$variableMap) {
#       $this.variableMap = $variableMap
#    }

#    [string]Rewrite([Ast]$ast) {
#       $this.extents = [System.Collections.Generic.List[System.Tuple[[IScriptExtent],[string]]]]::new()
#       $ast.Visit($this)
#       $sortedExtents = $this.extents | Sort-Object -Descending -Property "Item1.StartOffset"
#       $script = $ast.ToString();
#       foreach ($extent in $sortedExtents) {
#          $startOffset = $extent.Item1.StartOffset - $ast.Extent.StartOffset
#          $endOffset = $extent.Item1.EndOffset - $ast.Extent.StartOffset
#          $script = $script.Substring(0, $startOffset + 1) + $extent.Item2 + $script.Substring($endOffset)
#       }
#       return $script;
#    }

#    [AstVisitAction] VisitVariableExpression([VariableExpressionAst]$variableExpressionAst) {
#       foreach ($mapping in $this.variableMap) {
#          if ($variableExpressionAst.VariablePath.UserPath -eq $mapping.Item1[0]) {
#             $memberAst = $variableExpressionAst.Parent -as [MemberExpressionAst];
#             for($memberNum = 1; $memberNum -lt $mapping.Item1.Count -and $memberAst -ne $null; $memberNum++) {
#                if ($memberAst.Member -is [StringConstantExpressionAst] -and $memberAst.Member.Value -eq $mapping.Item1[$memberNum]) {
#                   if ($memberNum -eq ($mapping.Item1.Count - 1)) {
#                      $this.extents.Add([System.Tuple[[IScriptExtent],[string]]]::new($memberAst.Extent, $mapping.Item2))
#                   }
#                   $memberAst = $memberAst.Parent;
#                } else {
#                   break;
#                }
#             }
#          }
#       }
#       return [AstVisitAction]::Continue;
#    }
# }

using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

class DeferredVariableRewriter : BaseAstVisitor { 
   
   static [Ast]Rewrite([Ast]$ast) {
      return $ast.Visit([DeferredVariableRewriter]::new());
   }

   [object] VisitUsingExpression([UsingExpressionAst]$usingExpressionAst) {
      return $usingExpressionAst.SubExpression.Visit($this);
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

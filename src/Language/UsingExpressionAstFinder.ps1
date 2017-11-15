using namespace System.Collections.Generic;
using namespace System.Management.Automation.Language;

class UsingExpressionAstFinder : AstVisitor {
   static [UsingExpressionAst[]]FindAll([Ast]$ast) {
      return [UsingExpressionAstFinder]::new().FindAllImpl($ast);
   }

   static [bool]Contains([Ast]$ast) {
      return [UsingExpressionAstFinder]::new().FindAllImpl($ast).Count -gt 0;
   }

   hidden [List[UsingExpressionAst]]$references;

   [UsingExpressionAst[]]FindAllImpl([Ast]$ast) {
      $this.references = [List[UsingExpressionAst]]::new();
      $ast.Visit($this);
      return $this.references.ToArray();
   }

   [AstVisitAction]VisitUsingExpression([UsingExpressionAst]$usingExpressionAst) {
      $this.references.Add($usingExpressionAst);
      return [AstVisitAction]::Continue;
   }
}

using namespace System.Collections.Generic;
using namespace System.Management.Automation.Language;

class VariableReferenceFinder : AstVisitor {
   static [bool]Contains([Ast]$ast, [String[]]$Exclude = @(), [bool]$excludeUsingScoped) {
      return ([VariableReferenceFinder]::new().FindAllReferences($ast, $Exclude, $excludeUsingScoped)).Length -gt 0;
   }

   static [Tuple[string,VariableExpressionAst][]]FindAll([Ast]$ast, [String[]]$Exclude = @(), [bool]$excludeUsingScoped) {
      return [VariableReferenceFinder]::new().FindAllReferences($ast, $Exclude, $excludeUsingScoped);
   }

   [HashSet[String]]$Exclude;
   [HashSet[string]]$Scope;

   hidden [HashSet[string]]$assigned;
   hidden [List[Tuple[string,VariableExpressionAst]]]$references;
   hidden [bool]$excludeUsingScoped;

   [Tuple[string,VariableExpressionAst][]]FindAllReferences([Ast]$ast, [IEnumerable[String]]$Exclude, [bool]$excludeUsingScoped) {
      $this.Exclude = [HashSet[String]]::new($Exclude);
      $this.Exclude.Add('true');
      $this.Exclude.Add('false');
      $this.Exclude.Add('null');
      $this.assigned = [HashSet[string]]::new();
      $this.references = [List[Tuple[string,VariableExpressionAst]]]::new();
      $this.excludeUsingScoped = $excludeUsingScoped;
      $ast.Visit($this);
      return $this.references;
   }

   [AstVisitAction]VisitVariableExpression([VariableExpressionAst]$variableExpressionAst) {
      if ($variableExpressionAst.VariablePath.IsVariable -and (-not($this.Exclude.Contains($variableExpressionAst.VariablePath.UserPath)))) {
         [bool]$skip = $false;
         if ($this.excludeUsingScoped) {
            # check if in using scope
            $parent = $variableExpressionAst.Parent;
            while ($parent -ne $null) {
               if ($parent -is [UsingExpressionAst]) {
                  $skip = $true;
                  break;
               }
               $parent = $parent.Parent;
            }
         }

         if (-not $skip) {
            if ($variableExpressionAst.Parent -is [AssignmentStatementAst] -and $variableExpressionAst.Parent.Left -eq $variableExpressionAst) {
               $this.assigned.Add($variableExpressionAst.VariablePath.UserPath)
            }
            elseif (-not $this.assigned.Contains($variableExpressionAst.VariablePath.UserPath)) {
               $this.references.Add([Tuple[string,VariableExpressionAst]]::new($variableExpressionAst.VariablePath.UserPath, $variableExpressionAst))
            }
         }
      }
      return [AstVisitAction]::Continue;
   }
}

using namespace System.Management.Automation
using namespace System.Management.Automation.Language

class BaseAstVisitor : ICustomAstVisitor {

   BaseAstVisitor() {
   }

   hidden [object]Visit($ast) {
      if ($ast -ne $null) {
         return $ast.Visit($this);
      } else {
         return $null;
      }
   }

   [object] VisitErrorStatement([ErrorStatementAst]$errorStatementAst) {
      # this type has no public constructor
      return $errorStatementAst.Copy(); 
   }

   [object] VisitErrorExpression([ErrorExpressionAst]$errorExpressionAst) {
      # this type has no public constructor
      return $errorExpressionAst.Copy();
   }

   [object] VisitScriptBlock([ScriptBlockAst]$scriptBlockAst) {
      return [ScriptBlockAst]::new($scriptBlockAst.Extent,
                                   [UsingStatementAst[]]$scriptBlockAst.UsingStatements.ForEach({$_.Visit($this)}),
                                   [AttributeAst[]]$scriptBlockAst.Attributes.ForEach({$_.Visit($this)}),
                                   $this.Visit($scriptBlockAst.ParamBlock),
                                   $this.Visit($scriptBlockAst.BeginBlock),
                                   $this.Visit($scriptBlockAst.ProcessBlock),
                                   $this.Visit($scriptBlockAst.EndBlock),
                                   $this.Visit($scriptBlockAst.DynamicParamBlock));
   }
   [object] VisitParamBlock([ParamBlockAst]$paramBlockAst) {
      return [ParamBlockAst]::new($paramBlockAst.Extent,
                                  [AttributeAst[]]$paramBlockAst.Attributes.ForEach({$_.Visit($this)}),
                                  [ParameterAst[]]$paramBlockAst.Parameters.ForEach({$_.Visit($this)}));
   }

   [object] VisitNamedBlock([NamedBlockAst]$namedBlockAst) {
      return [NamedBlockAst]::new($namedBlockAst.Extent,
                                  $namedBlockAst.BlockKind,
                                  [StatementBlockAst]::new($namedBlockAst.Extent,
                                                           [StatementAst[]]$namedBlockAst.Statements.ForEach({$_.Visit($this)}),
                                                           [TrapStatementAst[]]$namedBlockAst.Traps.ForEach({$_.Visit($this)})),
                                  $namedBlockAst.Unnamed);
   }

   [object] VisitTypeConstraint([TypeConstraintAst]$typeConstraintAst) {
      # nothing to descend into
      return $typeConstraintAst.Copy();
   }

   [object] VisitAttribute([AttributeAst]$attributeAst) {
      return [AttributeAst]::new($attributeAst.Extent,
                                 $attributeAst.TypeName,
                                 [ExpressionAst[]]$attributeAst.PositionalArguments.ForEach({$_.Visit($this)}),
                                 [NamedAttributeArgumentAst[]]$attributeAst.PositionalArguments.ForEach({$_.Visit($this)}));
   }
   [object] VisitNamedAttributeArgument([NamedAttributeArgumentAst]$namedAttributeArgumentAst) {
      return [NamedAttributeArgumentAst]::new($namedAttributeArgumentAst.Extent,
                                              $namedAttributeArgumentAst.ArgumentName,
                                              $namedAttributeArgumentAst.Argument.Visit($this),
                                              $namedAttributeArgumentAst.ExpressionOmitted);
   }

   [object] VisitParameter([ParameterAst]$parameterAst) {
      return [ParameterAst]::new($parameterAst.Extent,
                                 $parameterAst.Name.Visit($this),
                                 [AttributeBaseAst[]]$parameterAst.Attributes.ForEach({$_.Visit($this)}),
                                 $this.Visit($parameterAst.DefaultValue));
   }

   [object] VisitFunctionDefinition([FunctionDefinitionAst]$functionDefinitionAst) {
      return [FunctionDefinitionAst]::new($functionDefinitionAst.Extent,
                                          $functionDefinitionAst.IsFilter,
                                          $functionDefinitionAst.IsWorkflow,
                                          $functionDefinitionAst.Name,
                                          [ParameterAst[]]$functionDefinitionAst.Parameters.ForEach({$_.Visit($this)}),
                                          $functionDefinitionAst.Body.Visit($this));
   }

   [object] VisitStatementBlock([StatementBlockAst]$statementBlockAst) {
      return [StatementBlockAst]::new($statementBlockAst.Extent,
                                      [StatementAst[]]$statementBlockAst.Statements.ForEach({$_.Visit($this)}),
                                      [TrapStatementAst[]]$statementBlockAst.Traps.ForEach({$_.Visit($this)}));
   }
   [object] VisitIfStatement([IfStatementAst]$ifStmtAst) {
      return [IfStatementAst]::new($ifStmtAst.Extent, 
                                   [Tuple[PipelineBaseAst, StatementBlockAst][]]`
                                      $ifStmtAst.Clauses.ForEach({[Tuple[PipelineBaseAst, StatementBlockAst]]::new($_.Item1.Visit($this),$_.Item2.Visit($this))}),
                                   $this.Visit($ifStmtAst.ElseClause));
   }

   [object] VisitTrap([TrapStatementAst]$trapStatementAst) {
      return [TrapStatementAst]::new($trapStatementAst.Extent,
                                     $this.Visit($trapStatementAst.TrapType),
                                     $trapStatementAst.Body.Visit($this));
   }

   [object] VisitSwitchStatement([SwitchStatementAst]$switchStatementAst) {
      return [SwitchStatementAst]::new($switchStatementAst.Extent,
                                       $switchStatementAst.Label,
                                       $this.Visit($switchStatementAst.Condition),
                                       $switchStatementAst.Flags,
                                       [Tuple[ExpressionAst,StatementBlockAst][]]`
                                          $switchStatementAst.Clauses.ForEach({[Tuple[ExpressionAst,StatementBlockAst]]::new($_.Item1.Visit($this), $_.Item2.Visit($this))}),
                                       $this.Visit($switchStatementAst.Default));
   }

   [object] VisitDataStatement([DataStatementAst]$dataStatementAst) {
      return [DataStatementAst]::new($dataStatementAst.Extent,
                                     $dataStatementAst.Variable,
                                     [ExpressionAst[]]$dataStatementAst.CommandsAllowed.ForEach({$_.Visit($this)}),
                                     $dataStatementAst.Body.Visit($this));
   }

   [object] VisitForEachStatement([ForEachStatementAst]$forEachStatementAst) {
      return [ForEachStatementAst]::new($forEachStatementAst.Extent,
                                        $forEachStatementAst.Label,
                                        $forEachStatementAst.Flags,
                                        $this.Visit($forEachStatementAst.ThrottleLimit),
                                        $forEachStatementAst.Variable.Visit($this),
                                        $forEachStatementAst.Condition.Visit($this),
                                        $forEachStatementAst.Body.Visit($this));


      return $forEachStatementAst; 
   }

   [object] VisitDoWhileStatement([DoWhileStatementAst]$doWhileStatementAst) {
      return [DoWhileStatementAst]::new($doWhileStatementAst.Extent,
                                        $doWhileStatementAst.Label,
                                        $doWhileStatementAst.Condition.Visit($this),
                                        $doWhileStatementAst.Body.Visit($this));
   }
   [object] VisitForStatement([ForStatementAst]$forStatementAst) {
      return [ForStatementAst]::new($forStatementAst.Extent,
                                    $forStatementAst.Label,
                                    $this.Visit($forStatementAst.Initializer),
                                    $this.Visit($forStatementAst.Condition),
                                    $this.Visit($forStatementAst.Iterator),
                                    $this.Body.Visit($this));
   }

   [object] VisitWhileStatement([WhileStatementAst]$whileStatementAst) {
      return [WhileStatementAst]::new($whileStatementAst.Extent,
                                      $whileStatementAst.Label,
                                      $whileStatementAst.Condition.Visit($this),
                                      $whileStatementAst.Body.Visit($this));
   }

   [object] VisitCatchClause([CatchClauseAst]$catchClauseAst) {
      return [CatchClauseAst]::new($catchClauseAst.Extent,
                                   [TypeConstraintAst[]]$catchClauseAst.CatchTypes.ForEach({$_.Visit($this)}),
                                   $catchClauseAst.Body.Visit($this));
   }

   [object] VisitTryStatement([TryStatementAst]$tryStatementAst) {
      return [TryStatementAst]::new($tryStatementAst.Extent,
                                    $tryStatementAst.Body.Visit($this),
                                    [CatchClauseAst[]]$tryStatementAst.CatchClauses.ForEach({$_.Visit($this)}),
                                    $this.Visit($tryStatementAst.Finally));
   }
   [object] VisitBreakStatement([BreakStatementAst]$breakStatementAst) {
      return [BreakStatementAst]::new($breakStatementAst.Extent,
                                      $this.Visit($breakStatementAst.Label));
   }

   [object] VisitContinueStatement([ContinueStatementAst]$continueStatementAst) {
      return [ContinueStatementAst]::new($continueStatementAst.Extent,
                                         $this.Visit($continueStatementAst.Label));
   }

   [object] VisitReturnStatement([ReturnStatementAst]$returnStatementAst) {
      return [ReturnStatementAst]::new($returnStatementAst.Extent,
                                       $this.Visit($returnStatementAst.Pipeline));
   }

   [object] VisitExitStatement([ExitStatementAst]$exitStatementAst) {
      return [ExitStatementAst]::new($exitStatementAst.Extent,
                                     $this.Visit($exitStatementAst.Pipeline));
   }

   [object] VisitThrowStatement([ThrowStatementAst]$throwStatementAst) {
      return [ThrowStatementAst]::new($throwStatementAst.Extent, 
                                      $this.Visit($throwStatementAst.Pipeline));
   }
   [object] VisitDoUntilStatement([DoUntilStatementAst]$doUntilStatementAst) {
      return [DoUntilStatementAst]::new($doUntilStatementAst.Extent,
                                        $doUntilStatementAst.Label,
                                        $doUntilStatementAst.Condition.Visit($this),
                                        $doUntilStatementAst.Body.Visit($this));
   }

   [object] VisitAssignmentStatement([AssignmentStatementAst]$assignmentStatementAst) {
      return [AssignmentStatementAst]::new($assignmentStatementAst.Extent,
                                           $assignmentStatementAst.Left.Visit($this),
                                           $assignmentStatementAst.Operator,
                                           $assignmentStatementAst.Right.Visit($this),
                                           $assignmentStatementAst.ErrorPosition);
   }

   [object] VisitPipeline([PipelineAst]$pipelineAst) {
      return [PipelineAst]::new($pipelineAst.Extent, 
                                [CommandBaseAst[]]$pipelineAst.PipelineElements.ForEach({$_.Visit($this)})); 
   }

   [object] VisitCommand([CommandAst]$commandAst) {
      return [CommandAst]::new($commandAst.Extent,
                               [CommandElementAst[]]$commandAst.CommandElements.ForEach({$_.Visit($this)}),
                               $commandAst.InvocationOperator,
                               [RedirectionAst[]]$commandAst.Redirections.ForEach({$_.Visit($this)}));
   }

   [object] VisitCommandExpression([CommandExpressionAst]$commandExpressionAst) {
      return [CommandExpressionAst]::new($commandExpressionAst.Extent,
                                         $commandExpressionAst.Expression.Visit($this),
                                         [RedirectionAst[]]$commandExpressionAst.Redirections.ForEach({$_.Visit($this)}));
   }

   [object] VisitCommandParameter([CommandParameterAst]$commandParameterAst) {
      return [CommandParameterAst]::new($commandParameterAst.Extent,
                                        $commandParameterAst.ParameterName,
                                        $this.Visit($commandParameterAst.Argument),
                                        $commandParameterAst.ErrorPosition);
   }

   [object] VisitFileRedirection([FileRedirectionAst]$fileRedirectionAst) {
      return [FileRedirectionAst]::new($fileRedirectionAst.Extent, 
                                       $fileRedirectionAst.FromStream,
                                       $fileRedirectionAst.Location.Visit($this),
                                       $fileRedirectionAst.Append);
   }

   [object] VisitMergingRedirection([MergingRedirectionAst]$mergingRedirectionAst) {
      # nothing to descend into
      return $mergingRedirectionAst.Copy();
   }

   [object] VisitBinaryExpression([BinaryExpressionAst]$binaryExpressionAst) {
      return [BinaryExpressionAst]::new($binaryExpressionAst.Extent,
                                        $binaryExpressionAst.Left.Visit($this),
                                        $binaryExpressionAst.Operator,
                                        $binaryExpressionAst.Right.Visit($this),
                                        $binaryExpressionAst.ErrorPosition);
   }

   [object] VisitUnaryExpression([UnaryExpressionAst]$unaryExpressionAst) {
      return [UnaryExpressionAst]::new($unaryExpressionAst.Extent,
                                       $unaryExpressionAst.TokenKind,
                                       $unaryExpressionAst.Child.Visit($this));
   }

   [object] VisitConvertExpression([ConvertExpressionAst]$convertExpressionAst) {
      return [ConvertExpressionAst]::new($convertExpressionAst.Extent,
                                         $convertExpressionAst.Type.Visit($this),
                                         $convertExpressionAst.Child.Visit($this));
   }

   [object] VisitConstantExpression([ConstantExpressionAst]$constantExpressionAst) {
      # nothing to descend into here
      return $constantExpressionAst.Copy();
   }

   [object] VisitStringConstantExpression([StringConstantExpressionAst]$stringConstantExpressionAst) {
      # nothing to descend into here
      return $stringConstantExpressionAst.Copy();
   }

   [object] VisitSubExpression([SubExpressionAst]$subExpressionAst) {
      return [SubExpressionAst]::new($subExpressionAst.Extent,
                                     $subExpressionAst.SubExpression.Visit($this));
   }

   [object] VisitUsingExpression([UsingExpressionAst]$usingExpressionAst) {
      return [UsingExpressionAst]::new($usingExpressionAst.Extent,
                                       $usingExpressionAst.SubExpression.Visit($this));
   }

   [object] VisitVariableExpression([VariableExpressionAst]$variableExpressionAst) {
      # nothing to descend into here
      return $variableExpressionAst.Copy();
   }

   [object] VisitTypeExpression([TypeExpressionAst]$typeExpressionAst) {
      # nothing to descend into here
      return $typeExpressionAst.Copy(); 
   }

   [object] VisitMemberExpression([MemberExpressionAst]$memberExpressionAst) {
      return [MemberExpressionAst]::new($memberExpressionAst.Extent,
                                        $memberExpressionAst.Expression.Visit($this),
                                        $memberExpressionAst.Member.Visit($this),
                                        $memberExpressionAst.Static);
   }

   [object] VisitInvokeMemberExpression([InvokeMemberExpressionAst]$invokeMemberExpressionAst) {
      return [InvokeMemberExpressionAst]::new($invokeMemberExpressionAst.Extent,
                                              $invokeMemberExpressionAst.Expression.Visit($this),
                                              $invokeMemberExpressionAst.Member.Visit($this),
                                              [ExpressionAst[]]$invokeMemberExpressionAst.Arguments.ForEach({$_.Visit($this)}),
                                              $invokeMemberExpressionAst.Static);
   }

   [object] VisitArrayExpression([ArrayExpressionAst]$arrayExpressionAst) {
      return [ArrayExpressionAst]::new($arrayExpressionAst.Extent,
                                       $arrayExpressionAst.SubExpression.Visit($this));
   }

   [object] VisitArrayLiteral([ArrayLiteralAst]$arrayLiteralAst) {
      return [ArrayLiteralAst]::new($arrayLiteralAst.Extent,
                                    $arrayLiteralAst.Elements.ForEach({$_.Visit($this)}));
   }

   [object] VisitHashtable([HashtableAst]$hashtableAst) {
      return [HashtableAst]::new($hashtableAst.Extent,
                                 [Tuple[ExpressionAst,StatementAst][]]`
                                    $hashtableAst.KeyValuePairs.ForEach({[Tuple[ExpressionAst,StatementAst]]::new($_.Item1.Visit($this), $_.Item2.Visit($this))}));
   }

   [object] VisitScriptBlockExpression([ScriptBlockExpressionAst]$scriptBlockExpressionAst) {
      return [ScriptBlockExpressionAst]::new($scriptBlockExpressionAst.Extent, 
                                             $scriptBlockExpressionAst.ScriptBlock.Visit($this));
   }

   [object] VisitParenExpression([ParenExpressionAst]$parenExpressionAst) {
      return [ParenExpressionAst]::new($parenExpressionAst.Extent,
                                       $parenExpressionAst.Pipeline.Visit($this));
   }

   [object] VisitExpandableStringExpression([ExpandableStringExpressionAst]$expandableStringExpressionAst) {
      # nothing to descend into here
      return $expandableStringExpressionAst.Copy();
   }

   [object] VisitIndexExpression([IndexExpressionAst]$indexExpressionAst) {
      return [IndexExpressionAst]::new($indexExpressionAst.Extent,
                                       $indexExpressionAst.Target.Visit($this),
                                       $indexExpressionAst.Index.Visit($this));
   }

   [object] VisitAttributedExpression([AttributedExpressionAst]$attributedExpressionAst) {
      return [AttributedExpressionAst]::new($attributedExpressionAst.Extent,
                                            $attributedExpressionAst.Attribute.Visit($this),
                                            $attributedExpressionAst.Child.Visit($this));
   }

   [object] VisitBlockStatement([BlockStatementAst]$blockStatementAst) {
      return [BlockStatementAst]::new($blockStatementAst.Extent,
                                      $blockStatementAst.Kind,
                                      $blockStatementAst.Body.Visit($this));
   }
}
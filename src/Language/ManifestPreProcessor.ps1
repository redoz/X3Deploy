using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

enum ParserState {
   Waiting
   Manifest
   Require
   Include
   Parameters
   Install
   PropertyValue
   DeferredExpression
}

class ManifestPreProcessor : ICustomAstVisitor {
   hidden [Stack[ParserState]]$State;

   ManifestPreProcessor() {
      $this.State = [Stack[ParserState]]::new();
      $this.State.Push([ParserState]::Waiting);
   }

   hidden [object]Visit($ast) {
      if ($ast -ne $null) {
         return $ast.Visit($this);
      } else {
         return $null;
      }
   }

   hidden [bool]TryParseResourceProperty([StatementAst]$statementAst, [ref]$nameAst, [ref]$valueAst) { 
      # TODO it might be better to just reparse the textual representation..
      # $propertyValueAst = [Parser]::ParseInput(....)

      [PipelineAst]$pipelineAst = $statementAst -as [PipelineAst]
      if ($pipelineAst -eq $null) {
         # TODO should we report some kind of error here?
         return $false;
      }

      [CommandAst]$propertyCommandAst = $pipelineAst.PipelineElements[0] -as [CommandAst]
      if ($propertyCommandAst -eq $null){
         return false;
      }

      if ($propertyCommandAst.CommandElements.Count -lt 3) 
      {
         return false;
      }

      if ($propertyCommandAst.CommandElements[0] -isnot [StringConstantExpressionAst] -or `
          $propertyCommandAst.CommandElements[1] -isnot [StringConstantExpressionAst] -or `
          $propertyCommandAst.CommandElements[1].Value -ne '=') {
         return $false;
      }
      $nameAst.Value = $propertyCommandAst.CommandElements[0];
      # unmangle the broken parsing

      # this is definately a pipeline
      if ((($propertyCommandAst.CommandElements[2] -isnot [ConstantExpressionAst] -and $propertyCommandAst.CommandElements[2] -isnot [VariableExpressionAst]) -or `
           ($propertyCommandAst.CommandElements[2] -is [StringConstantExpressionAst] -and `
            $propertyCommandAst.CommandElements[2].StringConstantType -eq [StringConstantType]::BareWord)) -or `
            $pipelineAst.PipelineElements.Count -gt 1) {
         
         $pipelineElementAstList = [List[CommandBaseAst]]::new()
         
         if ($propertyCommandAst.CommandElements[2] -is [StringConstantExpressionAst] -and `
             $propertyCommandAst.CommandElements[2].StringConstantType -eq [StringConstantType]::BareWord) {

            $commandElementAstList = [CommandElementAst[]]@($propertyCommandAst.CommandElements | Select-Object -Skip 2 | ForEach-Object -Process {$_.Copy()});
            $pipelineElementAstList.Add([CommandAst]::new((Join-X3ScriptExtent -Extent ($commandElementAstList.Extent)),
                                                          $commandElementAstList,
                                                          [TokenKind]::Unknown,
                                                          $null));
         } elseif ($propertyCommandAst.CommandElements[2] -is [ExpressionAst] -and $propertyCommandAst.CommandElements.Count -eq 3) {
            # wrap it in a [CommandExpressionAst] so it can be part of a pipeline
            $pipelineElementAstList.Add([CommandExpressionAst]::new($propertyCommandAst.CommandElements[2].Extent,
                                                                    $propertyCommandAst.CommandElements[2].Copy(),
                                                                    $null));
          } else {
            throw "Not implemented yet!";
         }

         for ($i = 1; $i -lt $pipelineAst.PipelineElements.Count; $i++) {
            $pipelineElementAstList.Add($pipelineAst.PipelineElements[$i].Copy($this))
         }
                     
         $valueAst.Value = [PipelineAst]::new((Join-X3ScriptExtent -Extent ($pipelineElementAstList.Extent)), $pipelineElementAstList);
      } elseif ($propertyCommandAst.CommandElements[2] -is [ExpressionAst]) {
         # skip descending & just copy node
         $valueAst.Value = $propertyCommandAst.CommandElements[2].Copy();
      } else {
         throw "not implemented yet!"
      }

      $this.State.Push([ParserState]::PropertyValue);
      # analyze AST to see if it contains references to runtime objects, in which case we should inject a "Defer {...}" block
      if (($valueAst.Value -isnot [PipelineAst] -or 
           $valueAst.Value.PipelineElements[0] -isnot [CommandAst] -or 
           $valueAst.Value.PipelineElements[0].GetCommandName() -ne 'Defer') -and [UsingExpressionAstFinder]::Contains($valueAst.Value)) {
         
         $newValueAst = $valueAst.Value.Visit($this);

         [StatementBlockAst]$statementBlockAst = [StatementBlockAst]::new($valueAst.Value.Extent, 
                                                                          [StatementAst[]]@($newValueAst),
                                                                          $null);
                                           
         [NamedBlockAst]$namedBlockAst = [NamedBlockAst]::new($valueAst.Value.Extent, 
                                               [TokenKind]::End,
                                               $statementBlockAst,
                                               $true);
                                               
         [ScriptBlockAst]$scriptBlockAst = [ScriptBlockAst]::new($valueAst.Value.Extent,
                                                                 $null, # usingStatements
                                                                 $null, # attributes
                                                                 $null, # paramBlock
                                                                 $null, # beginBlock
                                                                 $null, # processBlock
                                                                 $namedBlockAst, # endBlock
                                                                 $null); #dynamicParamBlock

         [ScriptBlockExpressionAst]$scriptBlockExpressionAst = [ScriptBlockExpressionAst]::new([IScriptExtent]$valueAst.Value.Extent, $scriptBlockAst);

         $commandAst= [CommandAst]::new($valueAst.Value.Extent,
                                        [CommandElementAst[]]@(
                                           [StringConstantExpressionAst]::new([X3Extent]::Null, 'New-DeferredExpression', [StringConstantType]::BareWord)
                                           [CommandParameterAst]::new($valueAst.Value.Extent, 
                                                                      'Script',
                                                                      $scriptBlockExpressionAst,
                                                                      $valueAst.Value.Extent)
                                           [CommandParameterAst]::new([X3Extent]::Null,
                                                                      'ErrorPosition',
                                                                      [ConstantExpressionAst]::new([X3Extent]::Null, $valueAst.Value.Extent),
                                                                      [X3Extent]::Null)
                                        ),
                                        [TokenKind]::Unknown,
                                        $null);

         $valueAst.Value = [PipelineAst]::new($valueAst.Value.Extent, $commandAst);
      } else {
         # now that we hopefully re-constructed what the AST should look like, descend & process
         $valueAst.Value = $valueAst.Value.Visit($this);
      }
      $this.State.Pop();
      return $true;
   }

   
   hidden [bool]TryParseResource([CommandAst]$commandAst, [ref]$resourceAst, [ref]$nameAst, [ref]$argumentAsts) {
      if ($commandAst.CommandElements.Count -ne 3) {
         return $false;
      }

      if ($commandAst.CommandElements[0] -isnot [StringConstantExpressionAst]) {
         return $false;
      }

      $resourceAst.Value = $commandAst.CommandElements[0];

      $nameAst.Value = $commandAst.CommandElements[1];

      if ($commandAst.CommandElements[2] -isnot [ScriptBlockExpressionAst]) {
         return $false;
      }

      [ScriptBlockAst]$scriptBlockAst = $commandAst.CommandElements[2].ScriptBlock;
      if ($scriptBlockAst.BeginBlock -ne $null -or `
          $scriptBlockAst.ProcessBlock -ne $null -or `
          $scriptBlockAst.DynamicParamBlock -ne $null -or `
          $scriptBlockAst.ParamBlock -ne $null) {

         return $false;
      }
      [NamedBlockAst]$namedBlockAst = $scriptBlockAst.EndBlock;

      if ($namedBlockAst -eq $null) {
         return $false;
      }

      $arguments = [Dictionary[ExpressionAst, Ast]]::new();

      foreach ($statementAst in $namedBlockAst.Statements) {
         $propertyNameAst = $null;
         $propertyValueAst = $null;
         if ($this.TryParseResourceProperty($statementAst, [ref]$propertyNameAst, [ref]$propertyValueAst)) {
            $arguments.Add($propertyNameAst.Copy(), $propertyValueAst);
         } else {
            return $false;
         }
      }
      
      $argumentAsts.Value = $arguments;

      return $true;
   }

   [CommandAst] Rewrite([CommandAst]$manifestAst) {
      return $manifestAst.Visit($this);
   }

   [object] VisitErrorStatement([ErrorStatementAst]$errorStatementAst) {
      Write-Debug -Message 'errorStatementAst';
      # this type has no public constructor
      return $errorStatementAst.Copy(); 
   }

   [object] VisitErrorExpression([ErrorExpressionAst]$errorExpressionAst) {
      Write-Debug -Message 'errorExpressionAst';
      # this type has no public constructor
      return $errorExpressionAst.Copy();
   }

   [object] VisitScriptBlock([ScriptBlockAst]$scriptBlockAst) {
      Write-Debug -Message 'scriptBlockAst';
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
      Write-Debug -Message 'paramBlockAst';
      return [ParamBlockAst]::new($paramBlockAst.Extent,
                                  [AttributeAst[]]$paramBlockAst.Attributes.ForEach({$_.Visit($this)}),
                                  [ParameterAst[]]$paramBlockAst.Parameters.ForEach({$_.Visit($this)}));
   }

   [object] VisitNamedBlock([NamedBlockAst]$namedBlockAst) {
      Write-Debug -Message 'namedBlockAst'; 
      return [NamedBlockAst]::new($namedBlockAst.Extent,
                                  $namedBlockAst.BlockKind,
                                  [StatementBlockAst]::new($namedBlockAst.Extent,
                                                           [StatementAst[]]$namedBlockAst.Statements.ForEach({$_.Visit($this)}),
                                                           [TrapStatementAst[]]$namedBlockAst.Traps.ForEach({$_.Visit($this)})),
                                  $namedBlockAst.Unnamed);
   }

   [object] VisitTypeConstraint([TypeConstraintAst]$typeConstraintAst) {
      Write-Debug -Message 'typeConstraintAst';
      # nothing to descend into
      return $typeConstraintAst.Copy();
   }

   [object] VisitAttribute([AttributeAst]$attributeAst) {
      Write-Debug -Message 'attributeAst';
      return [AttributeAst]::new($attributeAst.Extent,
                                 $attributeAst.TypeName,
                                 [ExpressionAst[]]$attributeAst.PositionalArguments.ForEach({$_.Visit($this)}),
                                 [NamedAttributeArgumentAst[]]$attributeAst.PositionalArguments.ForEach({$_.Visit($this)}));
   }
   [object] VisitNamedAttributeArgument([NamedAttributeArgumentAst]$namedAttributeArgumentAst) {
      Write-Debug -Message 'namedAttributeArgumentAst';
      return [NamedAttributeArgumentAst]::new($namedAttributeArgumentAst.Extent,
                                              $namedAttributeArgumentAst.ArgumentName,
                                              $namedAttributeArgumentAst.Argument.Visit($this),
                                              $namedAttributeArgumentAst.ExpressionOmitted);
   }

   [object] VisitParameter([ParameterAst]$parameterAst) {
      Write-Debug -Message 'parameterAst';
      return [ParameterAst]::new($parameterAst.Extent,
                                 $parameterAst.Name.Visit($this),
                                 [AttributeBaseAst[]]$parameterAst.Attributes.ForEach({$_.Visit($this)}),
                                 $this.Visit($parameterAst.DefaultValue));
   }

   [object] VisitFunctionDefinition([FunctionDefinitionAst]$functionDefinitionAst) {
      Write-Debug -Message 'functionDefinitionAst';
      return [FunctionDefinitionAst]::new($functionDefinitionAst.Extent,
                                          $functionDefinitionAst.IsFilter,
                                          $functionDefinitionAst.IsWorkflow,
                                          $functionDefinitionAst.Name,
                                          [ParameterAst[]]$functionDefinitionAst.Parameters.ForEach({$_.Visit($this)}),
                                          $functionDefinitionAst.Body.Visit($this));
   }

   [object] VisitStatementBlock([StatementBlockAst]$statementBlockAst) {
      Write-Debug -Message 'statementBlockAst';
      return [StatementBlockAst]::new($statementBlockAst.Extent,
                                      [StatementAst[]]$statementBlockAst.Statements.ForEach({$_.Visit($this)}),
                                      [TrapStatementAst[]]$statementBlockAst.Traps.ForEach({$_.Visit($this)}));
   }
   [object] VisitIfStatement([IfStatementAst]$ifStmtAst) {
      Write-Debug -Message 'ifStmtAst';
      return [IfStatementAst]::new($ifStmtAst.Extent, 
                                   [Tuple[PipelineBaseAst, StatementBlockAst][]]`
                                      $ifStmtAst.Clauses.ForEach({[Tuple[PipelineBaseAst, StatementBlockAst]]::new($_.Item1.Visit($this),$_.Item2.Visit($this))}),
                                   $this.Visit($ifStmtAst.ElseClause));
   }

   [object] VisitTrap([TrapStatementAst]$trapStatementAst) {
      Write-Debug -Message 'trapStatementAst';
      return [TrapStatementAst]::new($trapStatementAst.Extent,
                                     $this.Visit($trapStatementAst.TrapType),
                                     $trapStatementAst.Body.Visit($this));
   }

   [object] VisitSwitchStatement([SwitchStatementAst]$switchStatementAst) {
      Write-Debug -Message 'switchStatementAst';
      return [SwitchStatementAst]::new($switchStatementAst.Extent,
                                       $switchStatementAst.Label,
                                       $this.Visit($switchStatementAst.Condition),
                                       $switchStatementAst.Flags,
                                       [Tuple[ExpressionAst,StatementBlockAst][]]`
                                          $switchStatementAst.Clauses.ForEach({[Tuple[ExpressionAst,StatementBlockAst]]::new($_.Item1.Visit($this), $_.Item2.Visit($this))}),
                                       $this.Visit($switchStatementAst.Default));
   }
   [object] VisitDataStatement([DataStatementAst]$dataStatementAst) {
      Write-Debug -Message 'dataStatementAst';
      return [DataStatementAst]::new($dataStatementAst.Extent,
                                     $dataStatementAst.Variable,
                                     [ExpressionAst[]]$dataStatementAst.CommandsAllowed.ForEach({$_.Visit($this)}),
                                     $dataStatementAst.Body.Visit($this));
   }

   [object] VisitForEachStatement([ForEachStatementAst]$forEachStatementAst) {
      Write-Debug -Message 'forEachStatementAst';
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
      Write-Debug -Message 'doWhileStatementAst';
      return [DoWhileStatementAst]::new($doWhileStatementAst.Extent,
                                        $doWhileStatementAst.Label,
                                        $doWhileStatementAst.Condition.Visit($this),
                                        $doWhileStatementAst.Body.Visit($this));
   }
   [object] VisitForStatement([ForStatementAst]$forStatementAst) {
      Write-Debug -Message 'forStatementAst';
      return [ForStatementAst]::new($forStatementAst.Extent,
                                    $forStatementAst.Label,
                                    $this.Visit($forStatementAst.Initializer),
                                    $this.Visit($forStatementAst.Condition),
                                    $this.Visit($forStatementAst.Iterator),
                                    $this.Body.Visit($this));
   }

   [object] VisitWhileStatement([WhileStatementAst]$whileStatementAst) {
      Write-Debug -Message 'whileStatementAst';
      return [WhileStatementAst]::new($whileStatementAst.Extent,
                                      $whileStatementAst.Label,
                                      $whileStatementAst.Condition.Visit($this),
                                      $whileStatementAst.Body.Visit($this));
   }

   [object] VisitCatchClause([CatchClauseAst]$catchClauseAst) {
      Write-Debug -Message 'catchClauseAst';
      return [CatchClauseAst]::new($catchClauseAst.Extent,
                                   [TypeConstraintAst[]]$catchClauseAst.CatchTypes.ForEach({$_.Visit($this)}),
                                   $catchClauseAst.Body.Visit($this));
   }

   [object] VisitTryStatement([TryStatementAst]$tryStatementAst) {
      Write-Debug -Message 'tryStatementAst';
      return [TryStatementAst]::new($tryStatementAst.Extent,
                                    $tryStatementAst.Body.Visit($this),
                                    [CatchClauseAst[]]$tryStatementAst.CatchClauses.ForEach({$_.Visit($this)}),
                                    $this.Visit($tryStatementAst.Finally));
   }
   [object] VisitBreakStatement([BreakStatementAst]$breakStatementAst) {
      Write-Debug -Message 'breakStatementAst';
      return [BreakStatementAst]::new($breakStatementAst.Extent,
                                      $this.Visit($breakStatementAst.Label));
   }

   [object] VisitContinueStatement([ContinueStatementAst]$continueStatementAst) {
      Write-Debug -Message 'continueStatementAst';
      return [ContinueStatementAst]::new($continueStatementAst.Extent,
                                         $this.Visit($continueStatementAst.Label));
   }

   [object] VisitReturnStatement([ReturnStatementAst]$returnStatementAst) {
      Write-Debug -Message 'returnStatementAst';
      return [ReturnStatementAst]::new($returnStatementAst.Extent,
                                       $this.Visit($returnStatementAst.Pipeline));
   }

   [object] VisitExitStatement([ExitStatementAst]$exitStatementAst) {
      Write-Debug -Message 'exitStatementAst';
      return [ExitStatementAst]::new($exitStatementAst.Extent,
                                     $this.Visit($exitStatementAst.Pipeline));
   }

   [object] VisitThrowStatement([ThrowStatementAst]$throwStatementAst) {
      Write-Debug -Message 'throwStatementAst';
      return [ThrowStatementAst]::new($throwStatementAst.Extent, 
                                      $this.Visit($throwStatementAst.Pipeline));
   }
   [object] VisitDoUntilStatement([DoUntilStatementAst]$doUntilStatementAst) {
      Write-Debug -Message 'doUntilStatementAst';
      return [DoUntilStatementAst]::new($doUntilStatementAst.Extent,
                                        $doUntilStatementAst.Label,
                                        $doUntilStatementAst.Condition.Visit($this),
                                        $doUntilStatementAst.Body.Visit($this));
   }

   [object] VisitAssignmentStatement([AssignmentStatementAst]$assignmentStatementAst) {
      Write-Debug -Message 'assignmentStatementAst';
      return [AssignmentStatementAst]::new($assignmentStatementAst.Extent,
                                           $assignmentStatementAst.Left.Visit($this),
                                           $assignmentStatementAst.Operator,
                                           $assignmentStatementAst.Right.Visit($this),
                                           $assignmentStatementAst.ErrorPosition);
   }

   [object] VisitPipeline([PipelineAst]$pipelineAst) {
      Write-Debug -Message ('PipelineAst: ' + $pipelineAst.Extent.Text);
      return [PipelineAst]::new($pipelineAst.Extent, 
                                [CommandBaseAst[]]$pipelineAst.PipelineElements.ForEach({$_.Visit($this)})); 
   }

   [object] VisitCommand([CommandAst]$commandAst) {
      Write-Debug -Message ('CommandAst: ' + $commandAst.Extent.Text);

      if ($this.State.Peek() -eq [ParserState]::Waiting) {
         if ($commandAst.GetCommandName() -eq 'Manifest') {
         
            # new state
            $this.State.Push([ParserState]::Manifest)

            $manifestNameAst = $commandAst.CommandElements[1];

            # find the scriptblock that is the manifest definition (this works because Get-Manifest only takes one script-block parameter)
            [NamedBlockAst]$innerManifestAst = $commandAst.Find({param($ast) return $ast -is [ScriptBlockExpressionAst]}, $false).ScriptBlock.EndBlock;

            # parse main structure
            $commandArgumentAstList = [List[CommandElementAst]]::new()

            foreach ($statement in $innerManifestAst.Statements) {
               [PipelineAst]$pipelineAst = $statement -as [PipelineAst]
               if ($pipelineAst -eq $null) {
                  throw [ParseException]::new(@([ParseError]::new($statement.Extent, $null, "Expected Require, Include, Parameters, or Install.")))
               }

               if ($pipelineAst.PipelineElements.Count -eq 1 -and `
                   $pipelineAst.PipelineElements[0] -is [CommandAst] -and `
                   $pipelineAst.PipelineElements[0].CommandElements.Count -eq 2 -and `
                   $pipelineAst.PipelineElements[0].CommandElements[0] -is [StringConstantExpressionAst] -and `
                   $pipelineAst.PipelineElements[0].CommandElements[1] -is [ScriptBlockExpressionAst]) {

                  [CommandAst]$innerCommandAst = $pipelineAst.PipelineElements[0];
                  $section = $innerCommandAst.GetCommandName();
                  
                  [NamedBlockAst]$sectionDefinition = $innerCommandAst.CommandElements[1].ScriptBlock.EndBlock;
                  $newState = switch ($section) {
                     "Require" { [ParserState]::Require }
                     "Include" { [ParserState]::Include }
                     "Parameters" { [ParserState]::Parameters }
                     "Install" { [ParserState]::Install }
                     default {
                        throw [ParseException]::new(@([ParseError]::new($innerCommandAst.CommandElements[0].Extent, $null, "Expected Require, Include, Parameters, or Install.")));
                     }
                  }

                  $this.State.Push($newState);

                  $statementAstList = [List[StatementAst]]::new();
                  foreach ($sectionStatement in $sectionDefinition.Statements) {
                     $statementAstList.Add($sectionStatement.Visit($this));
                  }
                  
                  [StatementBlockAst]$statementBlockAst = [statementBlockAst]::new($pipelineAst.Extent, [StatementAst[]]$statementAstList, $null);
                  [NamedBlockAst]$argumentNamedBlock = [NamedBlockAst]::new($pipelineAst.Extent, [TokenKind]::End, $statementBlockAst , $true);
                  [ScriptBlockAst]$argumentScriptBlockAst = [ScriptBlockAst]::new($pipelineAst.Extent,
                                                                                  $null,
                                                                                  $null,
                                                                                  $null,
                                                                                  $null,
                                                                                  $null,
                                                                                  $argumentNamedBlock,
                                                                                  $null);
                  [ScriptBlockExpressionAst]$argumentScriptBlockExpressionAst = [ScriptBlockExpressionAst]::new($pipelineAst.Extent, $argumentScriptBlockAst);
                  [CommandAst]$argumentCommandAst = [CommandAst]::new($pipelineAst.Extent, [CommandElementAst[]]@($argumentScriptBlockExpressionAst) , [TokenKind]::Ampersand, $null);
                  [PipelineAst]$argumentPipelineAst = [PipelineAst]::new($pipelineAst.Extent, [CommandBaseAst[]]@($argumentCommandAst));
                  [StatementBlockAst]$argumentStatementBlockAst = [StatementBlockAst]::new($pipelineAst.Extent, [StatementAst[]]@($argumentPipelineAst), $null);
                  [ArrayExpressionAst]$argumentArrayExpressionAst = [ArrayExpressionAst]::new($pipelineAst.Extent, $argumentStatementBlockAst);

                  $commandArgumentAstList.Add([CommandParameterAst]::new($innerCommandAst.Extent, $section, $argumentArrayExpressionAst, $innerCommandAst.Extent));

                  $this.State.Pop();
               } else {
                  # TODO figure out better error reporting
                  throw [ParseException]::new(@([ParseError]::new($pipelineAst.Extent, $null, "Expected Require, Include, Parameters, or Install.")))
               }
            }

            $this.State.Pop();

            $commandNameAst = [StringConstantExpressionAst]::new([X3Extent]::FromLiteral("New-Manifest"), 'New-Manifest', [StringConstantType]::BareWord);
            $commandArgumentAstList.Insert(0, $commandNameAst);
            $commandArgumentAstList.Insert(1, [CommandParameterAst]::new($manifestNameAst.Extent, 'Name', $null, $manifestNameAst.Extent));

            if ($manifestNameAst -is [PipelineBaseAst]){
               $commandArgumentAstList.Insert(2, [ParenExpressionAst]::new($manifestNameAst.Extent, $manifestNameAst.Copy()));
            } else {
               $commandArgumentAstList.Insert(2, [CommandElementAst]$manifestNameAst.Copy());
            }
            
            return [CommandAst]::new($commandAst.Extent,
                                     $commandArgumentAstList,
                                     $commandAst.InvocationOperator,
                                     $null);
         }
         else {
            throw [ParseException]::new(@([ParseError]::new($commandAst.Extent, $null, "Expected Manifest")));
         }
      } elseif ($this.State.Peek() -eq [ParserState]::PropertyValue -and $commandAst.GetCommandName() -eq 'Defer') {
         if ($commandAst.CommandElements.Count -ne 2) {
            throw [ParseException]::new(@([ParseError]::new($commandAst.Extent, $null, "Invalid syntax, expected: Defer {...}")));
         }
         $this.State.Push([ParserState]::DeferredExpression)
         $commandElementAst = $commandAst.CommandElements[1].Visit($this);
         $this.State.Pop();
         return [CommandAst]::new($commandAst.Extent,
                                  [CommandElementAst[]]@(
                                     [StringConstantExpressionAst]::new($commandAst.CommandElements[0].Extent, 'New-DeferredExpression', [StringConstantType]::BareWord)
                                     $commandElementAst
                                  ),
                                  $commandAst.InvocationOperator,
                                  $null);
      } else {
         $resourceAst = $null
         $nameAst = $null
         $arguments = $null
         # <resource> "name" { X = Y }
         if ($this.TryParseResource($commandAst, [ref]$resourceAst, [ref]$nameAst, [ref]$arguments)) {
            $newCommandName = $null;
            $newCommandArguments = [List[CommandElementAst]]::new();
            if ($this.State.Peek() -eq [ParserState]::Parameters) {
               $newCommandName = 'New-Parameter'
               # $ErrorPosition, $Name, $Title, $Description, $Type, $Mandatory.IsPresent, $Default, $Hidden.IsPresent
               $newCommandArguments.Add([CommandParameterAst]::new($nameAst.Extent,
                                                                   'Name',
                                                                   $nameAst.Copy(),
                                                                   $nameAst.Extent));
                                                                   
               $commandParameters = Get-DefinedParameter -Command (Get-Command -Verb New -Noun Parameter)
               foreach ($kvp in $arguments.GetEnumerator()) {
                  $commandParameter = $commandParameters[$kvp.Key.SafeGetValue()]
                  if ($commandParameter -ne $null -and $commandParameter.SwitchParameter) {
                     $newCommandArguments.Add([CommandParameterAst]::new($kvp.Key.Extent,
                                                                        $kvp.Key.SafeGetValue(),
                                                                        $kvp.Value,
                                                                        $kvp.Key.Extent));
                  } elseif ($commandParameter -ne $null) {
                     $newCommandArguments.Add([CommandParameterAst]::new($kvp.Key.Extent,
                                                                        $kvp.Key.SafeGetValue(),
                                                                        $null,
                                                                        $kvp.Key.Extent));
                     if ($kvp.Value -is [PipelineBaseAst]){
                        $newCommandArguments.Add([ParenExpressionAst]::new($kvp.Value.Extent, $kvp.Value));
                     } else {
                        $newCommandArguments.Add([CommandElementAst]$kvp.Value);
                     }
                  } else {
                     Invoke-Error -Message ("Invalid term '$($kvp.Key.SafeGetValue())' specified in Parameter block, should be one of: " + ($commandParameters.Keys -join ', ')) -Extent $kvp.Key.Extent
                  }
               }

               $newCommandArguments.Add([CommandParameterAst]::new($resourceAst.Extent,
                                                                   'ErrorPosition',
                                                                   [ConstantExpressionAst]::new([X3Extent]::Null, $commandAst.Extent),
                                                                   [X3Extent]::Null));
            } else {
               $arrayLiteralElementAsts = [List[ExpressionAst]]::new();
               
               # convert all argument bindings into X3Argument (via New-Argument)
               foreach ($kvp in $arguments.GetEnumerator()) {
                  # value needs to be an ExpressionAst
                  [ExpressionAst]$valueExpressionAst = $null;
                  if ($kvp.Value -isnot [ExpressionAst]) {
                     # so if it isn't, we need to convert it to one using a SubExpressionAst node
                     # but in order to do that we need a StatementBlockAst node
                     [StatementBlockAst]$statementBlockAst = $null
                     if ($kvp.Value -is [StatementBlockAst]) {
                        # we're in luck, we can just use what we have
                        $statementBlockAst = $kvp.Value;
                     } else {
                        # $kvp.value wasn't a StatementBlockAst node so we need to create one
                        $statementBlockAst = [StatementBlockAst]::new($kvp.Value.Extent, [StatementAst[]]@($kvp.Value), $null);
                     }
                     # now we can create the SubExpressionAst node
                     $valueExpressionAst = [SubExpressionAst]::new($kvp.Value.Extent, $statementBlockAst);
                  } else {
                     $valueExpressionAst = $kvp.Value;
                  }
                  # join the key and value extents
                  [IScriptExtent]$kvpExtent = Join-X3ScriptExtent -Extent @($kvp.Key.Extent, $kvp.Value.Extent)
                  # create the "New-Argument -Name <name> -NameErrorPosition <namePos> -Value <value> -ValueErrorPosition <value>" call site
                  [CommandAst]$newArgumentCommandAst = [CommandAst]::new(
                        $kvpExtent, 
                        [CommandElementAst[]]@(
                           [StringConstantExpressionAst]::new([X3Extent]::FromLiteral("New-Argument"), 'New-Argument', [StringConstantType]::BareWord)
                           [CommandParameterAst]::new($kvp.Key.Extent,
                                                      'Name',
                                                      $kvp.Key,
                                                      $kvp.Key.Extent)
                           [CommandParameterAst]::new([X3Extent]::Null,
                                                      'NameErrorPosition',
                                                      [ConstantExpressionAst]::new([X3Extent]::Null, $kvp.Key.Extent),
                                                      [X3Extent]::Null)
                           [CommandParameterAst]::new($kvp.Value.Extent,
                                                      'Value',
                                                      $valueExpressionAst,
                                                      $kvp.Value.Extent)
                           [CommandParameterAst]::new([X3Extent]::Null,
                                                      'ValueErrorPosition',
                                                      [ConstantExpressionAst]::new([X3Extent]::Null, $kvp.Value.Extent),
                                                      [X3Extent]::Null)
                        ), 
                        [TokenKind]::Unknown, $null);
                  # wrap the CommandAst in a PipelineAst
                  [PipelineAst]$newArgumentPipelineAst = [PipelineAst]::new($kvpExtent, [CommandBaseAst[]]@($newArgumentCommandAst));
                  # wrap the PipelineAst in a ParenExpressionAst
                  [ParenExpressionAst]$newArgumentParenExprAst = [ParenExpressionAst]::new($kvpExtent, $newArgumentPipelineAst);
                  # now we have something we can use for our ArrayLiteralAst node
                  $arrayLiteralElementAsts.Add($newArgumentParenExprAst);
               }
               # create the ArrayLiteralAst node containing a list of elements consisting of ParenExpressionAsts
               [ArrayLiteralAst]$argumentsArrayLiteralAst = [ArrayLiteralAst]::new([X3Extent]::Null, $arrayLiteralElementAsts);
               # but we can't put this in a PipelineAst so wrap it in a CommandExpressionAst first
               [CommandExpressionAst]$argumentsCommandExprAst = [CommandExpressionAst]::new([X3Extent]::Null, $argumentsArrayLiteralAst, $null);
               # now we can create a PipelineAst node
               $arrayItemsPipelineAst = [PipelineAst]::new([X3Extent]::Null, $argumentsCommandExprAst);
               # which gets wrapped in a StatementBlockAst so we can use it for the ArrayExpressionAst
               $arrayStatementBlockAst = [StatementBlockAst]::new([X3Extent]::Null, [StatementAst[]]@($arrayItemsPipelineAst) , $null);
               # finally we can create the ArrayExpressionAst node which we can use as a parameter value for the call to New-*
               $argumentsAst = [ArrayExpressionAst]::new([X3Extent]::Null, $arrayStatementBlockAst);
               $newCommandName = 'New-' + $this.State.Peek().ToString();
               $newCommandArguments.AddRange(
                  [CommandElementAst[]]@(
                     [CommandParameterAst]::new([X3Extent]::Null,
                                                'ErrorPosition',
                                                [ConstantExpressionAst]::new([X3Extent]::Null, $commandAst.Extent), 
                                                [X3Extent]::Null)
                     [CommandParameterAst]::new($resourceAst.Extent,
                                                'Type',
                                                [StringConstantExpressionAst]::new($resourceAst.Extent, $resourceAst.Value, [StringConstantType]::SingleQuoted),
                                                $resourceAst.Extent)
                     [CommandParameterAst]::new($nameAst.Extent,
                                                'Name',
                                                $nameAst.Copy(),
                                                $nameAst.Extent)
                     [CommandParameterAst]::new($commandAst.Extent,
                                                'Arguments',
                                                $argumentsAst,
                                                $commandAst.Extent)
                  ));
            }
            
            $newCommandArguments.Insert(0, [StringConstantExpressionAst]::new($commandAst.Extent, $newCommandName, [StringConstantType]::BareWord));
            return [CommandAst]::new($commandAst.Extent, $newCommandArguments, [TokenKind]::Unknown, $null)
            
         } else {
            # descend
            return [CommandAst]::new($commandAst.Extent,
                                     [CommandElementAst[]]$commandAst.CommandElements.ForEach({$_.Visit($this)}),
                                     $commandAst.InvocationOperator,
                                     [RedirectionAst[]]$commandAst.Redirections.ForEach({$_.Visit($this)}));
         }
      }
   }

   [object] VisitCommandExpression([CommandExpressionAst]$commandExpressionAst) {
      Write-Debug -Message ('CommandExpressionAst: ' + $commandExpressionAst.Extent.Text);
      return [CommandExpressionAst]::new($commandExpressionAst.Extent,
                                         $commandExpressionAst.Expression.Visit($this),
                                         [RedirectionAst[]]$commandExpressionAst.Redirections.ForEach({$_.Visit($this)}));
   }

   [object] VisitCommandParameter([CommandParameterAst]$commandParameterAst) {
      Write-Debug -Message 'commandParameterAst';
      return [CommandParameterAst]::new($commandParameterAst.Extent,
                                        $commandParameterAst.ParameterName,
                                        $this.Visit($commandParameterAst.Argument),
                                        $commandParameterAst.ErrorPosition);
   }

   [object] VisitFileRedirection([FileRedirectionAst]$fileRedirectionAst) {
      Write-Debug -Message 'fileRedirectionAst';
      return [FileRedirectionAst]::new($fileRedirectionAst.Extent, 
                                       $fileRedirectionAst.FromStream,
                                       $fileRedirectionAst.Location.Visit($this),
                                       $fileRedirectionAst.Append);
   }

   [object] VisitMergingRedirection([MergingRedirectionAst]$mergingRedirectionAst) {
      Write-Debug -Message 'mergingRedirectionAst';
      return $mergingRedirectionAst; 
   }

   [object] VisitBinaryExpression([BinaryExpressionAst]$binaryExpressionAst) {
      Write-Debug -Message 'binaryExpressionAst';
      return [BinaryExpressionAst]::new($binaryExpressionAst.Extent,
                                        $binaryExpressionAst.Left.Visit($this),
                                        $binaryExpressionAst.Operator,
                                        $binaryExpressionAst.Right.Visit($this),
                                        $binaryExpressionAst.ErrorPosition);
   }

   [object] VisitUnaryExpression([UnaryExpressionAst]$unaryExpressionAst) {
      Write-Debug -Message 'unaryExpressionAst';
      return [UnaryExpressionAst]::new($unaryExpressionAst.Extent,
                                       $unaryExpressionAst.TokenKind,
                                       $unaryExpressionAst.Child.Visit($this));
   }

   [object] VisitConvertExpression([ConvertExpressionAst]$convertExpressionAst) {
      Write-Debug -Message 'convertExpressionAst';
      return [ConvertExpressionAst]::new($convertExpressionAst.Extent,
                                         $convertExpressionAst.Type.Visit($this),
                                         $convertExpressionAst.Child.Visit($this));
   }

   [object] VisitConstantExpression([ConstantExpressionAst]$constantExpressionAst) {
      Write-Debug -Message 'constantExpressionAst';
      # nothing to descend into here
      return $constantExpressionAst.Copy();
   }

   [object] VisitStringConstantExpression([StringConstantExpressionAst]$stringConstantExpressionAst) {
      Write-Debug -Message ('StringConstantExpressionAst: ' + $stringConstantExpressionAst.Extent.Text);
      # nothing to descend into here
      return $stringConstantExpressionAst.Copy();
   }

   [object] VisitSubExpression([SubExpressionAst]$subExpressionAst) {
      Write-Debug -Message 'subExpressionAst';
      return [SubExpressionAst]::new($subExpressionAst.Extent,
                                     $subExpressionAst.SubExpression.Visit($this));
   }

   [object] VisitUsingExpression([UsingExpressionAst]$usingExpressionAst) {
      Write-Debug -Message 'usingExpressionAst';
      return [UsingExpressionAst]::new($usingExpressionAst.Extent,
                                       $usingExpressionAst.SubExpression.Visit($this));
   }

   [object] VisitVariableExpression([VariableExpressionAst]$variableExpressionAst) {
      Write-Debug -Message ('VariableExpressionAst: ' + $variableExpressionAst.Extent.Text);
      # nothing to descend into here
      return $variableExpressionAst.Copy();
   }

   [object] VisitTypeExpression([TypeExpressionAst]$typeExpressionAst) {
      Write-Debug -Message 'typeExpressionAst';
      # nothing to descend into here
      return $typeExpressionAst.Copy(); 
   }

   [object] VisitMemberExpression([MemberExpressionAst]$memberExpressionAst) {
      Write-Debug -Message ('MemberExpressionAst: ' + $memberExpressionAst.Extent.Text);
      return [MemberExpressionAst]::new($memberExpressionAst.Extent,
                                        $memberExpressionAst.Expression.Visit($this),
                                        $memberExpressionAst.Member.Visit($this),
                                        $memberExpressionAst.Static);
   }

   [object] VisitInvokeMemberExpression([InvokeMemberExpressionAst]$invokeMemberExpressionAst) {
      Write-Debug -Message 'invokeMemberExpressionAst';
      return [InvokeMemberExpressionAst]::new($invokeMemberExpressionAst.Extent,
                                              $invokeMemberExpressionAst.Expression.Visit($this),
                                              $invokeMemberExpressionAst.Member.Visit($this),
                                              [ExpressionAst[]]$invokeMemberExpressionAst.Arguments.ForEach({$_.Visit($this)}),
                                              $invokeMemberExpressionAst.Static);
   }

   [object] VisitArrayExpression([ArrayExpressionAst]$arrayExpressionAst) {
      Write-Debug -Message 'arrayExpressionAst';
      return [ArrayExpressionAst]::new($arrayExpressionAst.Extent,
                                       $arrayExpressionAst.SubExpression.Visit($this));
   }

   [object] VisitArrayLiteral([ArrayLiteralAst]$arrayLiteralAst) {
      Write-Debug -Message 'arrayLiteralAst';
      return [ArrayLiteralAst]::new($arrayLiteralAst.Extent,
                                    $arrayLiteralAst.Elements.ForEach({$_.Visit($this)}));
   }

   [object] VisitHashtable([HashtableAst]$hashtableAst) {
      Write-Debug -Message 'hashtableAst';
      return [HashtableAst]::new($hashtableAst.Extent,
                                 [Tuple[ExpressionAst,StatementAst][]]`
                                    $hashtableAst.KeyValuePairs.ForEach({[Tuple[ExpressionAst,StatementAst]]::new($_.Item1.Visit($this), $_.Item2.Visit($this))}));
   }

   [object] VisitScriptBlockExpression([ScriptBlockExpressionAst]$scriptBlockExpressionAst) {
      Write-Debug -Message 'scriptBlockExpressionAst';
      return [ScriptBlockExpressionAst]::new($scriptBlockExpressionAst.Extent, 
                                             $scriptBlockExpressionAst.ScriptBlock.Visit($this));
   }

   [object] VisitParenExpression([ParenExpressionAst]$parenExpressionAst) {
      Write-Debug -Message 'parenExpressionAst';
      return [ParenExpressionAst]::new($parenExpressionAst.Extent,
                                       $parenExpressionAst.Pipeline.Visit($this));
   }

   [object] VisitExpandableStringExpression([ExpandableStringExpressionAst]$expandableStringExpressionAst) {
      Write-Debug -Message 'expandableStringExpressionAst';
      # nothing to descend into here
      return $expandableStringExpressionAst.Copy();
   }

   [object] VisitIndexExpression([IndexExpressionAst]$indexExpressionAst) {
      Write-Debug -Message 'indexExpressionAst';
      return [IndexExpressionAst]::new($indexExpressionAst.Extent,
                                       $indexExpressionAst.Target.Visit($this),
                                       $indexExpressionAst.Index.Visit($this));
   }

   [object] VisitAttributedExpression([AttributedExpressionAst]$attributedExpressionAst) {
      Write-Debug -Message 'attributedExpressionAst';
      return [AttributedExpressionAst]::new($attributedExpressionAst.Extent,
                                            $attributedExpressionAst.Attribute.Visit($this),
                                            $attributedExpressionAst.Child.Visit($this));
   }

   [object] VisitBlockStatement([BlockStatementAst]$blockStatementAst) {
      Write-Debug -Message 'blockStatementAst';
      return [BlockStatementAst]::new($blockStatementAst.Extent,
                                      $blockStatementAst.Kind,
                                      $blockStatementAst.Body.Visit($this));
   }
}
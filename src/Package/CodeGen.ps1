using namespace System.Collections.Generic
using namespace System.Text
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

Set-StrictMode -Version Latest

enum CodeGenOptions {
   None = 0
   SkipContainer = 1
}

class CodeGen : ICustomAstVisitor2 {
   static [string]Write([Ast]$ast, [CodeGenOptions]$options = [CodeGenOptions]::None) {
      return [CodeGen]::new().Generate($ast, $options);
   }

   hidden [StringBuilder]$output;
   hidden [CodeGenOptions]$options;

   CodeGen() {
      $this.output = [StringBuilder]::new();
      $this.options = [CodeGenOptions]::None;
   }

   [string]Generate([Ast]$ast, [CodeGenOptions]$options = [CodeGenOptions]::None) {
      $this.options = $options;
      $this.output.Clear();
      $ast.Visit($this);
      return $this.output.ToString();
   }

   hidden [object]Visit($ast) {
      if ($ast -ne $null) {
         return $ast.Visit($this);
      } else {
         return $this;
      }
   }

   hidden [CodeGen]JoinVisit([TokenKind]$seperator, [Ast[]]$nodes) {
      [bool]$needsSeperator = $false;
      foreach($node in $nodes) {
         if ($needsSeperator) {
            $this.AppendToken($seperator);
         } else {
            $needsSeperator = $true;
         }
         $node.Visit($this);
      }
      return $this;
   }

   hidden [CodeGen]JoinVisit([TokenKind]$seperator, [Ast[]]$nodes1, [Ast[]]$nodes2) {
      [Ast[]]$nodes = @();
      if ($null -ne $nodes1 -and $nodes1.Count -gt 0) {
         $nodes += $nodes1;
      }
      if ($null -ne $nodes2 -and $nodes2.Count -gt 0) {
         $nodes += $nodes2;
      }
      return $this.JoinVisit($seperator, $nodes);
   }

   hidden [CodeGen]AppendTypeName([ITypeName]$typeName) {
      if ($typeName -is [GenericTypeName]) {
         [GenericTypeName]$generic = $typeName;
         $this.AppendTypeName($generic.TypeName);
         $this.AppendToken([TokenKind]::LBracket);
         
         for($i = 0; $i -lt $generic.GenericArguments.Count; $i++) {
            if ($i -gt 0) {
               $this.AppendToken([TokenKind]::Comma);
            }
            $this.AppendToken([TokenKind]::LBracket);
            $this.AppendTypeName($generic.GenericArguments[$i]);
            $this.AppendToken([TokenKind]::RBracket);
         }

         $this.AppendToken([TokenKind]::RBracket);
      } elseif ($typeName -is [ArrayTypeName]) {
         [ArrayTypeName]$array = $typeName;
         $this.AppendTypeName($array.ElementType);
         $this.AppendToken([TokenKind]::LBracket, [TokenKind]::RBracket);
      } else {
         $this.Append($typeName.Name);
      }

      return $this;
   }

   hidden [CodeGen]AppendToken([TokenKind]$t1) {
      return $this.AppendTokens(@($t1));
   }

   hidden [CodeGen]AppendToken([TokenKind]$t1, [TokenKind]$t2) {
      return $this.AppendTokens(@($t1, $t2));
   }

   hidden [CodeGen]AppendToken([TokenKind]$t1, [TokenKind]$t2, [TokenKind]$t3) {
      return $this.AppendTokens(@($t1, $t2, $t3));
   }

   hidden [CodeGen]AppendTokens([TokenKind[]]$token) {
      $token.ForEach({$this.output.Append($this.Token($_))})
      return $this;
   }

   hidden [CodeGen]AppendSpace() {
      $this.output.Append(' ');
      return $this;
   }

   hidden [CodeGen]Append([string]$value) {
      $this.output.Append($value);
      return $this;
   }

   hidden [string]Token([TokenKind]$token) {
      $ret = switch ($token) {
           # Unknown = 0,
           # Variable = 1,
           # SplattedVariable = 2,
           # Parameter = 3,
           # Number = 4,
           # Label = 5,
           # Identifier = 6,
           # Generic = 7,
           NewLine { [Environment]::NewLine }
           LineContinuation { '`' }
           # Comment = 10,
           # EndOfInput = 11,
           # StringLiteral = 12,
           # StringExpandable = 13,
           # HereStringLiteral = 14,
           # HereStringExpandable = 15,
           LParen { '(' }
           RParen { ')' }
           LCurly { '{' }
           RCurly { '}' }
           LBracket { '[' }
           RBracket { ']' }
           AtParen { '@(' }
           AtCurly { '@{' }
           DollarParen { '$(' }
           Semi { ';' }
           AndAnd { '&&' }
           OrOr {'||'}
           Ampersand { '&' }
           Pipe { '|' }
           Comma { ',' }
           MinusMinus { '--' }
           PlusPlus { '++' }
           DotDot { '..' }
           ColonColon  { '::' }
           Dot  { '.' }
           Exclaim { '!' }
           Multiply  { '*' }
           Divide  { '/' }
           Rem  { '%' }
           Plus  { '+' }
           Minus  { '-' }
           Equals  { '=' }
           PlusEquals  { '+=' }
           MinusEquals  { '-=' }
           MultiplyEquals  { '*=' }
           DivideEquals  { '/=' }
           RemainderEquals  { '%=' }
           # Redirection = 48,
           # RedirectInStd = 49,
           Format { '-f' }
           Not  { '-not' }
           Bnot { '-bnot' }
           And { '-and' }
           Or { '-or' }
           Xor { '-xor' }
           Band { '-band' }
           Bor { '-bor' }
           Bxor { '-bxor' }
           Join { '-join' }
           Ieq { '-ieq' }
           Ine { '-ine' }
           Ige { '-ige' }
           Igt { '-igt' }
           Ilt { '-ilt' }
           Ile { '-ile' }
           Ilike { '-ilike' }
           Inotlike { '-inotlike' }
           Imatch { '-imatch' }
           Inotmatch { '-notmatch' }
           Ireplace { '-ireplace' }
           Icontains { '-icontains' }
           Inotcontains { '-inotcontains' }
           Iin { '-iin' }
           Inotin { '-inotin' }
           Isplit { '-isplit' }
           Ceq { '-ceq' }
           Cne { '-cne' }
           Cge { '-cge' }
           Cgt { '-cgt' }
           Clt { '-clt' }
           Cle { '-clr' }
           Clike { '-clike' }
           Cnotlike { '-cnotlike' }
           Cmatch { '-cmatch' }
           Cnotmatch { '-cnotmatch' }
           Creplace { '-creplace' }
           Ccontains { '-contains' }
           Cnotcontains { '-cnotcontains' }
           Cin { '-cin' }
           Cnotin { '-cnotin' }
           Csplit { '-csplit' }
           Is { '-is' }
           IsNot{ '-isnot' }
           As { '-as' }
           PostfixPlusPlus { '++' }
           PostfixMinusMinus { '--' }
           Shl { '-shl' }
           Shr { '-shr' }
           Colon { ':' }
           Begin { 'begin' }
           Break { 'break' }
           Catch { 'catch' }
           Class { 'class' }
           Continue { 'continue' }
           Data { 'DATA' }
           # Define = 125,
           Do { 'do' }
           Dynamicparam { 'dynamicparam' }
           Else { 'else' }
           ElseIf { 'elseif' }
           End { 'end' }
           Exit { 'exit' }
           # Filter = 132,
           Finally { 'finally' }
           For { 'for' }
           Foreach { 'foreach' }
           # From = 136,
           Function { 'function' }
           If { 'if' }
           In { 'in' }
           Param { 'param' }
           Process { 'process' }
           Return { 'return' }
           Switch { 'switch' }
           Throw { 'throw' }
           Trap { 'trap' }
           Try { 'try' }
           Until { 'until' }
           Using { 'using' }
           # Var = 149,
           While { 'while' }
           # Workflow = 151,
           # Parallel = 152,
           # Sequence = 153,
           # InlineScript = 154,
           Configuration { 'Configuration' }
           # DynamicKeyword = 156,
           # Public = 157,
           # Private = 158,
           Static { 'static' }
           # Interface = 160,
           Enum { 'enum' }
           Namespace { 'namespace' }
           # Module = 163,
           # Type = 164,
           # Assembly = 165,
           # Command = 166,
           Hidden { 'hidden' }
           Base { 'base' } 
           default {throw ('Not Supported: ' + $token)}
         }
      return $ret;
   }

   [object] VisitErrorStatement([ErrorStatementAst]$errorStatementAst) {
      Write-Debug -Message "CodeGen::VisitErrorStatement"
      Write-Warning -Message "Not Implemented"
      return $this;
   }

   [object] VisitErrorExpression([ErrorExpressionAst]$errorExpressionAst) {
      Write-Debug -Message "CodeGen::VisitErrorExpression"
      Write-Warning -Message "Not Implemented"
      return $this;
   }

   [object] VisitScriptBlock([ScriptBlockAst]$scriptBlockAst) {
      Write-Debug -Message "CodeGen::VisitScriptBlock"

      if ($scriptBlockAst.Parent -ne $null -or ($this.options -band [CodeGenOptions]::SkipContainer) -eq 0) {
         $this.AppendToken([TokenKind]::LCurly)
      }
      $scriptBlockAst.UsingStatements.ForEach({$_.Visit($this)});

      $this.Visit($scriptBlockAst.ParamBlock);
      if ($scriptBlockAst.DynamicParamBlock -ne $null) {
         $this.AppendToken([TokenKind]::Dynamicparam, [TokenKind]::LCurly);
         $scriptBlockAst.DynamicParamBlock.Visit($this);
         $this.AppendToken([TokenKind]::RCurly);
      }      

      if ($scriptBlockAst.BeginBlock -ne $null) {
         $this.AppendToken([TokenKind]::Begin);
         $this.AppendToken([TokenKind]::LCurly);
         $scriptBlockAst.BeginBlock.Visit($this);
         $this.AppendToken([TokenKind]::RCurly);
      }      

      if ($scriptBlockAst.ProcessBlock -ne $null) {
         $this.AppendToken([TokenKind]::Process,[TokenKind]::LCurly);
         
         $scriptBlockAst.ProcessBlock.Visit($this);
         $this.AppendToken([TokenKind]::RCurly);
      }
      if ($scriptBlockAst.EndBlock -ne $null) {
         if ($scriptBlockAst.BeginBlock -ne $null -or $scriptBlockAst.ProcessBlock -ne $null) {
            $this.AppendToken([TokenKind]::End)
            $this.AppendToken([TokenKind]::LCurly);
         }
         $scriptBlockAst.EndBlock.Visit($this);
         if ($scriptBlockAst.BeginBlock -ne $null -or $scriptBlockAst.ProcessBlock -ne $null) {
            $this.AppendToken([TokenKind]::RCurly);
         }
      }

      if ($scriptBlockAst.Parent -ne $null -or ($this.options -band [CodeGenOptions]::SkipContainer) -eq 0) {
         $this.AppendToken([TokenKind]::RCurly)
      }
      return $this;
   }
   [object] VisitParamBlock([ParamBlockAst]$paramBlockAst) {
      Write-Debug -Message "CodeGen::VisitParamBlock"

      $paramBlockAst.Attributes.ForEach({$_.Visit($this)});
      $this.AppendToken([TokenKind]::Param);
      $this.AppendToken([TokenKind]::LParen);
      $this.JoinVisit([TokenKind]::Comma, $paramBlockAst.Parameters);
      $this.AppendToken([TokenKind]::RParen);

      return $this;
   }

   [object] VisitNamedBlock([NamedBlockAst]$namedBlockAst) {
      Write-Debug -Message "CodeGen::VisitNamedBlock"

      $namedBlockAst.Traps.ForEach({$_.Visit($this)});

      $this.JoinVisit([TokenKind]::Semi, [StatementAst[]]@($namedBlockAst.Statements.Where({$_ -isnot [CommandExpressionAst] -or $_.Expression -isnot [BaseCtorInvokeMemberExpressionAst]})))
      return $this;
   }

   [object] VisitTypeConstraint([TypeConstraintAst]$typeConstraintAst) {
      Write-Debug -Message "CodeGen::VisitTypeConstraint"
      if ($typeConstraintAst.Parent -isnot [TypeDefinitionAst]) {
         $this.AppendToken([TokenKind]::LBracket);
      }
      $this.AppendTypeName($typeConstraintAst.TypeName);
      if ($typeConstraintAst.Parent -isnot [TypeDefinitionAst]) {
         $this.AppendToken([TokenKind]::RBracket);
      }

      return $this;
   }

   [object] VisitAttribute([AttributeAst]$attributeAst) {
      Write-Debug -Message "CodeGen::VisitAttribute"
      $this.AppendToken([TokenKind]::LBracket);
      $this.AppendTypeName($attributeAst.TypeName).AppendToken([TokenKind]::LParen)
      $this.JoinVisit([TokenKind]::Comma, $attributeAst.PositionalArguments, $attributeAst.NamedArguments)

      $this.AppendToken([TokenKind]::RParen, [TokenKind]::RBracket);

      return $this;
   }

   [object] VisitNamedAttributeArgument([NamedAttributeArgumentAst]$namedAttributeArgumentAst) {
      Write-Debug -Message "CodeGen::VisitNamedAttributeArgument"
      $this.Append($namedAttributeArgumentAst.ArgumentName).AppendToken([TokenKind]::Equals);
      $namedAttributeArgumentAst.Argument.Visit($this)
      return $this;
   }

   [object] VisitParameter([ParameterAst]$parameterAst) {
      Write-Debug -Message "CodeGen::VisitParameter"
      $parameterAst.Attributes.ForEach({$_.Visit($this)})
      $parameterAst.Name.Visit($this)

      if ($parameterAst.DefaultValue -ne $null) {
         $this.AppendToken([TokenKind]::Equals);
         $parameterAst.DefaultValue.Visit($this);
      }

      return $this;
   }

   [object] VisitFunctionDefinition([FunctionDefinitionAst]$functionDefinitionAst) {
      Write-Debug -Message "CodeGen::VisitFunctionDefinition"

      $this.AppendToken([TokenKind]::Function).AppendSpace().Append($functionDefinitionAst.Name);

      if ($null -ne $functionDefinitionAst.Parameters -and $functionDefinitionAst.Parameters.Count -gt 0) {
         $this.AppendToken([TokenKind]::LParen);
         $this.JoinVisit([TokenKind]::Comma, $functionDefinitionAst.Parameters)
         $this.AppendToken([TokenKind]::RParen);
      }
      $functionDefinitionAst.Body.Visit($this);
      return $this;
   }

   [object] VisitStatementBlock([StatementBlockAst]$statementBlockAst) {
      Write-Debug -Message "CodeGen::VisitStatementBlock"

      $statementBlockAst.Traps.ForEach({$_.Visit($this)})

      $this.JoinVisit([TokenKind]::Semi, $statementBlockAst.Statements)

      return $this;
   }
   [object] VisitIfStatement([IfStatementAst]$ifStmtAst) {
      Write-Debug -Message "CodeGen::VisitIfStatement"

      [bool]$needsElseIf = $false;
      foreach ($clause in $ifStmtAst.Clauses) {
         if ($needsElseIf) {
            $this.AppendToken([TokenKind]::ElseIf);
         } else {
            $this.AppendToken([TokenKind]::If);
            $needsElseIf = $true
         }
         
         $this.AppendToken([TokenKind]::LParen)
         $clause.Item1.Visit($this);
         $this.AppendToken([TokenKind]::RParen)
         $this.AppendToken([TokenKind]::LCurly)
         $clause.Item2.Visit($this);
         $this.AppendToken([TokenKind]::RCurly)
      }

      if ($ifStmtAst.ElseClause -ne $null) {
         $this.AppendToken([TokenKind]::Else)
         $this.AppendToken([TokenKind]::LCurly)
         $ifStmtAst.ElseClause.Visit($this);
         $this.AppendToken([TokenKind]::RCurly)
      }

      return $this;
   }

   [object] VisitTrap([TrapStatementAst]$trapStatementAst) {
      Write-Debug -Message "CodeGen::VisitTrap"
      Write-Warning -Message "Not Implemented"

      return $this;
   }

   [object] VisitSwitchStatement([SwitchStatementAst]$switchStatementAst) {
      Write-Debug -Message "CodeGen::VisitSwitchStatement"
      
      if ($switchStatementAst.Label -ne $null) {
         $this.AppendToken([TokenKind]::Colon);
         $this.Append($switchStatementAst.Label).AppendSpace();
      }

      $this.AppendToken([TokenKind]::Switch);

      switch ($switchStatementAst.Flags) {
         File { $this.AppendSpace().Append('-File')}
         Regex {$this.AppendSpace().Append('-Regex')}
         Wildcard {$this.AppendSpace().Append('-Wildcard')}
         Exact {$this.AppendSpace().Append('-Exact')}
         CaseSensitive {$this.AppendSpace().Append('-CaseSensitive')}
         Parallel {$this.AppendSpace().Append('-Parallel')}
      }

      $this.AppendToken([TokenKind]::LParen);
      $switchStatementAst.Condition.Visit($this);
      $this.AppendToken([TokenKind]::RParen);

      $this.AppendToken([TokenKind]::LCurly);
      [bool]$needsSpace = $false;
      foreach ($clause in $switchStatementAst.Clauses) {
         if ($needsSpace) {
            $this.AppendSpace();
         } else {
            $needsSpace = $true;
         }
         $clause.Item1.Visit($this);
         $this.AppendSpace();
         $this.AppendToken([TokenKind]::LCurly);
         $clause.Item2.Visit($this);
         $this.AppendToken([TokenKind]::RCurly);
      }
      if ($null -ne $switchStatementAst.Default) {
         $this.AppendSpace();
         $this.Append('default').AppendSpace();
         $this.AppendToken([TokenKind]::LCurly);
         $switchStatementAst.Default.Visit($this);
         $this.AppendToken([TokenKind]::RCurly);
      }
      $this.AppendToken([TokenKind]::RCurly);

      return $this;
   }

   [object] VisitDataStatement([DataStatementAst]$dataStatementAst) {
      Write-Debug -Message "CodeGen::VisitDataStatement"
      Write-Warning -Message "Not Implemented"
      return $this;
   }

   [object] VisitForEachStatement([ForEachStatementAst]$forEachStatementAst) {
      Write-Debug -Message "CodeGen::VisitForEachStatement"

      if ($forEachStatementAst.Label -ne $null) {
         $this.AppendToken([TokenKind]::Colon);
         $this.Append($forEachStatementAst.Label).AppendSpace();
      }
      $this.AppendToken([TokenKind]::Foreach);
      if (($forEachStatementAst.Flags -band [ForEachFlags]::Parallel) -eq [ForEachFlags]::Parallel) {
         $this.Append(' -Parallel');
      }
      if ($forEachStatementAst.ThrottleLimit -ne $null) {
         $this.Append(' -ThrottleLimit ');
         $forEachStatementAst.ThrottleLimit.Visit($this);
         $this.AppendSpace()
      }
      $this.AppendToken([TokenKind]::LParen)
      $forEachStatementAst.Variable.Visit($this);
      $this.AppendSpace().AppendToken([TokenKind]::In).AppendSpace()
      $forEachStatementAst.Condition.Visit($this);
      $this.AppendToken([TokenKind]::RParen)

      $this.AppendToken([TokenKind]::LCurly)
      $forEachStatementAst.Body.Visit($this);
      $this.AppendToken([TokenKind]::RCurly)

      return $this;
   }

   [object] VisitDoWhileStatement([DoWhileStatementAst]$doWhileStatementAst) {
      Write-Debug -Message "CodeGen::VisitDoWhileStatement"

      if ($doWhileStatementAst.Label -ne $null) {
         $this.AppendToken([TokenKind]::Colon);
         $this.Append($doWhileStatementAst.Label).AppendSpace();
      }

      $this.AppendToken([TokenKind]::Do, [TokenKind]::LCurly);
      $doWhileStatementAst.Body.Visit($this);
      $this.AppendToken([TokenKind]::RCurly, [TokenKind]::While, [TokenKind]::LParen);
      $doWhileStatementAst.Condition.Visit($this);
      $this.AppendToken([TokenKind]::RParen);

      return $this;
   }
   [object] VisitForStatement([ForStatementAst]$forStatementAst) {
      Write-Debug -Message "CodeGen::VisitForStatement"
      
      if ($forStatementAst.Label -ne $null) {
         $this.AppendToken([TokenKind]::Colon);
         $this.Append($forStatementAst.Label).AppendSpace();
      }

      $this.AppendToken([TokenKind]::For, [TokenKind]::LParen);
      $this.Visit($forStatementAst.Initializer)
      $this.AppendToken([TokenKind]::Semi);
      $this.Visit($forStatementAst.Condition)
      $this.AppendToken([TokenKind]::Semi);
      $this.Visit($forStatementAst.Iterator)
      $this.AppendToken([TokenKind]::RParen, [TokenKind]::LCurly);
      if ($forStatementAst.Body -ne $null) {
         $forStatementAst.Body.Visit($this)
      }
      $this.AppendToken([TokenKind]::RCurly);

      return $this;
   }

   [object] VisitWhileStatement([WhileStatementAst]$whileStatementAst) {
      Write-Debug -Message "CodeGen::VisitWhileStatement"

      if ($whileStatementAst.Label -ne $null) {
         $this.AppendToken([TokenKind]::Colon);
         $this.Append($whileStatementAst.Label).AppendSpace();
      }

      $this.AppendToken([TokenKind]::While, [TokenKind]::LParen);
      $whileStatementAst.Condition.Visit($this);
      $this.AppendToken([TokenKind]::RParen, [TokenKind]::LCurly);
      $whileStatementAst.Body.Visit($this);
      $this.AppendToken([TokenKind]::RCurly);

      return $this;
   }

   [object] VisitCatchClause([CatchClauseAst]$catchClauseAst) {
      Write-Debug -Message "CodeGen::VisitCatchClause"
      $this.AppendToken([TokenKind]::Catch);
      if ($null -ne $catchClauseAst -and $catchClauseAst.CatchTypes.Count -gt 0) {
         $this.AppendSpace();
         $this.JoinVisit([TokenKind]::Comma, $catchClauseAst.CatchTypes);
      }
      $this.AppendToken([TokenKind]::LCurly);
      $catchClauseAst.Body.Visit($this);
      $this.AppendToken([TokenKind]::RCurly);

      return $this;
   }

   [object] VisitTryStatement([TryStatementAst]$tryStatementAst) {
      Write-Debug -Message "CodeGen::VisitTryStatement"
      $this.AppendToken([TokenKind]::Try, [TokenKind]::LCurly);
      if ($tryStatementAst.Body -ne $null) {
         $tryStatementAst.Body.Visit($this)
      }
      $this.AppendToken([TokenKind]::RCurly);
      $tryStatementAst.CatchClauses.ForEach({$_.Visit($this)})
      if ($tryStatementAst.Finally -ne $null){
         $this.AppendToken([TokenKind]::Finally, [TokenKind]::LCurly);
         $tryStatementAst.Finally.Visit($this);
         $this.AppendToken([TokenKind]::RCurly);
      }

      return $this;
   }
   [object] VisitBreakStatement([BreakStatementAst]$breakStatementAst) {
      Write-Debug -Message "CodeGen::VisitBreakStatement"
      $this.AppendToken([TokenKind]::Break);
      if ($breakStatementAst.Label -ne $null) {
         $this.AppendSpace().Append($breakStatementAst.Label)
      }
      return $this;
   }

   [object] VisitContinueStatement([ContinueStatementAst]$continueStatementAst) {
      Write-Debug -Message "CodeGen::VisitContinueStatement"
      
      $this.AppendToken([TokenKind]::Continue);
      if ($continueStatementAst.Label -ne $null) {
         $this.AppendSpace().Append($continueStatementAst.Label)
      }

      return $this;
   }

   [object] VisitReturnStatement([ReturnStatementAst]$returnStatementAst) {
      Write-Debug -Message "CodeGen::VisitReturnStatement"

      $this.AppendToken([TokenKind]::Return);
      if ($returnStatementAst.Pipeline -ne $null) {
         $this.AppendSpace();
         $returnStatementAst.Pipeline.Visit($this);
      }

      return $this;
   }

   [object] VisitExitStatement([ExitStatementAst]$exitStatementAst) {
      Write-Debug -Message "CodeGen::VisitExitStatement"
      
      $this.AppendToken([TokenKind]::Exit);
      if ($exitStatementAst.Pipeline -ne $null) {
         $exitStatementAst.Pipeline.Visit($this);
      }
      return $this;
   }

   [object] VisitThrowStatement([ThrowStatementAst]$throwStatementAst) {
      Write-Debug -Message "CodeGen::VisitThrowStatement"
      $this.AppendToken([TokenKind]::Throw);
      if ($throwStatementAst.Pipeline -ne $null) {
         $this.AppendSpace();
         $throwStatementAst.Pipeline.Visit($this);
      }
      return $this;
   }
   [object] VisitDoUntilStatement([DoUntilStatementAst]$doUntilStatementAst) {
      Write-Debug -Message "CodeGen::VisitDoUntilStatement"
      Write-Warning -Message "Not Implemented"

      return $this;
   }

   [object] VisitAssignmentStatement([AssignmentStatementAst]$assignmentStatementAst) {
      Write-Debug -Message "CodeGen::VisitAssignmentStatement"

      $assignmentStatementAst.Left.Visit($this)
      $this.AppendToken($assignmentStatementAst.Operator)
      $assignmentStatementAst.Right.Visit($this)

      return $this;
   }

   [object] VisitPipeline([PipelineAst]$pipelineAst) {
      Write-Debug -Message "CodeGen::VisitPipeline"
      $this.JoinVisit([TokenKind]::Pipe, $pipelineAst.PipelineElements);
      return $this;
   }

   [object] VisitCommand([CommandAst]$commandAst) {
      Write-Debug -Message "CodeGen::VisitCommand"

      if ($commandAst.InvocationOperator -ne [TokenKind]::Unknown) {
         $this.AppendToken($commandAst.InvocationOperator).AppendSpace();
      }
      for($elementPos = 0; $elementPos -lt $commandAst.CommandElements.Count; $elementPos++) {
         if ($elementPos -gt 0) {
            $this.AppendSpace();
         }
         $commandAst.CommandElements[$elementPos].Visit($this);
      }
      return $this;
   }

   [object] VisitCommandExpression([CommandExpressionAst]$commandExpressionAst) {
      Write-Debug -Message "CodeGen::VisitCommandExpression"

      return $commandExpressionAst.Expression.Visit($this)
   }

   [object] VisitCommandParameter([CommandParameterAst]$commandParameterAst) {
      Write-Debug -Message "CodeGen::VisitCommandParameter"

      $this.AppendToken([TokenKind]::Minus).Append($commandParameterAst.ParameterName);
      if ($commandParameterAst.Argument -ne $null) {
         $this.AppendToken([TokenKind]::Colon);
         $commandParameterAst.Argument.Visit($this);
      }
      return $this;
   }

   [object] VisitFileRedirection([FileRedirectionAst]$fileRedirectionAst) {
      Write-Debug -Message "CodeGen::VisitFileRedirection"
      Write-Warning -Message "Not Implemented"

      return $this;
   }

   [object] VisitMergingRedirection([MergingRedirectionAst]$mergingRedirectionAst) {
      Write-Debug -Message "CodeGen::VisitMergingRedirection"
      Write-Warning -Message "Not Implemented"

      return $this;
   }

   [object] VisitBinaryExpression([BinaryExpressionAst]$binaryExpressionAst) {
      Write-Debug -Message "CodeGen::VisitBinaryExpression"
      $binaryExpressionAst.Left.Visit($this);
      $this.AppendSpace().AppendToken($binaryExpressionAst.Operator).AppendSpace();
      $binaryExpressionAst.Right.Visit($this);
      return $this;
   }

   [object] VisitUnaryExpression([UnaryExpressionAst]$unaryExpressionAst) {
      Write-Debug -Message "CodeGen::VisitUnaryExpression"
      
      switch ($unaryExpressionAst.TokenKind) {
         PostfixMinusMinus {
            $unaryExpressionAst.Child.Visit($this);
            $this.AppendToken($unaryExpressionAst.TokenKind)
         }
         PostfixPlusPlus {
            $unaryExpressionAst.Child.Visit($this);
            $this.AppendToken($unaryExpressionAst.TokenKind)
         }
         PlusPlus {
            $this.AppendToken($unaryExpressionAst.TokenKind)
            $unaryExpressionAst.Child.Visit($this);
         }
         MinusMinus {
            $this.AppendToken($unaryExpressionAst.TokenKind)
            $unaryExpressionAst.Child.Visit($this);
         }
         Minus {
            $this.AppendToken($unaryExpressionAst.TokenKind)
            $unaryExpressionAst.Child.Visit($this);            
         }
         default {
            $this.AppendToken($unaryExpressionAst.TokenKind).AppendSpace();
            $unaryExpressionAst.Child.Visit($this);
         }
      }
      
      return $this;
   }

   [object] VisitConvertExpression([ConvertExpressionAst]$convertExpressionAst) {
      Write-Debug -Message "CodeGen::VisitConvertExpression"
      $convertExpressionAst.Type.Visit($this);
      $convertExpressionAst.Child.Visit($this);
      return $this;
   }

   [object] VisitConstantExpression([ConstantExpressionAst]$constantExpressionAst) {
      Write-Debug -Message "CodeGen::VisitConstantExpression"

      # TODO this is most likely not good enough
      return $this.output.Append($constantExpressionAst.Value);
   }

   [object] VisitStringConstantExpression([StringConstantExpressionAst]$stringConstantExpressionAst) {
      Write-Debug -Message "CodeGen::VisitStringConstantExpression"

      [string]$prefix = ""
      [string]$suffix = ""
      [string]$value = $stringConstantExpressionAst.Value;
      switch ($stringConstantExpressionAst.StringConstantType) {
         BareWord {}
         DoubleQuoted {
            $prefix = $suffix = '"'
            $value = $value.Replace('`', '``').Replace('$', '`$').Replace('"', '`"');
         }
         DoubleQuotedHereString {
            $prefix = '@"' + [System.Environment]::NewLine
            $suffix = [System.Environment]::NewLine + '"@'
            $value = $value.Replace('`', '``').Replace('$', '`$');
         }
         SingleQuoted {
            $prefix = $suffix = "'"
            $value = [CodeGeneration]::EscapeSingleQuotedStringContent($value)
         }
         SingleQuotedHereString {
            $prefix = "@'" + [System.Environment]::NewLine
            $suffix = [System.Environment]::NewLine + "'@"
         }
      }
      return $this.Append($prefix).Append($value).Append($suffix);
   }

   [object] VisitSubExpression([SubExpressionAst]$subExpressionAst) {
      Write-Debug -Message "CodeGen::VisitSubExpression"
      $this.AppendToken([TokenKind]::DollarParen);
      $subExpressionAst.SubExpression.Visit($this);
      $this.AppendToken([TokenKind]::RParen);
      return $this;
   }

   [object] VisitUsingExpression([UsingExpressionAst]$usingExpressionAst) {
      Write-Debug -Message "CodeGen::VisitUsingExpression"

      $this.output.Append('$using:')
      return $usingExpressionAst.SubExpression.Visit($this)
   }

   [object] VisitVariableExpression([VariableExpressionAst]$variableExpressionAst) {
      Write-Debug -Message "CodeGen::VisitVariableExpression"

      [bool]$isInUsingScope = $false;
      for($parent = $variableExpressionAst.Parent; $parent -ne $null ;$parent = $parent.Parent) {
         if ($parent -is [UsingExpressionAst]) {
            $isInUsingScope = $true;
            break;
         }
      }

      if (-not $isInUsingScope) {
         if ($variableExpressionAst.Splatted) {
            $this.Append('@');
         } else {
            $this.Append('$');
         }
         
      }
      return $this.Append($variableExpressionAst.VariablePath)
   }

   [object] VisitTypeExpression([TypeExpressionAst]$typeExpressionAst) {
      Write-Debug -Message "CodeGen::VisitTypeExpression"
      $this.AppendToken([TokenKind]::LBracket)
      $this.AppendTypeName($typeExpressionAst.TypeName)
      $this.AppendToken([TokenKind]::RBracket)
      return $this;
   }

   [object] VisitMemberExpression([MemberExpressionAst]$memberExpressionAst) {
      Write-Debug -Message "CodeGen::VisitMemberExpression"

      $memberExpressionAst.Expression.Visit($this);
      if ($memberExpressionAst.Static) {
         $this.AppendToken([TokenKind]::ColonColon)
      } else {
         $this.AppendToken([TokenKind]::Dot)
      }
      $memberExpressionAst.Member.Visit($this);
      return $this;
   }

   [object] VisitInvokeMemberExpression([InvokeMemberExpressionAst]$invokeMemberExpressionAst) {
      Write-Debug -Message "CodeGen::VisitInvokeMemberExpression"

      $invokeMemberExpressionAst.Expression.Visit($this);
      if ($invokeMemberExpressionAst.Static) {
         $this.AppendToken([TokenKind]::ColonColon)
      } else {
         $this.AppendToken([TokenKind]::Dot)
      }
      $invokeMemberExpressionAst.Member.Visit($this);
      $this.AppendToken([TokenKind]::LParen)
      $this.JoinVisit([TokenKind]::Comma, $invokeMemberExpressionAst.Arguments);

      $this.AppendToken([TokenKind]::RParen)
      return $this;
   }

   [object] VisitArrayExpression([ArrayExpressionAst]$arrayExpressionAst) {
      Write-Debug -Message "CodeGen::VisitArrayExpression"
      $this.AppendToken([TokenKind]::AtParen)
      $this.Visit($arrayExpressionAst.SubExpression);
      $this.AppendToken([TokenKind]::RParen)

      return $this;
   }

   [object] VisitArrayLiteral([ArrayLiteralAst]$arrayLiteralAst) {
      Write-Debug -Message "CodeGen::VisitArrayLiteral"
      $this.JoinVisit([TokenKind]::Comma, $arrayLiteralAst.Elements);
      return $this;
   }

   [object] VisitHashtable([HashtableAst]$hashtableAst) {
      Write-Debug -Message "CodeGen::VisitHashtable"
      $this.AppendToken([TokenKind]::AtCurly)
      for($elementPos = 0; $elementPos -lt $hashtableAst.KeyValuePairs.Count; $elementPos++) {
         if ($elementPos -gt 0) {
            $this.AppendToken([TokenKind]::Semi)
         }
         $hashtableAst.KeyValuePairs[$elementPos].Item1.Visit($this);
         $this.AppendToken([TokenKind]::Equals)
         $hashtableAst.KeyValuePairs[$elementPos].Item2.Visit($this);
      }
      $this.AppendToken([TokenKind]::RCurly)
      return $this;
   }

   [object] VisitScriptBlockExpression([ScriptBlockExpressionAst]$scriptBlockExpressionAst) {
      Write-Debug -Message "CodeGen::VisitScriptBlockExpression"

      return $scriptBlockExpressionAst.ScriptBlock.Visit($this);
   }

   [object] VisitParenExpression([ParenExpressionAst]$parenExpressionAst) {
      Write-Debug -Message "CodeGen::VisitParenExpression"

      $this.AppendToken([TokenKind]::LParen)
      $parenExpressionAst.Pipeline.Visit($this)
      return $this.AppendToken([TokenKind]::RParen)
   }

   [object] VisitExpandableStringExpression([ExpandableStringExpressionAst]$expandableStringExpressionAst) {
      Write-Debug -Message "CodeGen::VisitExpandableStringExpression"
      
      # TODO/HACK see https://github.com/PowerShell/PowerShell/issues/5365 for background info.
      $internalProperty = [ExpandableStringExpressionAst].GetProperty('FormatExpression', ([System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic));
      if ($null -eq $internalProperty) {
         throw "Internal property 'FormatExpression' on ExpandableStringExpressionAst not found.";
      }

      [string]$formatExpression = $internalProperty.GetValue($expandableStringExpressionAst);

      [string]$prefix = ""
      [string]$suffix = ""
      switch ($expandableStringExpressionAst.StringConstantType) {
         BareWord {}
         DoubleQuoted {
            $prefix = $suffix = '"'
            $formatExpression = $formatExpression.Replace('`', '``').Replace('$', '`$').Replace('"', '`"');
         }
         DoubleQuotedHereString {
            $prefix = '@"' + [System.Environment]::NewLine
            $suffix = [System.Environment]::NewLine + '"@'
            $formatExpression = $formatExpression.Replace('`', '``').Replace('$', '`$');
         }
      }
      $value = [String]::Format($formatExpression, [object[]]($expandableStringExpressionAst.NestedExpressions.ForEach({[CodeGen]::Write($_, [CodeGenOptions]::None)})));
      
      return $this.Append($prefix).Append($value).Append($suffix);      
      return $this;
   }

   [object] VisitIndexExpression([IndexExpressionAst]$indexExpressionAst) {
      Write-Debug -Message "CodeGen::VisitIndexExpression"
      
      $indexExpressionAst.Target.Visit($this);
      $this.AppendToken([TokenKind]::LBracket);
      $indexExpressionAst.Index.Visit($this);
      $this.AppendToken([TokenKind]::RBracket);

      return $this;
   }

   [object] VisitAttributedExpression([AttributedExpressionAst]$attributedExpressionAst) {
      Write-Debug -Message "CodeGen::VisitAttributedExpression"
      Write-Warning -Message "Not Implemented"
      return $this;
   }

   [object] VisitBlockStatement([BlockStatementAst]$blockStatementAst) {
      Write-Debug -Message "CodeGen::VisitBlockStatement"

      $this.AppendToken([TokenKind]::LCurly)
      $blockStatementAst.Body.Visit($this);
      $this.AppendToken([TokenKind]::RCurly)
      return $this;
   }

   [object] VisitTypeDefinition([TypeDefinitionAst]$typeDefinitionAst) {
      Write-Debug -Message "CodeGen::TypeDefinitionAst (Name: $($typeDefinitionAst.Name))"
      $typeDefinitionAst.Attributes.ForEach({$_.Visit($this)});
      $typeToken = switch ($typeDefinitionAst.TypeAttributes) {
         Class {[TokenKind]::Class}
         Interface {[TokenKind]::Interface}
         Enum {[TokenKind]::Enum}
      }
      $this.AppendToken($typeToken).AppendSpace()
      $this.Append($typeDefinitionAst.Name)
      if ($typeDefinitionAst.BaseTypes.Count -gt 0) {
         $this.AppendToken([TokenKind]::Colon);

         $this.JoinVisit([TokenKind]::Comma, $typeDefinitionAst.BaseTypes);
      }
      $this.AppendToken([TokenKind]::LCurly);
      $typeDefinitionAst.Members.ForEach({$_.Visit($this)})
      $this.AppendToken([TokenKind]::RCurly);

      return $this;
   }
   
   [object] VisitPropertyMember([PropertyMemberAst]$propertyMemberAst) {
      Write-Debug -Message "CodeGen::PropertyMemberAst (Name: $($propertyMemberAst.Name))"
      $propertyMemberAst.Attributes.ForEach({$_.Visit($this)});
      if (-not $propertyMemberAst.Parent.IsEnum) {
         if ($propertyMemberAst.IsHidden)
         {
            $this.AppendToken([TokenKind]::Hidden).AppendSpace();
         }
         if ($propertyMemberAst.IsStatic)
         {
            $this.AppendToken([TokenKind]::Static).AppendSpace();
         }
         if ($propertyMemberAst.PropertyType -ne $null) {
            $propertyMemberAst.PropertyType.Visit($this);
         }
         $this.Append('$');
      }
      $this.Append($propertyMemberAst.Name);
      if ($propertyMemberAst.InitialValue -ne $null) {
         $this.AppendToken([TokenKind]::Equals).AppendSpace();
         $propertyMemberAst.InitialValue.Visit($this);
      }
      $this.AppendToken([TokenKind]::Semi);

      return $this;
   }
   
   [object] VisitFunctionMember([FunctionMemberAst]$functionMemberAst) {
      Write-Debug -Message "CodeGen::FunctionMemberAst (Name: $($functionMemberAst.Name))"
      $functionMemberAst.Attributes.ForEach({$_.Visit($this)});
      if ($functionMemberAst.IsHidden)
      {
         $this.AppendToken([TokenKind]::Hidden).AppendSpace();
      }
      if ($functionMemberAst.IsStatic)
      {
         $this.AppendToken([TokenKind]::Static).AppendSpace();
      }
      if ($functionMemberAst.ReturnType -ne $null) {
         $functionMemberAst.ReturnType.Visit($this);
      }

      $this.Append($functionMemberAst.Name);
      $this.AppendToken([TokenKind]::LParen);
      $this.JoinVisit([TokenKind]::Comma, $functionMemberAst.Parameters)
      $this.AppendToken([TokenKind]::RParen);
      if ($functionMemberAst.IsConstructor){
         $commandExpressionAst = $functionMemberAst.Body.Find({param($ast) $ast -is [CommandExpressionAst] -and $ast.Expression -is [BaseCtorInvokeMemberExpressionAst]}, $true)
         if ($commandExpressionAst -ne $null) {
            $commandExpressionAst.Expression.Visit($this);
         }
      }
      # script block will add it's own curlys
      $functionMemberAst.Body.Visit($this);
      return $this;
   }
   
   [object] VisitBaseCtorInvokeMemberExpression([BaseCtorInvokeMemberExpressionAst]$baseCtorInvokeMemberExpressionAst) {
      Write-Debug -Message "CodeGen::BaseCtorInvokeMemberExpressionAst"
      $this.AppendToken([TokenKind]::Colon, [TokenKind]::Base, [TokenKind]::LParen);
      $this.JoinVisit([TokenKind]::Comma, $baseCtorInvokeMemberExpressionAst.Arguments);
      $this.AppendToken([TokenKind]::RParen);  
      return $this;
   }
   
   [object] VisitUsingStatement([UsingStatementAst]$usingStatement) {
      Write-Debug -Message "CodeGen::UsingStatementAst"
      # TODO this is incomplete
      $this.AppendToken([TokenKind]::Using).AppendSpace()
      $this.Append($usingStatement.UsingStatementKind.ToString().ToLowerInvariant()).AppendSpace()
      $this.Append($usingStatement.Name)
      $this.AppendToken([TokenKind]::Semi);
      return $this;
   }
   
   [object] VisitConfigurationDefinition([ConfigurationDefinitionAst]$configurationDefinitionAst) {
      Write-Debug -Message "CodeGen::ConfigurationDefinitionAst"
      Write-Warning -Message "Not Implemented"
      return $this;
   }
   
   [object] VisitDynamicKeywordStatement([DynamicKeywordStatementAst]$dynamicKeywordAst) {
      Write-Debug -Message "CodeGen::DynamicKeywordStatementAst"
      Write-Warning -Message "Not Implemented"
      return $this;
   }
}
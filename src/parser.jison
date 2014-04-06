/* operator assocations and precedence */
%left "+" "-"
%left "*" "/"
%left "^"
%left UMINUS

%start module

%% /* language grammar */

module
	: topLevelBlock
		{	return new yy.nodes.Module($1); }
	;

topLevelBlock
	: /* nothing */
		{	$$ = new yy.nodes.Block(); }
	| topLevelBlock topLevelRequire
		{	$1.push($2);
			$$ = $1; }
	| topLevelBlock terminatedTopLevelExpression
		{	$1.push($2);
			$$ = $1; }
	| topLevelBlock NEWLINE
	| topLevelBlock EOF
	;

block
	: /* nothing */
		{	$$ = new yy.nodes.Block(); }
	| block require
		{	$1.push($2);
			$$ = $1; }
	| block terminatedExpression
		{	$1.push($2);
			$$ = $1; }
	| block NEWLINE
	;

topLevelRequire
	: REQUIRE STRING AS IDENTIFIER
		{	$$ = new yy.nodes.TopLevelRequire($2, $4); }
	;

require
	: REQUIRE STRING AS IDENTIFIER
		{	$$ = new yy.nodes.Require($2, $4); }
	;

terminatedTopLevelExpression
	: topLevelExpression NEWLINE
	| topLevelExpression EOF
	;

terminatedExpression
	: expression NEWLINE
	;

topLevelExpression
	: topLevelAssignment
	| nonAssignmentExpression
	;

expression
	: assignment
	| nonAssignmentExpression
	;

nonAssignmentExpression
	: functionDeclaration
	| functionCall
	| NUMBER
		{$$ = new yy.nodes.Number($1);}
	| STRING
		{$$ = new yy.nodes.String($1.substring(1, $1.length - 1));}
	| IDENTIFIER
		{$$ = new yy.nodes.Identifier($1);}
	| objectLiteral
	;

functionDeclaration
	: "(" functionDeclarationParams ")" "->" "NEWLINE" "INDENT" block "DEDENT"
		{$$ = new yy.nodes.FunctionDeclaration($2, $7);}
	| "(" functionDeclarationParams ")" "->" terminatedExpression
		{$$ = new yy.nodes.FunctionDeclaration($2, $5);}
	;

functionDeclarationParams
	: /* nothing */
		{	$$ = new yy.nodes.FunctionDeclarationParamList(); }
	| IDENTIFIER
		{	$$ = new yy.nodes.FunctionDeclarationParamList();
			$$.push($1); }
	| functionDeclarationParams "," IDENTIFIER
		{	$1.push($2);
			$$ = $1; }
	;

topLevelAssignment
	: IDENTIFIER "=" expression
		{	$$ = new yy.nodes.TopLevelAssignment($1, $3); }
	;

assignment
	: IDENTIFIER "=" expression
		{$$ = new yy.nodes.Assignment($1, $3);}
	;

functionCall
	: IDENTIFIER "(" functionCallParams ")"
		{$$ = new yy.nodes.FunctionCall($1, $3);}
	;

functionCallParams
	: /* nothing */
		{	$$ = new yy.nodes.FunctionCallParamList();}
	| expression
		{	$$ = new yy.nodes.FunctionCallParamList();
			$$.push($1);	}
	| functionCallParams "," expression
		{	$1.push($2);
			$$ = $1; }
	;

objectLiteral
	: "{" "}"
		{	$$ = new yy.nodes.ObjectLiteral([]); }
	| "{" NEWLINE INDENT objectPropertyList NEWLINE DEDENT "}"
		{	$$ = new yy.nodes.ObjectLiteral($4); }
	;

objectPropertyList
	: objectProperty
		{	$$ = [$1]; }
	| objectPropertyList NEWLINE objectProperty
		{	$$ = $1;
			$$.push($3); }
	;

objectProperty
	: IDENTIFIER ":" expression
		{	$$ = {property: $1, value: $3}; }
	;

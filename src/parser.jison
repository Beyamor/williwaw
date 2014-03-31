/* operator assocations and precedence */
%left "+" "-"
%left "*" "/"
%left "^"
%left UMINUS

%start program

%% /* language grammar */

program
	: block EOF
		{return $1;}
	;

block
	: /* nothing */
		{	$$ = new yy.nodes.Block(); }
	| block terminatedExpression
		{	$1.push($2);
			$$ = $1; }
	| block NEWLINE
		{	$$ = $1; }
	;

terminatedExpression
	: expression NEWLINE
		{$$ = $1;}
	;

expression
	: functionDeclaration
		{$$ = $1;}
	| functionCall
		{$$ = $1;}
	| NUMBER
		{$$ = new yy.nodes.Number($1);}
	| STRING
		{$$ = new yy.nodes.String($1.substring(1, $1.length - 1));}
	| assignment
		{$$ = $1;}
	| IDENTIFIER
		{$$ = new yy.nodes.Identifier($1);}
	;

functionDeclaration
	: "(" functionDeclarationParams ")" "->" "NEWLINE" "{" block "}"
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

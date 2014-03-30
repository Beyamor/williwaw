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
	| block expression
		{	$1.push($2);
			$$ = $1; }
	;

expression
	: functionDeclaration
		{$$ = $1;}
	| functionCall
		{$$ = $1;}
	| NUMBER
		{$$ = new yy.nodes.Number($1);}
	| assignment
		{$$ = $1;}
	;

functionDeclaration
	: FUNCTION "(" ")" "{" block "}"
		{$$ = new yy.nodes.FunctionDeclaration($5);}
	;

assignment
	: IDENT "=" expression
		{$$ = new yy.nodes.Assignment($1, $3);}
	;

functionCall
	: IDENT "(" functionCallParams ")"
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

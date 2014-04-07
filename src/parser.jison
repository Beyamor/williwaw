/* operator assocations and precedence */
%left "==" "!="
%left ">" ">=" "<" "<="
%left "+" "-"
%left "*" "/"
%left "^"
%left UMINUS
%nonassoc "("

%start module

%% /* language grammar */

number
	: NUMBER
		{	$$ = new yy.nodes.Number($1); }
	;

string
	: STRING
		{	$$ = new yy.nodes.String($1.substring(1, $1.length-1)); }
	;

boolean
	: TRUE
		{	$$ = true; }
	| FALSE
		{	$$ = false; }
	;

identifier
	: IDENTIFIER
		{	$$ = new yy.nodes.Identifier($1); }
	;

comma_separated_expressions
	: expression
		{	$$ = new yy.nodes.ExpressionList();
			$$.push($1); }
	| comma_separated_expressions "," expression
		{	$$ = $1;
			$$.push($3); }
	;

expression_tuple
	: "(" ")"
		{	$$ = new yy.nodes.ExpressionList(); }
	| "(" comma_separated_expressions ")"
		{	$$ = $2; }
	;

comma_separated_identifiers
	: identifier
		{	$$ = new yy.nodes.IdentifierList();
			$$.push($1); }
	| comma_separated_identifiers "," identifier
		{	$$ = $1;
			$$.push($3); }
	;

function_parameter_declaration
	: "->"
		{	$$ = new yy.nodes.IdentifierList(); }
	| "|" "|" "->"
		{	$$ = new yy.nodes.IdentifierList(); }
	| "|" comma_separated_identifiers "|" "->"
		{	$$ = $2; }
	;

function_call
	: expression expression_tuple
		{	$$ = new yy.nodes.FunctionCall($1, $2); }
	;

function_declaration
	: function_parameter_declaration block
		{	$$ = new yy.nodes.FunctionDeclaration($1, $2); }
	;

property
	: identifier ":" expression
		{	$$ = {property: $1, value: $3}; }
	;

property_list
	: /* empty */
		{	$$ = []; }
	| property_list property NEWLINE
		{	$$ = $1;
			$$.push($2); }
	;

object_literal
	: "{" NEWLINE INDENT property_list DEDENT "}"
		{	$$ = new yy.nodes.ObjectLiteral($4); }
	;

binary_operation
	: expression "+" expression { $$ = new yy.nodes.BinaryOperation($1, "+", $3); }
	| expression "-" expression { $$ = new yy.nodes.BinaryOperation($1, "-", $3); }
	| expression "*" expression { $$ = new yy.nodes.BinaryOperation($1, "*", $3); }
	| expression "/" expression { $$ = new yy.nodes.BinaryOperation($1, "/", $3); }
	| expression "==" expression { $$ = new yy.nodes.BinaryOperation($1, "===", $3); }
	| expression "!=" expression { $$ = new yy.nodes.BinaryOperation($1, "!==", $3); }
	| expression ">" expression { $$ = new yy.nodes.BinaryOperation($1, ">", $3); }
	| expression ">=" expression { $$ = new yy.nodes.BinaryOperation($1, ">=", $3); }
	| expression "<" expression { $$ = new yy.nodes.BinaryOperation($1, "<", $3); }
	| expression "<=" expression { $$ = new yy.nodes.BinaryOperation($1, "<=", $3); }
	;

expression
	: number
	| string
	| boolean
	| identifier
	| function_call
	| function_declaration
	| object_literal
	| binary_operation
	| "(" expression ")"
		{	$$ = $2; }
	;

assignment
	: identifier "=" expression
		{	$$ = new yy.nodes.Assignment($1, $3); }
	;

require
	: REQUIRE string AS identifier
		{	$$ = new yy.nodes.Require($2, $4); }
	;

statement
	: expression NEWLINE
	| assignment NEWLINE
	| require NEWLINE
	;

top_level_assignment
	: identifier "=" expression
		{	$$ = new yy.nodes.TopLevelAssignment($1, $3); }
	;

top_level_require
	: REQUIRE string AS identifier
		{	$$ = new yy.nodes.TopLevelRequire($2, $4); }
	;

top_level_statement
	: expression NEWLINE
	| top_level_assignment NEWLINE
	| top_level_require NEWLINE
	;

statements
	: /* empty */
		{	$$ = new yy.nodes.Block(); }
	| statements statement
		{	$1.push($2);
			$$ = $1; }
	| statements NEWLINE
	;

top_level_statements
	: /* empty */
		{	$$ = new yy.nodes.Block(); }
	| top_level_statements top_level_statement
		{	$1.push($2);
			$$ = $1; }
	| top_level_statements NEWLINE
	;

block
	: statement
	| NEWLINE INDENT statements DEDENT
		{	$$ = $3; }
	;

module
	: top_level_statements EOF
		{	return new yy.nodes.Module($1); }
	;

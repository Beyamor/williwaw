Lexer = require "lex"

indent	= [0]

lexer = module.exports = new Lexer (char) ->
				throw new Error "Unexpected character '#{char}'"

addRule = (rule, result) ->
	rule = new RegExp rule, "m"
	if typeof(result) isnt "function"
		action = (text) ->
			@yytext = text
			return result
	else
		action = result
	lexer.addRule rule, action

lexer.addRule /^	*/gm, (text) ->
	indentation = text.length

	if indentation > indent[0]
		indent.unshift indentation
		return "INDENT"

	tokens = []

	while indentation < indent[0]
		tokens.push "DEDENT"
		indent.shift()

	return tokens if tokens.length isnt 0

addRule "[ 	]+"

addRule "\n", ->
	@yylineno = 0 unless @yylineno?
	@yylineno++
	"NEWLINE"
addRule "fn", "FN"
addRule "require", "REQUIRE"
addRule "as", "AS"
addRule "[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z][a-zA-Z0-9_]*)*", "IDENTIFIER"
addRule "[0-9]+(\\.[0-9]+)?", "NUMBER"
addRule "\\|", "|"
addRule "->", "->"
addRule "\\(", "("
addRule "\\)", ")"
addRule "=", "="
addRule ",", ","
addRule "$", "EOF"
addRule "\\{", "{"
addRule "\\}", "}"
addRule ":", ":"
addRule "\".*\"", "STRING"
addRule "\\+", "+"
addRule "-", "-"
addRule "\\*", "*"
addRule "/", "/"

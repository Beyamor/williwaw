fs	= require "fs"
{Lexer}	= require "./lexer"
{parse} = require "./parser"
stdin	= process.openStdin()

fs.readFile process.argv[2], (err, data) ->
	data = data.toString()
	lexer = new Lexer
	tokens = lexer.lex data
	tree = parse tokens
	console.log tree.toString()
	process.exit()

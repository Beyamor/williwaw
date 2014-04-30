fs	= require "fs"
{lex}	= require "./lexer"
{parse} = require "./parser"
stdin	= process.openStdin()

fs.readFile process.argv[2], (err, data) ->
	data = data.toString()
	tokens = lex data
	tree = parse tokens
	console.log tree.toString()
	process.exit()

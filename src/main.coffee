fs		= require "fs"
{Lexer}		= require "./lexer"
{Parser}	= require "./parser"

[_, _, fileName] = process.argv
fileContents = fs.readFileSync fileName, "utf8"
tokens = (new Lexer).lex fileContents
code = (new Parser).parse tokens
console.log code.genCode()

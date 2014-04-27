fs		= require "fs"
{Lexer}		= require "./lexer"
{parse}		= require "./parser"

[_, _, fileName] = process.argv
fileContents = fs.readFileSync fileName, "utf8"
tokens = (new Lexer).lex fileContents
code = parse tokens
console.log code.genCode()

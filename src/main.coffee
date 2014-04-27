fs		= require "fs"
{Lexer}		= require "./lexer"
{parse}		= require "./parser"
{generate}	= require "./generator"

[_, _, fileName] = process.argv
fileContents = fs.readFileSync fileName, "utf8"
tokens = (new Lexer).lex fileContents
tree = parse tokens
code = generate tree
console.log code

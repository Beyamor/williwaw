fs		= require "fs"
{lex}		= require "./lexer"
{parse}		= require "./parser"
{generate}	= require "./generator"

[_, _, fileName] = process.argv
fileContents = fs.readFileSync fileName, "utf8"
tokens = lex fileContents
tree = parse tokens
code = generate tree
console.log code

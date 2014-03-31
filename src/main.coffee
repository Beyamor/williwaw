fs		= require "fs"
{parser}	= require "./parser"
nodes		= require "./nodes"
lexer		= require "./lexer"

parser.lexer = lexer
parser.yy.nodes = nodes

[_, _, fileName] = process.argv
fileContents = fs.readFileSync fileName, "utf8"
code = parser.parse fileContents
console.log code.genCode()

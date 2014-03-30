fs		= require "fs"
{parser}	= require "./heson"
nodes		= require "./nodes"

parser.yy.nodes = nodes

[_, _, fileName] = process.argv
fileContents = fs.readFileSync fileName, "utf8"
code = parser.parse fileContents
console.log code.genCode()

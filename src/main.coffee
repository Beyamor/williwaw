fs		= require "fs"
{parser}	= require "./heson"

[_, _, fileName] = process.argv
fileContents = fs.readFileSync fileName, "utf8"
parser.parse fileContents

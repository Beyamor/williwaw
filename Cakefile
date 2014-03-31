fs	= require "fs"
{print}	= require "sys"
{spawn}	= require "child_process"

spawnAndWatch = (name, args) ->
	child = spawn name, args
	child.stderr.on "data", (data) ->
		process.stderr.write data.toString()
	child.stdout.on "data", (data) ->
		console.log data.toString()
	child.on "exit", (code) ->
		callback?() if code is 0


task "build", "Build bin/ from src/", (callback) ->
	coffee = spawnAndWatch "coffee", ["-c", "-o", "bin", "src"]
	
task "watch", "Watch src/ for changes", (callback) ->
	coffee = spawnAndWatch "coffee", ["-w", "-c", "-o", "bin", "src"]

	parserFiles = ["src/heson.jison"] #, "src/heson.jisonlex"]
	parseBuilderCommands = ["-o", "bin/heson.js"].concat parserFiles

	rebuildParser = ->
		spawnAndWatch "jison", parseBuilderCommands

	for parserFile in parserFiles
		fs.watchFile parserFile, persistent: true, rebuildParser

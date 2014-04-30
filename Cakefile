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

task "build", "Build hs/ from src/", (callback) ->
	spawnAndWatch "coffee", ["-c", "-o", "js", "src"]
	
task "watch", "Watch src/ for changes", (callback) ->
	coffee = spawnAndWatch "coffee", ["-w", "-c", "-o", "js", "src"]

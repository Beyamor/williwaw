lines = (args...) ->
	args.join("\n")

generators =
	identifier: (identifier) ->
		identifier.value

	string: (string) ->
		string.value

	require: (_, [path, binding]) ->
		"#{@generate binding} = require(#{@generate path})"

	do: (_, children) ->
		s = "{"
		for child in children
			s += "#{@generate child};\n"
		s += "}"
		return s

	module: (_, [body]) ->
		lines \
		"define([],",
		"       function() {",
		@generate(body),
		"};"

class Generator
	generate: (node) ->
		generator = generators[node.type]
		throw new Error "No generator for #{node.type}" unless generator?
		return generator.call this, node, node.children

exports.generate = (tree) ->
	(new Generator).generate(tree)

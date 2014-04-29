lines = (args...) ->
	args.join("\n")

valueGenerator = ({value}) ->
	value

binaryGenerator = (f) ->
	({children}, blockDepth) ->
		[lhs, rhs] = children
		f.call(this, lhs, rhs, blockDepth)

directBinaryOperator = ({type, children}, blockDepth) ->
	[lhs, rhs] = children
	return "(#{@generate lhs, blockDepth} #{type} #{@generate rhs, blockDepth})"

indents = (blockDepth) ->
	new Array(blockDepth).join("	")

declare = (identifier, node) ->
	nearestScope = null
	previouslyDeclared = false
	while node?
		if node.scope?
			if node.scope.indexOf(identifier) isnt -1
				previouslyDeclared = true
				break
			else
				nearestScope = node.scope unless nearestScope
		node = node.parent
	unless previouslyDeclared
		nearestScope.push identifier

declarations = (scope, blockDepth) ->
	if scope.length > 0
		indents(blockDepth) + "var #{scope.join(", ")};\n"
	else
		""
generators =
	identifier: valueGenerator
	string: valueGenerator
	number: valueGenerator

	"+": directBinaryOperator
	"-": directBinaryOperator
	"*": directBinaryOperator
	"/": directBinaryOperator
	"==": directBinaryOperator
	"!=": directBinaryOperator
	">": directBinaryOperator
	">=": directBinaryOperator
	"<": directBinaryOperator
	"<=": directBinaryOperator

	"**": binaryGenerator (lhs, rhs, blockDepth) ->
		"(Math.pow(#{@generate lhs, blockDepth}, #{@generate rhs, blockDepth}))"

	assign: (node, blockDepth) ->
		[lhs, rhs] = node.children
		lhs = @generate lhs, blockDepth
		rhs = @generate rhs, blockDepth
		declare lhs, node
		"#{lhs} = #{rhs}"

	get: binaryGenerator (lhs, rhs, blockDepth) ->
		"#{@generate lhs, blockDepth}.#{@generate rhs, blockDepth}"

	call: ({children}, blockDepth) ->
		[f, args...] = children
		return "#{@generate f, blockDepth}(#{@commaSeparated args})"

	params: ({children}, blockDepth) ->
		@commaSeparated children

	fn: (node, blockDepth) ->
		node.scope = []
		[params, body] = node.children
		params = @generate params, blockDepth
		body = @generate body, blockDepth
		"function (#{params}) {\n" +
			declarations(node.scope, blockDepth) +
			"#{body}" +
		"}"

	property: binaryGenerator (lhs, rhs, blockDepth) ->
		"#{@generate lhs, blockDepth}: #{@generate rhs, blockDepth}"

	object: ({children}, blockDepth) ->
		s = "{\n"
		for child, index in children
			s += indents(blockDepth) + "#{@generate child, blockDepth + 1}"
			s += "," if index < children.length - 1
			s += "\n"
		s += indents(blockDepth - 1) + "}"
		return s

	require: (node, blockDepth) ->
		[path, binding] = node.children
		path = @generate path, blockDepth
		binding = @generate binding, blockDepth
		if node.handled
			return "/* top level require: #{path} => #{binding} */"
		else
			declare binding, node
			return "#{binding} = require(#{path})"

	do: ({children}, blockDepth) ->
		s = ""
		for child in children
			s += indents(blockDepth) + "#{@generate child, blockDepth + 1};\n"
		return s

	module: (module, blockDepth) ->
		module.scope = []
		{children} = module
		topLevelBindings = []
		topLevelPaths = []
		topLevelAssignments = []

		traverse = (node) ->
			if node.type is "require"
				[path, binding] = node.children
				topLevelBindings.push binding
				topLevelPaths.push path
				node.handled = true
			else if node.type is "assign"
				[identifier] = node.children
				topLevelAssignments.push identifier

			if node.type isnt "fn" and node.type isnt "require" and node.type isnt "assign" and node.children?
				traverse child for child in node.children
		traverse module

		moduleExports = topLevelAssignments.map((id) => @generate id).map((id) => "__exports.#{id} = #{id};").join("\n")

		body = @generate children[0], blockDepth + 1

		lines \
		"define([#{@commaSeparated topLevelPaths}],",
		"function(#{@commaSeparated topLevelBindings}){",
		"var __exports = {};",
		declarations(module.scope, blockDepth),
		body,
		moduleExports,
		"return __exports;",
		"});"

class Generator
	generate: (node, blockDepth=0) ->
		generator = generators[node.type]
		throw new Error "No generator for #{node.type}" unless generator?
		return generator.call this, node, blockDepth

	commaSeparated: (nodes) ->
		nodes.map((node) => @generate node, 0).join(", ")

exports.generate = (tree) ->
	(new Generator).generate(tree)

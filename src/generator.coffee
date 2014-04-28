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

	assign: binaryGenerator (lhs, rhs, blockDepth) ->
		"#{@generate lhs, blockDepth} = #{@generate rhs, blockDepth}"

	get: binaryGenerator (lhs, rhs, blockDepth) ->
		"#{@generate lhs, blockDepth}.#{@generate rhs, blockDepth}"

	call: ({children}, blockDepth) ->
		[f, args...] = children
		return "#{@generate f, blockDepth}(#{@commaSeparated args})"

	params: ({children}, blockDepth) ->
		@commaSeparated children

	fn: binaryGenerator (params, body, blockDepth) ->
		"function (#{@generate params, blockDepth})\n#{@generate body, blockDepth}"

	property: binaryGenerator (lhs, rhs, blockDepth) ->
		"#{@generate lhs, blockDepth}: #{@generate rhs, blockDepth}"

	object: ({children}, blockDepth) ->
		s = "\n" + indents(blockDepth) + "{\n"
		for child, index in children
			s += indents(blockDepth + 1) + "#{@generate child, blockDepth + 1}"
			s += "," if index < children.length - 1
			s += "\n"
		s += indents(blockDepth) + "}"
		return s

	require: ({children, handled}, blockDepth) ->
		[path, binding] = children
		return "/* top level require: #{@generate path} => #{@generate binding} */" if handled
		return "#{@generate binding, blockDepth} = require(#{@generate path, blockDepth})"

	do: ({children}, blockDepth) ->
		s = indents(blockDepth) + "{\n"
		for child in children
			s += indents(blockDepth) + "	" + "#{@generate child, blockDepth + 1};\n"
		s += indents(blockDepth) + "}"
		return s

	module: (module, blockDepth) ->
		{children} = module
		topLevelBindings = []
		topLevelPaths = []
		traverse = (node) ->
			if node.type is "require"
				[path, binding] = node.children
				topLevelBindings.push binding
				topLevelPaths.push path
				node.handled = true
			else if node.type isnt "fn" and node.children?
				traverse child for child in node.children
		traverse module

		lines \
		"define([#{@commaSeparated topLevelPaths}],",
		"function(#{@commaSeparated topLevelBindings})",
		@generate(children[0], blockDepth+1) + ");"

class Generator
	generate: (node, blockDepth=0) ->
		generator = generators[node.type]
		throw new Error "No generator for #{node.type}" unless generator?
		return generator.call this, node, blockDepth

	commaSeparated: (nodes) ->
		nodes.map((node) => @generate node, 0).join(", ")

exports.generate = (tree) ->
	(new Generator).generate(tree)

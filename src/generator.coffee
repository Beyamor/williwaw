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
		"function (#{@generate params, blockDepth}) {#{@generate body, blockDepth}}"

	property: binaryGenerator (lhs, rhs, blockDepth) ->
		"#{@generate lhs, blockDepth}: #{@generate rhs, blockDepth}"

	object: ({children}, blockDepth) ->
		s = indents(blockDepth) + "{\n"
		for child, index in children
			s += indents(blockDepth) + "#{@generate child, blockDepth + 1}"
			s += "," if index < children.length - 1
			s += "\n"
		s += indents(blockDepth) + "}"
		return s

	require: binaryGenerator (path, binding, blockDepth) ->
		return "#{@generate binding, blockDepth} = require(#{@generate path, blockDepth})"

	do: ({children}, blockDepth) ->
		s = indents(blockDepth) + "{\n"
		for child in children
			s += indents(blockDepth) + "	" + "#{@generate child, blockDepth + 1};\n"
		s += indents(blockDepth) + "}"
		return s

	module: ({children}, blockDepth) ->
		lines \
		"define([],",
		"function()",
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

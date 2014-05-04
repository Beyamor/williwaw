valueGenerator = ({value}) ->
	@write value

binaryGenerator = (f) ->
	({children}) ->
		[lhs, rhs] = children
		f.call(this, lhs, rhs)

directBinaryOperator = ({type, children}) ->
	[lhs, rhs] = children
	@write "("
	@generateNode lhs
	@write " #{type} "
	@generateNode rhs
	@write ")"

declarations = (scope) ->
	if scope.length > 0
		@writeTerminatedLine "var #{scope.join(", ")}"
	else
		""

processors =
	require: (node, blockDepth) ->
		unless node.handled?
			[path, binding] = node.children
			@declare binding, node

	assign: (node) ->
		[lhs, rhs] = node.children
		@declare lhs, node

	fn: (node) ->
		node.scope = []
	
	module: (module) ->
		module.scope = []
		module.topLevelBindings = []
		module.topLevelPaths = []
		module.topLevelAssignments = []
		traverse = (node) ->
			if node.type is "require"
				[path, binding] = node.children
				module.topLevelBindings.push binding
				module.topLevelPaths.push path
				node.handled = true
			else if node.type is "assign"
				[identifier] = node.children
				module.topLevelAssignments.push identifier

			if node.type isnt "fn" and node.type isnt "require" and node.type isnt "assign" and node.children?
				traverse child for child in node.children
		traverse module

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

	"**": binaryGenerator (lhs, rhs) ->
		@write "(Math.pow("
		@generateNode lhs
		@write ", "
		@generateNode rhs
		@write "))"

	assign: (node) ->
		[lhs, rhs] = node.children
		@generateNode lhs
		@write " = "
		@generateNode rhs

	get: binaryGenerator (lhs, rhs, blockDepth) ->
		@generateNode lhs
		@write "."
		@generateNode rhs

	call: ({children}, blockDepth) ->
		[f, args...] = children
		@generateNode f
		@write "("
		@commaSeparated args
		@write ")"

	params: ({children}, blockDepth) ->
		@commaSeparated children

	fn: (node, blockDepth) ->
		node.scope = []
		[params, body] = node.children
		@write "function ("
		@generateNode params
		@write ") "
		@inBlock =>
			@declareVariablesIn node.scope
			@generateNode body

	if: (node, blockDepth) ->
		[condition, ifTrue, ifFalse] = node.children
		@write "if ("
		@generateNode condition
		@write ") "
		@inBlock =>
			@generateNode ifTrue
		if ifFalse?
			@write " else "
			@inBlock =>
				@generateNode ifFalse

	property: binaryGenerator (lhs, rhs) ->
		@generateNode lhs
		@write ": "
		@generateNode rhs

	object: ({children}, blockDepth) ->
		@inBlock =>
			for child, index in children
				@writeLine =>
					@generateNode child
					@write "," if index < children.length - 1

	require: (node, blockDepth) ->
		[path, binding] = node.children
		if node.handled
			@write "/* #{binding.value} hoisted to module definition */"
		else
			@generateNode binding
			@write " = require("
			@generateNode path
			@write ")"

	do: ({children}, blockDepth) ->
		for child in children
			@writeAsTerminatedLine => @generateNode child

	module: (module) ->
		{topLevelAssignments, topLevelBindings, topLevelPaths} = module
		@write "define(["
		@commaSeparated topLevelPaths
		@write "],\n"
		@write "function("
		@commaSeparated topLevelBindings
		@write "){\n"
		@writeTerminatedLine "var __exports = {}"
		@declareVariablesIn module.scope
		@generateNode module.children[0]
		for topLevelAssignment in topLevelAssignments
			id = topLevelAssignment.value
			@writeTerminatedLine "__exports.#{id} = #{id}"
		@writeTerminatedLine "return __exports"
		@writeTerminatedLine "})"

class Generator
	process: (node) ->
		if processors[node.type]?
			processors[node.type].call this, node
		if node.children?
			@process child for child in node.children

	generate: (root) ->
		@text = ""
		@blockDepth = 0
		@process root
		@generateNode root
		return @text
	
	generateNode: (node) ->
		throw new Error "No node type for #{node}" unless node.type?
		generator = generators[node.type]
		throw new Error "No generator for #{node.type}" unless generator?
		generator.call this, node

	write: (text) ->
		@text += text

	writeTerminatedLine: (text) ->
		@writeAsTerminatedLine => @write text
	
	indent: ->
		@write (new Array(@blockDepth + 1)).join("\t")

	writeAsTerminatedLine: (body) ->
		@indent()
		body()
		@write ";\n"

	writeLine: (body) ->
		@indent()
		body()
		@write "\n"

	declare: (identifier, node) ->
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
			nearestScope.push identifier.value

	commaSeparated: (nodes) ->
		for node, index in nodes
			@generateNode node
			@write ", " if index < nodes.length - 1

	declareVariablesIn: (scope) ->
		if scope.length isnt 0
			@writeTerminatedLine "var #{scope.join(", ")}"

	inBlock: (body) ->
		@blockDepth += 1
		@write "{\n"
		body.call this
		@write "}"
		@blockDepth -= 1

exports.generate = (root) ->
	(new Generator).generate(root)

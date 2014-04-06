genCommaSeparatedCode = (forms) ->
	forms.map((form) -> form.genCode()).join(", ")

class exports.Module
	constructor: (@contents) ->

	genCode: ->
		modulePaths	= []
		moduleBindings	= []
		for expression in @contents.expressions
			if expression instanceof exports.TopLevelRequire
				modulePaths.push expression.path
				moduleBindings.push expression.binding
				
		return """
		define([#{genCommaSeparatedCode modulePaths}],
			function(#{genCommaSeparatedCode moduleBindings}) {
				var __heson_exports = {};
				#{@contents.genCode()}
				return __heson_exports;
			}
		);
		"""

class exports.TopLevelRequire
	constructor: (@path, @binding) ->

	genCode: ->
		""

class exports.Require
	constructor: (@path, @binding) ->

	genCode: ->
		"#{@binding.genCode()} = require(#{@path.genCode()})"

class exports.Identifier
	constructor: (@name) ->

	genCode: ->
		@name

class exports.FunctionCall
	constructor: (@functionName, @params) ->

	genCode: ->
		"#{@functionName.genCode()}(#{@params.genCode()})"

class exports.ExpressionList
	constructor: ->
		@params = []

	push: (param) ->
		@params.push param

	genCode: ->
		genCommaSeparatedCode @params

class exports.String
	constructor: (@contents) ->

	genCode: ->
		"\"#{@contents}\""

class exports.Number
	constructor: (@number) ->

	genCode: ->
		@number

class exports.TopLevelAssignment
	constructor: (@identifier, @value) ->

	genCode: ->
		"(__heson_exports[\"#{@identifier.genCode()}\"] = #{@identifier.genCode()} = #{@value.genCode()})"

class exports.Assignment
	constructor: (@identifier, @value) ->

	genCode: ->
		"(#{@identifier.genCode()} = #{@value.genCode()})"

class exports.FunctionDeclaration
	constructor: (@params, @body) ->

	genCode: ->
		"""
		function(#{@params.genCode()}) {
			#{@body.genCode()}
		}
		"""

class exports.IdentifierList
	constructor: ->
		@params = []

	push: (param) ->
		@params.push param

	genCode: ->
		genCommaSeparatedCode @params

class exports.Block
	constructor: ->
		@expressions = []

	push: (expression) ->
		@expressions.push expression

	genCode: ->
		s = ""
		for expression in @expressions
			code = expression.genCode()
			s += "#{code};\n" if code.trim().length > 0
		return s

class exports.ObjectLiteral
	constructor: (@properties) ->

	genCode: ->
		s = "{"
		for {property, value}, index in @properties
			s += "#{property.genCode()}: #{value.genCode()}"
			s += ", " if index < @properties.length - 1
		s += "}"
		return s

class exports.BinaryOperation
	constructor: (@lhs, @op, @rhs) ->

	genCode: ->
		"(#{@lhs.genCode()} #{@op} #{@rhs.genCode()})"

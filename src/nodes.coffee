class exports.FunctionCall
	constructor: (@functionName, @params) ->

	genCode: ->
		"#{@functionName}(#{@params.genCode()})"

class exports.FunctionCallParamList
	constructor: ->
		@params = []

	push: (param) ->
		@params.push param

	genCode: ->
		s = ""
		for param, index in @params
			s += param.genCode()
			s += ", " if index < @params.length - 1
		return s

class exports.Number
	constructor: (@number) ->

	genCode: ->
		@number

class exports.Assignment
	constructor: (@identifier, @value) ->

	genCode: ->
		"(#{@identifier} = #{@value.genCode()})"

class exports.FunctionDeclaration
	constructor: (@body) ->
	genCode: ->
		"function(){#{@body.genCode()}}"

class exports.Block
	constructor: ->
		@expressions = []

	push: (expression) ->
		@expressions.push expression

	genCode: ->
		s = ""
		for expression in @expressions
			s += "#{expression.genCode()};\n"
		return s

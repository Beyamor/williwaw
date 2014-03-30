class exports.Identifier
	constructor: (@name) ->

	genCode: ->
		@name

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
		@params.map((param) -> param.genCode()).join(", ")

class exports.Number
	constructor: (@number) ->

	genCode: ->
		@number

class exports.Assignment
	constructor: (@identifier, @value) ->

	genCode: ->
		"(#{@identifier} = #{@value.genCode()})"

class exports.FunctionDeclaration
	constructor: (@params, @body) ->

	genCode: ->
		"function(#{@params.genCode()}){#{@body.genCode()}}"

class exports.FunctionDeclarationParamList
	constructor: ->
		@params = []

	push: (param) ->
		@params.push param

	genCode: ->
		@params.join(", ")

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

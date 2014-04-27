nodes = require "./nodes"

class ParseError extends Error
	constructor: (message) ->
		super()
		@name = "ParseError"
		@message = message

class TokenStream
	constructor: (@tokens, @index=0) ->

	peek: ->
		@tokens[@index]

	pop: ->
		token = @tokens[@index]
		++@index
		return token

	isAtEnd: ->
		@index >= @tokens.length

	setMark: ->
		@marks or= []
		@marks.push @index

	restoreMark: ->
		@index = @marks.pop()

	dropMark: ->
		@marks.pop()

binaryOp = (op) ->
	(lhs) ->
		rhs = @parse parselet: "expression", args: [@getPredence op]
		return new nodes.BinaryOperation op, lhs, rhs


language =
	precedences:
		ordering: [
			"equality"
			"comparison"
			"plusminus"
			"multiplydivide"
			"propertyAccess"
			"call"
		]
	
		mapping:
			"(":	"call"
			".":	"propertyAccess"
			"+":	"plusminus"
			"-":	"plusminus"
			"*":	"multiplydivide"
			"/":	"multiplydivide"
			"==":	"equality"
			"!=":	"equality"
			">":	"comparison"
			">=":	"comparison"
			"<":	"comparison"
			"<=":	"comparison"

	prefixParselets:
		true: ->
			@expectText "true"
			return new nodes.True

		false: ->
			@expectText "false"
			return new nodes.False

		identifier: ->
			name = @read "identifier"
			return new nodes.Identifier name

		string: ->
			string = @read "string"
			return new nodes.String string.substring(1, string.length - 1)

		number: ->
			number = @read "number"
			return new nodes.Number number

		"(": ->
			@in "(", ")", =>
				@parse "expression"

	infixParselets:
		"(": (f) ->
			args = new nodes.ExpressionList()
			@until ")", =>
				args.push @parse "expression"
				@expect "," if @tokens.peek().type != ")"
			@expect ")"
			return new nodes.FunctionCall f, args

		".": (lhs) ->
			rhs = @parse "identifier"
			return new nodes.PropertyAccess lhs, rhs

		"+": binaryOp "+"
		"-": binaryOp "-"
		"*": binaryOp "*"
		"/": binaryOp "/"
		"==": binaryOp "=="
		"!=": binaryOp "!="
		">": binaryOp ">"
		">=": binaryOp ">="
		"<": binaryOp "<"
		"<=": binaryOp "<="
			
	statementParselets:
		precedenceExpression: (minPrecedence=0) ->
			token	= @tokens.peek()
			prefix	= language.prefixParselets[token.type]
			throw new ParseError "Could not find a prefix for #{token}" unless prefix?

			left = prefix.call this
			while minPrecedence < @nextPredence()
				token	= @tokens.pop()
				infix	= language.infixParselets[token.type]
				left	= infix.call this, left
			return left

		functionDeclaration: ->
			paramList = new nodes.IdentifierList
			@in "(", ")", =>
				@until ")", =>
					while @tokens.peek().type != ")"
						paramList.push @parse "identifier"
						@expect "," unless @tokens.peek().type is ")"
			@expect "->"
			body = @parse [
				"expression"
				"indentedBlock"
			]
			return new nodes.FunctionDeclaration paramList, body

		objectLiteral: ->
			@indented =>
				properties = []
				@until "dedent", =>
					property = @parse [
						"identifier"
						"string"
					]
					@expect ":"
					value = @parse "expression"
					@expect "newline"
					properties.push property: property, value: value
				return new nodes.ObjectLiteral properties

		expression: (minPrecedence=0) ->
			@parse [
				"objectLiteral"
				"functionDeclaration"
				parselet: "precedenceExpression", args: [minPrecedence]
			]

		indentedBlock: ->
			@indented =>
				block = new nodes.Block
				while @tokens.peek().type isnt "dedent"
					statement = @parse "statement"
					block.push statement
				return block
			
		topLevelRequire: ->
			@expectText "require"
			path = @parse "string"
			@expectText "as"
			identifier = @parse "identifier"
			return new nodes.TopLevelRequire path, identifier

		topLevelAssignment: ->
			identifier = @parse "identifier"
			@expect "="
			value = @parse "expression"
			return new nodes.TopLevelAssignment identifier, value

		topLevelStatements: ->
			block = new nodes.Block
			until @tokens.isAtEnd()
				@skippingNewlines =>
					statement = @parse [
						"topLevelRequire"
						"topLevelAssignment"
						"expression"
					]
					@expect "newline"
					block.push statement
			return block

		assignment: ->
			identifier = @parse "identifier"
			@expect "="
			value = @parse "expression"
			return new nodes.Assignment identifier, value

		require: ->
			@expectText "require"
			path = @parse "string"
			@expectText "as"
			identifier = @parse "identifier"
			return new nodes.Require path, identifier

		statement: ->
			thing = @parse [
				"require"
				"assignment"
				"expression"
			]
			@expect "newline"
			return thing

		module: (tokens) ->
			block = @parse "topLevelStatements"
			return new nodes.Module block

class Parser
	parseItUp: (tokens) ->
		@tokens = new TokenStream tokens
		@parse "module"

	getPredence: (type) ->
		precedence = language.precedences.mapping[type]
		if precedence?
			return language.precedences.ordering.indexOf(precedence) + 1
		else
			return 0

	nextPredence: ->
		@getPredence @tokens.peek().type
		
	parseOne: (parselet) ->
		@tokens.setMark()
		try
			{parselet, args} =
				if parselet.args?
					parselet
				else
					parselet: parselet, args: []

			if language.statementParselets[parselet]?
				result = language.statementParselets[parselet].apply this, args
			else if language.prefixParselets[parselet]?
				result = language.prefixParselets[parselet].apply this, args
			else
				throw new Error "No parselet for #{parselet}"
			@tokens.dropMark()
			return result
		catch e
			@tokens.restoreMark()
			throw e

	parseAny: (parselets) ->
		while true
			parselet = parselets.shift()
			try
				return @parse parselet
			catch e
				throw e unless parselets.length > 0 and e instanceof ParseError

	parse: (what) ->
		if Array.isArray what
			@parseAny what
		else
			@parseOne what

	expect: (expectedTypes...) ->
		for expectedType in expectedTypes
			token = @tokens.pop()
			unless token.type is expectedType
				throw new ParseError "Expected token of type #{expectedType} and got #{token}"
		return token

	expectText: (expectedTexts...) ->
		for expectedText in expectedTexts
			token = @tokens.pop()
			unless token.text is expectedText
				throw new ParseError "Expected token with text #{expectedText} and got #{token}"
		return token

	read: (what) ->
		return @expect(what).text

	skipNewlines: ->
		while not @tokens.isAtEnd() and @tokens.peek().type is "newline"
			@tokens.pop()

	skippingNewlines: (body) ->
		@skipNewlines()
		body()
		@skipNewlines()

	indented: (body) ->
		@expect "newline", "indent"
		result = body()
		@expect "dedent"
		return result

	until: (tokenType, body) ->
		while @tokens.peek().type isnt tokenType
			body()

	in: (opening, closing, body) ->
		@expect opening
		result = body()
		@expect closing
		return result

exports.parse = (tokens) ->
	(new Parser).parseItUp tokens

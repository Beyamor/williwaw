class Node
	constructor: (@type, @children) ->
		child.parent = this for child in @children
		if @children.length isnt 0
			@children[0].isFirstChild = true
			@children[@children.length-1].isLastChild = true

	getDepth: ->
		if @parent?
			@parent.getDepth() + 1
		else
			0

	toString: (depth=0)->
		s = ""
		if @isFirstChild
			s += " "
		s += "(#{@type}"
		for child in @children
			s += child.toString(depth + @type.length + 2)
		s += ")"
		unless @isLastChild
			s += "\n" + new Array(depth+1).join(" ")
		return s

class LeafNode extends Node
	constructor: (@type, @value) ->

	toString: (depth=0) ->
		s = ""
		if @isFirstChild
			s += " "
		s += @value
		unless @isLastChild
			s += "\n" + new Array(depth+1).join(" ")
		return s

class ParseError extends Error
	constructor: (message) ->
		super()
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
		return new Node op, [lhs, rhs]

language =
	precedences:
		ordering: [
			"equality"
			"comparison"
			"plusminus"
			"multiplydivide"
			"exponentiation"
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
			"**":	"exponentiation"

	prefixParselets:
		true: ->
			@expectText "true"
			return new LeafNode "boolean", "true"

		false: ->
			@expectText "false"
			return new LeafNode "boolean", "false"

		identifier: ->
			name = @read "identifier"
			return new LeafNode "identifier", name

		string: ->
			string = @read "string"
			return new LeafNode "string", string

		number: ->
			number = @read "number"
			return new LeafNode "number", number

		"(": ->
			@in "(", ")", =>
				@parse "expression"

	infixParselets:
		"(": (f) ->
			args = []
			@until ")", =>
				args.push @parse "expression"
				@expect "," if @tokens.peek().type != ")"
			@expect ")"
			return new Node "call", [f].concat(args)

		".": (lhs) ->
			rhs = @parse "identifier"
			return new Node ".", [lhs, rhs]

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

		"**": (lhs) ->
			rhs = @parse "expression", @getPredence "**"
			return new Node "**", [lhs, rhs]
			
	statementParselets:
		precedenceExpression: (minPrecedence=0) ->
			token	= @tokens.peek()
			prefix	= language.prefixParselets[token.type]
			@failOn token unless prefix?

			left = prefix.call this
			while minPrecedence < @nextPredence()
				token	= @tokens.pop()
				infix	= language.infixParselets[token.type]
				left	= infix.call this, left
			return left

		functionDeclaration: ->
			params = []
			if @tokens.peek().type is "("
				@in "(", ")", =>
					@until ")", =>
						while @tokens.peek().type != ")"
							params.push @parse "identifier"
							@expect "," unless @tokens.peek().type is ")"
			params = new Node "params", params
			@expect "->"
			body = @parse [
				"expression"
				"indentedBlock"
			]
			return new Node "fn", [params, body]

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
					properties.push property, value
				return new Node "object", properties

		expression: (minPrecedence=0) ->
			@parse [
				"objectLiteral"
				"functionDeclaration"
				parselet: "precedenceExpression", args: [minPrecedence]
			]

		indentedBlock: ->
			@indented =>
				block = []
				while @tokens.peek().type isnt "dedent"
					statement = @parse "statement"
					block.push statement
				return new Node "do", block
			
		topLevelRequire: ->
			@expectText "require"
			path = @parse "string"
			@expectText "as"
			identifier = @parse "identifier"
			return new Node "require", [path, identifier]

		topLevelAssignment: ->
			identifier = @parse "identifier"
			@expect "="
			value = @parse "expression"
			return new Node "=", [identifier, value]

		topLevelStatements: ->
			block = []
			@until "eof", =>
				@skippingNewlines =>
					statement = @parse [
						"topLevelRequire"
						"topLevelAssignment"
						"expression"
					]
					@expect "newline"
					block.push statement
			@expect "eof"
			return new Node "do", block

		assignment: ->
			identifier = @parse "identifier"
			@expect "="
			value = @parse "expression"
			return new Node "=", [identifier, value]

		require: ->
			@expectText "require"
			path = @parse "string"
			@expectText "as"
			identifier = @parse "identifier"
			return new Node "require", [path, identifier]

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
			return new Node "module", [block]

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
			@failOn token unless token? and token.type is expectedType
		return token

	expectText: (expectedTexts...) ->
		for expectedText in expectedTexts
			token = @tokens.pop()
			@failOn token unless token? and token.text is expectedText
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

	failOn: (token) ->
		throw new ParseError "Error on line #{token.line}: Unexpected '#{token}'"

exports.parse = (tokens) ->
	(new Parser).parseItUp tokens

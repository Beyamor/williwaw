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

language =
	precedences:
		ordering: [
			"propertyAccess"
			"call"
		]
	
		mapping:
			"(":	"call"
			".":	"propertyAccess"

	prefixParselets:
		identifier: ->
			name = @read "identifier"
			return new nodes.Identifier name

		string: ->
			string = @read "string"
			return new nodes.String string.substring(1, string.length - 1)

	infixParselets:
		"(": (f) ->
			args = new nodes.ExpressionList()
			while @tokens.peek().type != ")"
				args.push @tryParsing "expression"
				@expect "," if @tokens.peek().type != ")"
			@expect ")"
			return new nodes.FunctionCall f, args

		".": (lhs) ->
			rhs = @tryParsing "identifier"
			return new nodes.PropertyAccess lhs, rhs

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
			@expect "("
			paramList = new nodes.IdentifierList
			while @tokens.peek().type != ")"
				paramList.push @tryParsing "identifier"
				@expect "," unless @tokens.peek().type is ")"
			@expect ")"
			@expect "->"
			body = @tryParsing [
				"expression"
				"indentedBlock"
			]
			return new nodes.FunctionDeclaration paramList, body

		expression: (minPrecedence=0) ->
			@tryParsing [
				"functionDeclaration"
				"precedenceExpression"
			]

		indentedBlock: ->
			@expect "newline"
			@expect "indent"
			block = new nodes.Block
			while @tokens.peek().type isnt "dedent"
				statement = @tryParsing "statement"
				block.push statement
			@expect "dedent"
			return block
			
		topLevelRequire: ->
			@expectText "require"
			path = @tryParsing "string"
			@expectText "as"
			identifier = @tryParsing "identifier"
			return new nodes.TopLevelRequire path, identifier

		topLevelAssignment: ->
			identifier = @tryParsing "identifier"
			@expect "="
			value = @tryParsing "expression"
			return new nodes.TopLevelAssignment identifier, value

		topLevelStatements: ->
			block = new nodes.Block
			until @tokens.isAtEnd()
				@skippingNewlines =>
					statement = @tryParsing [
						"topLevelRequire"
						"topLevelAssignment"
						"expression"
					]
					@expect "newline"
					block.push statement
			return block

		assignment: ->
			identifier = @tryParsing "identifier"
			@expect "="
			value = @tryParsing "expression"
			return new nodes.Assignment identifier, value

		require: ->
			@expectText "require"
			path = @tryParsing "string"
			@expectText "as"
			identifier = @tryParsing "identifier"
			return new nodes.Require path, identifier

		statement: ->
			thing = @tryParsing [
				"require"
				"assignment"
				"expression"
			]
			@expect "newline"
			return thing

		module: (tokens) ->
			block = @tryParsing "topLevelStatements"
			return new nodes.Module block

class exports.Parser
	parse: (tokens) ->
		@tokens = new TokenStream tokens
		@tryParsing "module"

	nextPredence: ->
		nextToken	= @tokens.peek().type
		precedence	= language.precedences.mapping[nextToken]
		if precedence?
			return language.precedences.ordering.indexOf(precedence) + 1
		else
			return 0

	tryParsingOne: (parse) ->
		@tokens.setMark()
		try
			if language.statementParselets[parse]?
				result = language.statementParselets[parse].call this
			else if language.prefixParselets[parse]?
				result = language.prefixParselets[parse].call this
			else
				throw new Error "No parselet for #{parse}"
			@tokens.dropMark()
			return result
		catch e
			@tokens.restoreMark()
			throw e

	tryParsingAny: (parses) ->
		while true
			parse = parses.shift()
			try
				return @tryParsing parse
			catch e
				throw e unless parses.length > 0 and e instanceof ParseError

	tryParsing: (what) ->
		if Array.isArray what
			@tryParsingAny what
		else
			@tryParsingOne what

	expect: (expectedType) ->
		token = @tokens.pop()
		unless token.type is expectedType
			throw new ParseError "Expected token of type #{expectedType} and got #{token}"
		return token

	expectText: (expectedText) ->
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

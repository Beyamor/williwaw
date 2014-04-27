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
			"call"
		]
	
		mapping:
			"(":	"call"

	prefixes:
		IDENTIFIER: (token) ->
			return new nodes.Identifier token.text

		STRING: (token) ->
			return new nodes.String token.text.substring(1, token.text.substring.length - 1)

	infixes:
		"(": (f) ->
			args = new nodes.ExpressionList()
			while @tokens.peek().type != ")"
				args.push @tryParsingExpression()
				@expect "," if @tokens.peek().type != ")"
			@expect ")"
			return new nodes.FunctionCall f, args

	parselets:
		identifier: ->
			new nodes.Identifier @read "IDENTIFIER"

		string: ->
			token = @expect "STRING"
			return new nodes.String token.text.substring(1, token.text.substring.length - 1)

		expression: (minPrecedence=0) ->
			token	= @tokens.pop()
			prefix	= language.prefixes[token.type]
			throw new ParseError "Could not find a prefix for #{token}" unless prefix?

			left = prefix.call this, token
			while minPrecedence < @nextPredence()
				token	= @tokens.pop()
				infix	= language.infixes[token.type]
				left	= infix.call this, left, token
			return left

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
					@expect "NEWLINE"
					block.push statement
			return block

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
			result = language.parselets[parse].call this
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
				throw e if parses.length is 0 or not e instanceof ParseError

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
		while not @tokens.isAtEnd() and @tokens.peek().type is "NEWLINE"
			@tokens.pop()

	skippingNewlines: (body) ->
		@skipNewlines()
		body()
		@skipNewlines()

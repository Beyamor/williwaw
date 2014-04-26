nodes = require "./nodes"

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

	clone: ->
		new TokenStream @tokens, @index

	moveTo: (other) ->
		@index = other.index

	expect: (what) ->
		token = @pop()
		meetsExpectation =
			if what.text?
				token.text is what.text
			else
				token.type is what
		unless meetsExpectation
			throw "Expected #{what.text or what} and got #{token}"
		return token

	read: (what) ->
		return @expect(what).text

	skipNewlines: ->
		while not @isAtEnd() and @peek().type is "NEWLINE"
			@pop()

	skippingNewlines: (body) ->
		@skipNewlines()
		body()
		@skipNewlines()

language =
	identifier: (tokens) ->
		identifier = tokens.read "IDENTIFIER"
		return new nodes.Identifier identifier

	string: (tokens) ->
		value = tokens.read "STRING"
		return new nodes.String value.substring 1, value.length - 1

	expression: (tokens) ->
		@tryParsing [language.identifier], tokens

	topLevelRequire: (tokens) ->
		tokens.expect text: "require"
		path = @tryParsing language.string, tokens
		tokens.expect text: "as"
		identifier = @tryParsing language.identifier, tokens
		return new nodes.TopLevelRequire path, identifier

	topLevelStatements: (tokens) ->
		block = new nodes.Block
		until tokens.isAtEnd()
			tokens.skippingNewlines =>
				statement = @tryParsing [language.topLevelRequire, language.expression], tokens
				tokens.expect "NEWLINE"
				block.push statement
		return block

	module: (tokens) ->
		block = @tryParsing language.topLevelStatements, tokens
		return new nodes.Module block

class exports.Parser
	parse: (tokens) ->
		@tryParsing language.module, new TokenStream tokens

	tryParsingOne: (parse, tokens) ->
		tokensClone = tokens.clone()
		result = parse.call this, tokensClone
		tokens.moveTo tokensClone
		return result

	tryParsingAny: (parses, tokens) ->
		while true
			parse = parses.shift()
			try
				return @tryParsing parse, tokens
			catch e
				throw e if parses.length is 0

	tryParsing: (what, tokens) ->
		if Array.isArray what
			@tryParsingAny what, tokens
		else
			@tryParsingOne what, tokens

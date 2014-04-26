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
		@tryParsing tokens, [
			language.identifier
			language.string
		]

	topLevelRequire: (tokens) ->
		tokens.expect text: "require"
		path = @tryParsing tokens, language.string
		tokens.expect text: "as"
		identifier = @tryParsing tokens, language.identifier
		return new nodes.TopLevelRequire path, identifier

	topLevelAssignment: (tokens) ->
		identifier = @tryParsing tokens, language.identifier
		tokens.expect "="
		value = @tryParsing tokens, language.expression
		return new nodes.TopLevelAssignment identifier, value

	topLevelStatements: (tokens) ->
		block = new nodes.Block
		until tokens.isAtEnd()
			tokens.skippingNewlines =>
				statement = @tryParsing tokens, [
					language.topLevelRequire
					language.topLevelAssignment
					language.expression
				]
				tokens.expect "NEWLINE"
				block.push statement
		return block

	module: (tokens) ->
		block = @tryParsing tokens, language.topLevelStatements
		return new nodes.Module block

class exports.Parser
	parse: (tokens) ->
		@tryParsing new TokenStream(tokens), language.module

	tryParsingOne: (tokens, parse) ->
		tokensClone = tokens.clone()
		result = parse.call this, tokensClone
		tokens.moveTo tokensClone
		return result

	tryParsingAny: (tokens, parses) ->
		while true
			parse = parses.shift()
			try
				return @tryParsing tokens, parse
			catch e
				console.log "failed parse b/c #{e}"
				throw e if parses.length is 0

	tryParsing: (tokens, what) ->
		if Array.isArray what
			@tryParsingAny tokens, what
		else
			@tryParsingOne tokens, what

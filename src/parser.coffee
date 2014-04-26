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

	setMark: ->
		@marks or= []
		@marks.push @index

	restoreMark: ->
		@index = @marks.pop()

	dropMark: ->
		@marks.pop()

language =
	identifier: ->
		identifier = @read "IDENTIFIER"
		return new nodes.Identifier identifier

	string: ->
		value = @read "STRING"
		return new nodes.String value.substring 1, value.length - 1

	expression: ->
		@tryParsing [
			language.identifier
			language.string
		]

	topLevelRequire: ->
		@expect text: "require"
		path = @tryParsing language.string
		@expect text: "as"
		identifier = @tryParsing language.identifier
		return new nodes.TopLevelRequire path, identifier

	topLevelAssignment: ->
		identifier = @tryParsing language.identifier
		@expect "="
		value = @tryParsing language.expression
		return new nodes.TopLevelAssignment identifier, value

	topLevelStatements: ->
		block = new nodes.Block
		until @tokens.isAtEnd()
			@skippingNewlines =>
				statement = @tryParsing [
					language.topLevelRequire
					language.topLevelAssignment
					language.expression
				]
				@expect "NEWLINE"
				block.push statement
		return block

	module: (tokens) ->
		block = @tryParsing language.topLevelStatements
		return new nodes.Module block

class exports.Parser
	parse: (tokens) ->
		@tokens = new TokenStream tokens
		@tryParsing language.module

	tryParsingOne: (parse) ->
		@tokens.setMark()
		try
			result = parse.call this
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
				console.log "failed parse b/c #{e}"
				throw e if parses.length is 0

	tryParsing: (what) ->
		if Array.isArray what
			@tryParsingAny what
		else
			@tryParsingOne what

	expect: (what) ->
		token = @tokens.pop()
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
		while not @tokens.isAtEnd() and @tokens.peek().type is "NEWLINE"
			@tokens.pop()

	skippingNewlines: (body) ->
		@skipNewlines()
		body()
		@skipNewlines()



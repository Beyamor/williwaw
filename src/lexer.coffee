KEYWORDS =
	require:	"REQUIRE"
	as:		"AS"

class Lexer
	constructor: ->
		@o /^	*/m, (indents) =>
			indentationLevel = indents.length
			if indentationLevel > @indentStack[0]
				@indentStack.unshift indentationLevel
				@push "indent"

			while indentationLevel < @indentStack[0]
				@push "dedent"
				@indentStack.shift()

		@o /[ 	]+/, =>
			@consume()

		@o /".*"/, (contents) =>
			@consume()
			@push "string", contents

		@o /\n/, =>
			@consume()
			@push "newline"

		@o /\*\*=|\+=|-=|\*=|\/=|->|\(|\)|\||\+|-|\*\*|\*|\/|==|!=|>|>=|<|<=|=|{|}|\.|:|,/, (symbol) =>
			@consume()
			@push symbol

		@o /[0-9]+(\.[0-9]+)?/, (number) =>
			@consume()
			@push "number", number

		@o /[a-zA-Z_][a-zA-Z0-9_]*/, (name) =>
			@consume()
			@push "identifier", name

	o: (pattern, handler) ->
		flags = "g"
		flags += "m" if pattern.multiline
		pattern = new RegExp pattern.source, flags
		@rules or= []
		@rules.push [pattern, handler]

	push: (type, text) ->
		@tokens.push
			type: type
			text: text
			toString: -> "#{text or type}"
			line: @line

	lex: (text) ->
		@indentStack = [0]
		@tokens = []
		@line = 1

		startIndex = 0
		while startIndex < text.length
			@consumed = false
			for [pattern, handle] in @rules
				pattern.lastIndex = startIndex
				match = pattern.exec text
				if match? and match.index is startIndex
					matchText = match[0]
					handle matchText
					@line += (matchText.match(/\n/g) || []).length
					if @consumed
						startIndex += matchText.length
						break

			throw new Error "Can't tokenize character '#{text[startIndex]}'" unless @consumed

		while @indentStack[0] > 0
				@push "dedent"
				@indentStack.shift()
			@push "eof"

		return @tokens

	consume: ->
		@consumed = true

exports.lex = (text) ->
	(new Lexer).lex text

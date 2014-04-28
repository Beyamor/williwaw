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

		@o /".*"/, (contents) =>
			@push "string", contents

		@o /\n/, =>
			@push "newline"

		@o /->|\(|\)|\||\+|-|\*\*|\*|\/|==|!=|>|>=|<|<=|=|{|}|\.|:/, (symbol) =>
			@push symbol

		@o /[0-9]+(\.[0-9]+)?/, (number) =>
			@push "number", number

		@o /[a-zA-Z][a-zA-Z0-9_]*/, (name) =>
			@push "identifier", name

		@o /$/, =>
			while @indentStack[0] > 0
				@push "dedent"
				@indentStack.shift()
			@push "eof"

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
			matched = false
			for [pattern, handle] in @rules
				pattern.lastIndex = startIndex
				match = pattern.exec text
				if match? and match.index is startIndex
					matched = true
					matchText = match[0]
					handle matchText
					@line += (matchText.match(/\n/g) || []).length
					startIndex += matchText.length

			unless matched
				throw new Error "Can't tokenize character '#{text[startIndex]}'"

		return @tokens

exports.lex = (text) ->
	(new Lexer).lex text

KEYWORDS =
	require:	"REQUIRE"
	as:		"AS"

class exports.Lexer
	constructor: ->
		@o /^	*/m, (indents) =>
			indentationLevel = indents.length
			if indentationLevel > @indentStack[0]
				@indentStack.unshift indentationLevel
				@push "INDENT"

			while indentationLevel < @indentStack[0]
				@push "DEDENT"
				@indentStack.shift()

		@o /[ 	]+/, =>

		@o /".*"/, (contents) =>
			@push "STRING", contents

		@o /\n/, =>
			@push "NEWLINE"

		@o /->|\(|\)|\||\+|-|\*|\/|==|!=|>|>=|<|<=|=|{|}|\./, (symbol) =>
			@push symbol

		@o /[a-zA-Z][a-zA-Z0-9_]*/, (name) =>
			@push "IDENTIFIER", name

		@o /$/, =>
			while @indentStack[0] > 0
				@push "DEDENT"
				@indentStack.shift()

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

	lex: (text) ->
		@indentStack = [0]
		@tokens = []

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
					startIndex += matchText.length

			unless matched
				throw new Error "Can't tokenize character '#{text[startIndex]}'"

		return @tokens

assert = require "assert"
{lex} = require "../js/lexer.js"

assert.lex = (text, expectedTokens) ->
	actualTokens = lex text
	assert.equal expectedTokens.length + 1, actualTokens.length
	for expectedToken, index in expectedTokens
		actualToken = actualTokens[index]
		if actualToken.text?
			assert.equal expectedToken, actualToken.text
		else
			assert.equal expectedToken, actualToken.type
	assert.equal "eof", actualTokens[actualTokens.length-1]

describe "the lexer", ->
	it "should lex numbers", ->
		assert.lex "1", ["1"]
		assert.lex "1.0", ["1.0"]

	it "should lex identifiers", ->
		assert.lex "derp", ["derp"]
		assert.lex "derp_", ["derp_"]
		assert.lex "_derp", ["_derp"]
		assert.lex "derp0", ["derp0"]

	it "should lex strings", ->
		assert.lex '"derp"', ['"derp"']

	it "should lex symbols", ->
		assert.lex "*", ["*"]
		assert.lex "**", ["**"]
		assert.lex "*=", ["*="]
		assert.lex "**=", ["**="]
		assert.lex "=", ["="]
		assert.lex "==", ["=="]

	it "should lex expressions", ->
		assert.lex "1 + 2", ["1", "+", "2"]
		assert.lex "1+2", ["1", "+", "2"]

	it "should lex function declarations", ->
		assert.lex "(x) -> x", ["(", "x", ")", "->", "x"]

	it "should lex blocks", ->
		s =
			"if (x)\n" +
			"	x\n"
		assert.lex s, ["if", "(", "x", ")", "newline", "indent", "x", "newline", "dedent"]

	it "should sequential blocks", ->
		s =
			"if (x)\n" +
			"	x\n" +
			"else\n" +
			"	y\n"
		assert.lex s, ["if", "(", "x", ")", "newline",
				"indent", "x", "newline", "dedent",
				"else", "newline",
				"indent", "y", "newline", "dedent"]

	it "should reject unlexable symbols", ->
		assert.throws (-> lex "&something"), Error

	it "should tokenize commas", ->
		assert.lex ",", [","]

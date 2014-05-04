assert = require "assert"
{lex} = require "../js/lexer.js"
{parse} = require "../js/parser.js"

assert.parse = (text, expectedTopLevelNodes) ->
	tokens = lex text
	module = parse tokens
	assert.equal "module", module.type
	assert.equal 1, module.children.length
	moduleDo = module.children[0]
	assert.equal "do", moduleDo.type
	assertNodeEquals = (expectedNode, actualNode) ->
		if Array.isArray expectedNode
			[expectedType, expectedChildren...] = expectedNode
			assert.equal expectedType, actualNode.type
			assert actualNode.children
			assert.equal (expectedNode.length - 1), actualNode.children.length
			for expectedChild, index in expectedChildren
				assertNodeEquals expectedChild, actualNode.children[index]
		else
			if actualNode.value?
				assert.equal expectedNode, actualNode.value
			else
				assert.equal expectedNode, actualNode.type
	for expectedTopLevelNode, index in expectedTopLevelNodes
		assertNodeEquals expectedTopLevelNode, moduleDo.children[index]

describe "the parser", ->
	it "should parse single tokens", ->
		assert.parse "derp", ["derp"]
		assert.parse '"derp"', ['"derp"']
		assert.parse "1", ["1"]

	it "should parse infix operators", ->
		assert.parse "1 + 2", [["+", "1", "2"]]
		assert.parse "1 ** 2", [["**", "1", "2"]]
		assert.parse "1 == 2", [["==", "1", "2"]]
		assert.parse "1 > 2", [[">", "1", "2"]]

	it "should parse assignment", ->
		assert.parse "a = 1", [["assign", "a", "1"]]

	it "should parse operator assignment", ->
		assert.parse "a += 1", [["assign", "a",
						["+", "a", "1"]]]
		assert.parse "a **= 1", [["assign", "a",
						["**", "a", "1"]]]

	it "should parse function calls", ->
		assert.parse "f()", [["call", "f"]]
		assert.parse "f(1)", [["call", "f", "1"]]
		assert.parse "f(1, 2)", [["call", "f", "1", "2"]]
		assert.parse "f(1 + 2)", [["call", "f",
						["+", "1", "2"]]]

	it "should parse single line function declarations", ->
		assert.parse "() -> a", [["fn", ["params"],
						["do", "a"]]]
		assert.parse "-> a", [["fn", ["params"],
						["do", "a"]]]
		assert.parse "(a) -> a", [["fn", ["params", "a"],
						["do", "a"]]]
		assert.parse "(a, b) -> a", [["fn", ["params", "a", "b"],
						["do", "a"]]]

	it "should parse multi line function declarations", ->
		bodyText =
			"->\n" +
			"	a\n" +
			"	b + 2\n"
		expectedBody = ["do", "a", ["+", "b", "2"]]
		assert.parse "() #{bodyText}", [["fn", ["params"], expectedBody]]
		assert.parse "#{bodyText}", [["fn", ["params"], expectedBody]]
		assert.parse "(a) #{bodyText}", [["fn", ["params", "a"], expectedBody]]
		assert.parse "(a, b) #{bodyText}", [["fn", ["params", "a", "b"], expectedBody]]

	it "should parse a single if", ->
		expectedBody =
			[["if", "foo",
				["do", "bar"]]]
		text =
			"if foo\n" +
			"	bar\n"
		assert.parse text, expectedBody
		text =
			"if foo\n" +
			"	\n" +
			"	bar\n"
		assert.parse text, expectedBody

	it "should parse if-else", ->
		expectedBody =
			[["if", "foo",
				["do", "bar"]
				["do", "baz"]]]
		text =
			"if foo\n" +
			"	bar\n" +
			"else\n" +
			"	baz\n"
		assert.parse text, expectedBody
		text =
			"if foo\n" +
			"	bar\n" +
			"	\n" +
			"else\n" +
			"	baz\n" +
			"	\n"

	it "should parse nested functions", ->
		text =
			"(a) ->\n" +
			"	(b) ->\n" +
			"		a + b\n"
		assert.parse text, [["fn", ["params", "a"],
					["do", ["fn", ["params", "b"],
						["do", ["+", "a", "b"]]]]]]

	it "should parse nested ifs", ->
		text =
			"if a\n" +
			"	if b\n" +
			"		a + b\n" +
			"	else\n" +
			"		a - b\n" +
			"else\n" +
			"	a * b\n"
		assert.parse text, [["if", "a"
					["do", ["if", "b",
							["do", ["+", "a", "b"]],
							["do", ["-", "a", "b"]]]],
					["do", ["*", "a", "b"]]]]

	it "should parse requires", ->
		assert.parse 'require "whatever" as whatever', [["require", '"whatever"', "whatever"]]

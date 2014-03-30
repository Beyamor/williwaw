%%

\s+							/* skip whitespace */
[0-9]("."[0-9]+)?\b					return "NUMBER";
"function"						return "FUNCTION";
[a-zA-Z][a-zA-Z0-9_]*("."[a-zA-Z][a-zA-Z0-9_]*)*	return "IDENT";
"("							return "(";
")"							return ")";
"{"							return "{";
"}"							return "}";
"="							return "=";
","							return ",";
<<EOF>>							return "EOF";

![Ultra Tiny Compiler](http://medv.io/assets/ultra-tiny-compiler.png)

This is Ultra Tiny Compiler for any C-like expression into lisp.  
If remove all comments, source code will be less then **<90** lines of actual code. 
By the way, you are viewing source code itself (yes, this readme file also is source code).
It's written in [literate coffescript](http://coffeescript.org/#literate) and fully [tested](tests.litcoffee) [![Build Status](https://travis-ci.org/antonmedv/ultra-tiny-compiler.svg?branch=master)](https://travis-ci.org/antonmedv/ultra-tiny-compiler) and published on [npm](https://www.npmjs.com/package/ultra-tiny-compiler). 
You can install it via `npm install ultra-tiny-compiler`.

What this compiler can do?

##### Examples

| Input               | Output                 |
|---------------------|------------------------|
| `1 + 2 * 3`         | `(+ 1 (* 2 3))`        |
| `1 + exp(i * pi)`   | `(+ 1 (exp (* i pi)))` |
| `pow(1 + 1 / n, n)` | `(pow (+ 1 (/ 1 n)) n)`|


#### Theory

We begin by describing grammar of C-like expressions, more precisely context-free grammar.
A context-free grammar has four components:  
 1. A set of _terminal_ symbols (tokens).
 2. A set of _nonterminals_ (syntactic variables).
 3. A set of _productions_, where each production consists of a nonterminal, called the head or left side of the production, an arrow, and a sequence of terminals and/or nonterminals, called the body or right side of the production.
 4. A designation of one of the nonterminals as the start symbol.
 
For notational convenience, productions with the same nonterminal as the head can have their bodies grouped by symbol |.

Here is our grammar for C-like expressions:

_expr_ → _expr_ + _term_ | _expr_ - _term_ | _term_  
_term_ → _term_ * _factor_ | _term_ / _factor_ | _factor_  
_factor_ → ( _expr_ ) | _atom_ | _call_  
_call_ → _atom_ ( _list_ )  
_list_ → _list_ , _expr_ | _expr_  
_atom_ → [a-z0-9]+  

Here _expr_, _term_, _factor_, ... a nonterminals and +, -, *, /, (, ), ... a terminals, _expr_ is a start symbol.

Usually compiler consist of several parts: lexer, parser, code generator.
Lexer reads input stream, split it into tokens and pass them into parser.
Parser uses grammar to build parse tree and generate [abstract syntax tree](https://en.wikipedia.org/wiki/Abstract_syntax_tree) (AST for short). 
AST resemble parse tree to an extent. However, in AST interior nodes represent programming constructs while in the parse tree, the interior nodes represent nonterminals.
Code generator traverses AST and generates code.

But we a going to simplify our compiler and combine parse phase with code generation phase. 
To accomplish this we will use syntax-directed definitions (semantic actions) for translating expressions into postfix notation.

_expr_ → _expr_ + _term_ {puts("+")}  
_expr_ → _expr_ - _term_ {puts("-")}  
_atom_ → [a-z0-9]+ {puts(_atom_)}  
...  

Expression `9-5+2` will be translating into `95-2+` with this semantic actions.

For parsing we will use simple form of [recursive-descent parsing](https://en.wikipedia.org/wiki/Recursive_descent_parser), called predictive parsing, in which the lookahead symbol unambiguously determines the flow of control through the procedure body for each nonterminal.
It is possible for a recursive-descent parser to loop forever. A problem arises with left-recursive productions like _expr_ → _expr_ + _term_.

A left-recursive production can be eliminated by rewriting the offending production:

_A_ → _A_ ⍺ | β

Into right-recursive production:

_A_ → β _R_  
_R_ → ⍺ _R_ | ∅

Using this technique we can transform our grammer into new grammar:

_expr_ → _term_ _exprR_  
_exprR_ → + _term_ _exprR_ | - _term_ _exprR_ | ∅  
_term_ → _factor_ _termR_  
_termR_ → * _factor_ _termR_ | / _factor_ _termR_ | ∅  
_factor_ → ( _expr_ ) | _atom_ | _call_  
_call_ → _atom_ ( _list_ )  
_list_ → _expr_ _listR_  
_listR_ → , _expr_ _listR_ | ∅  
_atom_ → [a-z0-9]+  

Semantic actions embedded in the production are simply carried along in the transformation, as if they were terminals.

Okay, let's write some code. We need only one function `compile(input: string)` which will do all the work.

    compile = (input) -> 

First start with lexer what will be splitting input sequence of characters into tokens.  
For example next input string `pow(1, 2 + 3)` will be transformed into array `['pow', '(', '1', ',', '2', '+', '3', ')']`.

      tokens = []
      
Every of our tokens will be one character, only atoms can be any length of letters or numbers.
      
      is_atom = /[a-z0-9]/i

Iterate throw characters of input. Note what inside this loop may be another loop 
which also increments `i` value.

      i = 0
      while i < input.length 
        switch char = input[i]

When meet one of next character, put it as token and continue to next character.

          when "+", "-", "*", "/", "(", ")", ","
            tokens.push char
            i++

Skip whitespaces.

          when " "
            i++

If character is unknown,

          else

Loop through each character in sequence until we encounter a character that is not an atom.

            if is_atom.test char
              tokens.push do ->
                value = ''
                while char and is_atom.test char
                  value += char
                  char = input[++i]
                value

Throw error on an unknown character.

            else
              throw "Unknown input char: #{char}"

We need a function which will be giving us a token from a tokens stream. Let's call it _next_.

      next = -> tokens.shift()

Lookahead is very important part of our compiler. Allows to determine what kind of production we are hitting next.

      lookahead = next()

Another important function which can match given terminal with `lookahead` terminal and move `lookahead` to next token.

      match = (terminal) ->
        if lookahead == terminal then lookahead = next()
        else throw "Syntax error: Expected token #{terminal}, got #{lookahead}"

Sometimes we a going to hit into wrong production, and we need a function which allows us to return to previous state.

      recover = (token) ->
        tokens.unshift lookahead
        lookahead = token

Next, we a going to write our production rules. Each nonterminal represents corresponding function call,
each terminal represents `match` function call. Also, we omitted ∅ production.  
`expr` function represents next production rule:  
_expr_ → _term_ _exprR_ 
      
      expr = ->
        term(); exprR()

Will be using lookahead for determine which production to use. 
Here also our first semantic actions which puts + or - onto stack. 
Ensure preserve ordering of semantic actions.  
_exprR_ → + _term_ {puts("+")} _exprR_ | - _term_ {puts("-")} _exprR_ | ∅

      exprR = ->
        if lookahead == "+"
          match("+"); term(); puts("+"); exprR()
        else if lookahead == "-"
          match("-"); term(); puts("-"); exprR()

_term_ → _factor_ _termR_

      term = ->
        factor(); termR()

_termR_ → * _factor_ {puts("*")} _termR_ | / _factor_ {puts("/")} _termR_ | ∅

      termR = -> 
        if lookahead == "*"
          match("*"); factor(); puts("*"); termR()
        else if lookahead == "/"
          match("/"); factor(); puts("/"); termR()

Next goes tricky production rule. First, we lookahead if there `(`, 
which will mean what current we at expression in brackets.
Second, try use production rule for function call.
Third, if function call production fails, consider current token as an atom.  
_factor_ → ( _expr_ ) | _atom_ | _call_

      factor = ->
        if lookahead == "("
          match("("); expr(); match(")")
        else 
          atom() unless call() 

Call production should allow recovering if we chose it incorrectly.  
Remember current token, and move to next token with `match`. If after goes an `(`,
when we choose call production correctly, otherwise recover to previous state.
Then we hitting list of arguments, puts special _mark_ onto stack, this allows us to
know how many arguments contains in this list.  
_call_ → _atom_ ( _list_ )

      call = ->
        token = lookahead
        match(lookahead)
        if lookahead == "("
          puts(false, "mark"); match("("); list(); match(")"); puts(token, "call")
          true
        else
          recover(token)
          false

_list_ → _expr_ _listR_ 

      list = ->
        expr(); listR();

_listR_ → , _expr_ _listR_ | ∅

      listR = ->
        if lookahead == ","
          match(","); expr(); listR();

At the bottom lies atom production. If we went down to this production, we expecting to get an atom.  
Otherwise, it's some syntax error.  
_atom_ → [a-z0-9]+

      atom = ->
        if is_atom.test lookahead
          match(puts(lookahead, "atom"))
        else
          throw "Syntax error: Unexpected token #{lookahead}"
          

In semantic rules, we use `puts` function, which records operators and atoms into `stack` in [reverse polish notation](https://en.wikipedia.org/wiki/Reverse_Polish_notation) (RPN).  
But instead recording entire program in RPN, we are going to do code generation on the fly. For that, we must understand
how to [postfix algorithm](https://en.wikipedia.org/wiki/Reverse_Polish_notation#Postfix_algorithm) works.

For example, we have a stream of tokens: _1_, _2_, _3_, +, -  

1. Put _1_ onto stack.
2. Put _2_ onto stack.
3. Put _3_ onto stack.
4. When + pop two values (3,2) from stack and put `(+ 2 3)` onto stack. 
5. When - pop two values (`(+ 2 3)`,1) from stack and put `(- 1 (+ 2 3))` onto stack back.

Generated code will be on top of stack and stack size will be one, if stream was complete.

      stack = []
      puts = (token, type="op") ->
        switch type

Then operators comes in, pop two values from stack,
generate code for that operator and push generated code back into stack.

          when "op"
            op = token
            y = stack.pop()
            x = stack.pop()
            stack.push "(#{op} #{x} #{y})"

Do same thing for _call_, but instead of gathering two values from stack,
take all values, until `false` shows up from stack. `false` represents special
mark to know their arguments ends.

          when "call"
            func = token
            args = []
            while arg = stack.pop()
              break unless arg
              args.unshift arg
            stack.push "(#{func} #{args.join(' ')})"

Any other atoms or marks push to stack as it appears.

          else 
            stack.push token

Return token from puts function for reuse.

        token

At this point, we described all function what we need, and now we can start parsing 
and compilation at same time.

      expr()

If parsing pass well, we end up with `stack` with only one item in it.
It's our compiled code. Let's return it from the function.

      stack[0]

Expose the world.

    module.exports = compile

What's it. We just wrote out compiler.

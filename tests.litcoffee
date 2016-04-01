# Tests
As source of compiler, all test written in one `.litcoffee` file. Tests written with [mocha](https://mochajs.org/) and uses [should](https://github.com/shouldjs/should.js) library for assertion. It's allow to write very expressive expressions.

    compile = require "./readme.litcoffee"

The only thing we want to test it's a compiler. Lets describe it.

    describe "Compiler", ->

      it "should compile math expressions", ->
        compile("1 + 2").should.equal "(+ 1 2)"
        compile("1 - 2").should.equal "(- 1 2)"
        compile("1 * 2").should.equal "(* 1 2)"
        compile("1 / 2").should.equal "(/ 1 2)"
        
        compile("1 - 2 * 3").should.equal "(- 1 (* 2 3))"
        compile("(1 - 2) * 3").should.equal "(* (- 1 2) 3)"
        
        compile("1").should.equal "1"
        compile("(1)").should.equal "1"
        compile("((1))").should.equal "1"
        
        compile("(1) - 2").should.equal "(- 1 2)"
        compile("1 - (2)").should.equal "(- 1 2)"
        compile("(1) - (2)").should.equal "(- 1 2)"
        
        compile("9-5+2").should.equal "(+ (- 9 5) 2)"
        compile("9-(5+2)").should.equal "(- 9 (+ 5 2))"

      it "should compile call expressions", ->
        compile("f(1)").should.equal "(f 1)"
        compile("f(1, 2)").should.equal "(f 1 2)"
        compile("f(1, 2, 3)").should.equal "(f 1 2 3)"
        
        compile("f(1 + 2)").should.equal "(f (+ 1 2))"
        compile("f(1, 2 + 3)").should.equal "(f 1 (+ 2 3))"
        
        compile("f(f(1, 2))").should.equal "(f (f 1 2))"
        compile("f(1, f(2, 3))").should.equal "(f 1 (f 2 3))"
        compile("f(f(1, 2), 3)").should.equal "(f (f 1 2) 3)"
        
        compile("f(1, 2) * g(3, 4)").should.equal "(* (f 1 2) (g 3 4))"
        compile("f(1 + 2, 3 - 4)").should.equal "(f (+ 1 2) (- 3 4))"

      it "should tokenize properly", ->
        compile("add(1, subtract(2, 3))").should.equal "(add 1 (subtract 2 3))"
        compile("squareRoot (100)").should.equal "(squareRoot 100)"
        compile("1000 + 1").should.equal "(+ 1000 1)"

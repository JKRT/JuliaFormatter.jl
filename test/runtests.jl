using JuliaFormatter
using JuliaFormatter: DefaultStyle, YASStyle, Options
using CSTParser
using Test

fmt1(s; i = 4, m = 80, kwargs...) =
    JuliaFormatter.format_text(s; kwargs..., indent = i, margin = m)
fmt1(s, i, m; kwargs...) = fmt1(s; kwargs..., i = i, m = m)

# Verifies formatting the formatted text
# results in the same output
function fmt(s; i = 4, m = 80, kwargs...)
    s1 = fmt1(s; kwargs..., i = i, m = m)
    return fmt1(s1; kwargs..., i = i, m = m)
end
fmt(s, i, m; kwargs...) = fmt(s; kwargs..., i = i, m = m)

function run_pretty(
    text::String,
    print_width::Int;
    opts = Options(),
    style = DefaultStyle(),
)
    d = JuliaFormatter.Document(text)
    s = JuliaFormatter.State(d, 4, print_width, opts)
    x = CSTParser.parse(text, true)
    t = JuliaFormatter.pretty(style, x, s)
    t
end

function run_nest(text::String, print_width::Int; opts = Options(), style = DefaultStyle())
    d = JuliaFormatter.Document(text)
    s = JuliaFormatter.State(d, 4, print_width, opts)
    x = CSTParser.parse(text, true)
    t = JuliaFormatter.pretty(style, x, s)
    JuliaFormatter.nest!(style, t, s)
    t, s
end

@testset "Default" begin

    @testset "basic" begin
        @test fmt("") == ""
        @test fmt("a") == "a"
        @test fmt("a  #foo") == "a  #foo"
        @test fmt("#foo") == "#foo"

        str = """
        begin
            #=
               Hello, world!
             =#
        end
        """
        @test fmt(str) == str

        str = """
        #=
        Hello, world!
        =#
        a"""
        @test fmt(str) == str
    end

    @testset "format toggle" begin
        str = "#! format: off\n module Foo a \n end"
        @test fmt(str) == str

        str = "#! format: off\n#! format: on"
        @test fmt(str) == str

        str = """
        begin
            #! format: off
            don't
                  format
                         this
            #! format: on
        end"""
        @test fmt(str) == str

        str = """
        begin
            #! format: off
            # don't
            #     format
            #            this
            #! format: on
        end"""
        @test fmt(str) == str

        str = """
        # this should be formatted
        a = f(aaa, bbb, ccc)

        #! format: off
        # anything past this point should not be formatted !!!
        a = f(aaa,
            bbb,ccc)

        c = 102000

        d = @foo 10 20
        #! format: onono

        e = "what the foocho"

        # comment"""
        str_ = """
        # this should be formatted
        a = f(aaa,
            bbb,ccc)

        #! format: off
        # anything past this point should not be formatted !!!
        a = f(aaa,
            bbb,ccc)

        c = 102000

        d = @foo 10 20
        #! format: onono

        e = "what the foocho"

        # comment"""
        @test fmt(str_) == str

        str = """
        # this should be formatted
        a = f(aaa, bbb, ccc)

        #! format: off
        # this section is not formatted !!!
        a = f(aaa,
            bbb,ccc)

        c = 102000

        d = @foo 10 20
        # turning formatting back on
        #! format: on
        # back in business !!!

        e = "what the foocho"
        a = f(aaa, bbb, ccc)

        #! format: off
        b = 10*20
        #! format: on
        b = 10 * 20

        # comment"""
        str_ = """
        # this should be formatted
        a = f(aaa, bbb, ccc)

        #! format: off
        # this section is not formatted !!!
        a = f(aaa,
            bbb,ccc)

        c = 102000

        d = @foo 10 20
        # turning formatting back on
        #! format: on
        # back in business !!!

        e = "what the foocho"
        a = f(aaa,
            bbb,      ccc)

        #! format: off
        b = 10*20
        #! format: on
        b = 10*20

        # comment"""
        @test fmt(str_) == str

        str = """
        # this should be formatted
        a = f(aaa, bbb, ccc)

        #! format: off
        # this section is not formatted !!!
        a = f(aaa,
            bbb,ccc)

        c = 102000

        #=
        α
        =#
        x =      1

        d = @foo 10 20"""
        @test fmt(str) == str
    end

    @testset "dot op" begin
        @test fmt("10 .^ a") == "10 .^ a"
        @test fmt("10.0 .^ a") == "10.0 .^ a"
        @test fmt("a.^b") == "a .^ b"
        @test fmt("a.^10.") == "a .^ 10.0"
    end

    @testset "toplevel" begin
        str = """

        hello = "string";

        a = 10;


        c = 50;

        #comment"""
        str_ = """

        hello = "string";

        a = 10
        ;


        c = 50;

        #comment"""
        @test fmt(str_) == str
        t = run_pretty(str, 80)
        @test length(t) == 17
    end

    @testset "for = vs in normalization" begin
        str = """
        for i = 1:n
            println(i)
        end"""
        @test fmt(str) == str

        str = """
        for i in itr
            println(i)
        end"""
        @test fmt(str) == str

        str = """
        for i = 1:n
            println(i)
        end"""
        str_ = """
        for i in 1:n
            println(i)
        end"""
        @test fmt(str) == str

        str = """
        for i in itr
            println(i)
        end"""
        str_ = """
        for i = itr
            println(i)
        end"""
        @test fmt(str_) == str

        str_ = """
        for i = I1, j in I2
            println(i, j)
        end"""
        str = """
        for i in I1, j in I2
            println(i, j)
        end"""
        @test fmt(str_) == str

        str = """
        for i = 1:30, j = 100:-2:1
            println(i, j)
        end"""
        str_ = """
        for i = 1:30, j in 100:-2:1
            println(i, j)
        end"""
        @test fmt(str) == str

        str_ = "[(i,j) for i=I1,j=I2]"
        str = "[(i, j) for i in I1, j in I2]"
        @test fmt(str_) == str

        str_ = "((i,j) for i=I1,j=I2)"
        str = "((i, j) for i in I1, j in I2)"
        @test fmt(str_) == str

        str_ = "[(i,j) for i in 1:2:10,j  in 100:-1:10]"
        str = "[(i, j) for i = 1:2:10, j = 100:-1:10]"
        @test fmt(str_) == str

        str_ = "((i,j) for i in 1:2:10,j  in 100:-1:10)"
        str = "((i, j) for i = 1:2:10, j = 100:-1:10)"
        @test fmt(str_) == str
    end


    @testset "tuples" begin
        @test fmt("(a,)") == "(a,)"
        @test fmt("a,b") == "a, b"
        @test fmt("a ,b") == "a, b"
        @test fmt("(a,b)") == "(a, b)"
        @test fmt("(a ,b)") == "(a, b)"
        @test fmt("( a, b)") == "(a, b)"
        @test fmt("(a, b )") == "(a, b)"
        @test fmt("(a, b ,)") == "(a, b)"
        @test fmt("""(a,    b ,
                            c)""") == "(a, b, c)"
    end

    @testset "curly" begin
        @test fmt("X{a,b}") == "X{a,b}"
        @test fmt("X{ a,b}") == "X{a,b}"
        @test fmt("X{a ,b}") == "X{a,b}"
        @test fmt("X{a, b}") == "X{a,b}"
        @test fmt("X{a,b }") == "X{a,b}"
        @test fmt("X{a,b }") == "X{a,b}"

        str = """
        mutable struct Foo{A<:Bar,Union{B<:Fizz,C<:Buzz},<:Any}
            a::A
        end"""
        @test fmt(str) == str
        t = run_pretty(str, 80)
        @test length(t) == 55

        str = """
        struct Foo{A<:Bar,Union{B<:Fizz,C<:Buzz},<:Any}
            a::A
        end"""
        @test fmt(str) == str
        t = run_pretty(str, 80)
        @test length(t) == 47
    end

    @testset "where op" begin
        str = "Atomic{T}(value) where {T<:AtomicTypes} = new(value)"
        str_ = "Atomic{T}(value) where T <: AtomicTypes = new(value)"
        @test fmt(str) == str
        @test fmt(str_) == str

        str = "Vector{Vector{T} where T}"
        @test fmt(str) == str

        str_ = "Vector{Vector{T}} where T"
        str = "Vector{Vector{T}} where {T}"
        @test fmt(str_) == str
        @test fmt(str) == str
    end

    @testset "unary ops" begin
        @test fmt("! x") == "!x"
        @test fmt("x ...") == "x..."

        # Issue 110
        str = raw"""
        if x
            if y
                :(
                    $lhs = fffffffffffffffffffffff(
                        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx,
                        yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy,
                    )
                )
            end
        end"""
        @test fmt(str) == str

        str = "foo(args...)"
        @test fmt(str, m = 1) == str
    end

    @testset "binary ops" begin
        @test fmt("a+b*c") == "a + b * c"
        @test fmt("a +b*c") == "a + b * c"
        @test fmt("a+ b*c") == "a + b * c"
        @test fmt("a+b *c") == "a + b * c"
        @test fmt("a+b* c") == "a + b * c"
        @test fmt("a+b*c ") == "a + b * c"
        @test fmt("a:b") == "a:b"
        @test fmt("a : b") == "a:b"
        @test fmt("a: b") == "a:b"
        @test fmt("a :b") == "a:b"
        @test fmt("a +1 :b -1") == "a+1:b-1"
        @test fmt("a:b:c") == "a:b:c"
        @test fmt("a :b:c") == "a:b:c"
        @test fmt("a: b:c") == "a:b:c"
        @test fmt("a:b :c") == "a:b:c"
        @test fmt("a:b: c") == "a:b:c"
        @test fmt("a:b:c ") == "a:b:c"
        @test fmt("a::b:: c") == "a::b::c"
        @test fmt("a :: b::c") == "a::b::c"
        # issue 74
        @test fmt("0:1/3:2") == "0:1/3:2"
        @test fmt("2a") == "2a"
        @test fmt("2(a+1)") == "2 * (a + 1)"

        str_ = "a[1:2 * num_source * num_dump-1]"
        str = "a[1:2*num_source*num_dump-1]"
        @test fmt(str_, 4, 1) == str

        str_ = "a[2 * num_source * num_dump-1:1]"
        str = "a[2*num_source*num_dump-1:1]"
        @test fmt(str_, 4, 1) == str

        str = "!(typ <: ArithmeticTypes)"
        @test fmt(str) == str

        # Function def

        str_ = """foo() = if cond a else b end"""
        str = """
        foo() =
            if cond
                a
            else
                b
            end"""
        @test fmt(str_) == str

        str_ = """
        foo() = begin
            body
        end"""
        str = """
        foo() =
            begin
                body
            end"""
        @test fmt(str) == str_
        @test fmt(str_, 4, 1) == str

        str_ = """
        foo() = quote
            body
        end"""
        str = """
        foo() =
            quote
                body
            end"""
        @test fmt(str) == str_
        @test fmt(str_, 4, 1) == str

        str = """foo() = :(Union{})"""
        @test fmt(str) == str

        str_ = """foo() = for i=1:10 body end"""
        str = """
        foo() =
            for i = 1:10
                body
            end"""
        @test fmt(str_) == str

        str_ = """foo() = while cond body end"""
        str = """
        foo() =
            while cond
                body
            end"""
        @test fmt(str_) == str

        str_ = """foo() = try body1 catch e body2 finally body3 end"""
        str = """
        foo() =
            try
                body1
            catch e
                body2
            finally
                body3
            end"""
        @test fmt(str_) == str

        str_ = """foo() = let var1=value1,var2,var3=value3 body end"""
        str = """
        foo() =
            let var1 = value1, var2, var3 = value3
                body
            end"""
        @test fmt(str_) == str

        # Assignment op

        str_ = """foo = if cond a else b end"""
        str = """
        foo =
          if cond
            a
          else
            b
          end"""
        @test fmt(str_, 2, 1) == str

        str_ = """foo = begin body end"""
        str = """
        foo = begin
          body
        end"""
        @test fmt(str_, 2, 11) == str
        str = """
        foo =
          begin
            body
          end"""
        @test fmt(str_, 2, 10) == str

        str_ = """foo = quote body end"""
        str = """
        foo = quote
          body
        end"""
        @test fmt(str_, 2, 11) == str
        str = """
        foo =
          quote
            body
          end"""
        @test fmt(str_, 2, 10) == str

        str_ = """foo = for i=1:10 body end"""
        str = """
        foo = for i = 1:10
          body
        end"""
        @test fmt(str_, 2, 18) == str
        str = """
        foo =
          for i = 1:10
            body
          end"""
        @test fmt(str_, 2, 17) == str

        str_ = """foo = while cond body end"""
        str = """
        foo =
          while cond
            body
          end"""
        @test fmt(str_, 2, 1) == str

        str_ = """foo = try body1 catch e body2 finally body3 end"""
        str = """
        foo =
          try
            body1
          catch e
            body2
          finally
            body3
          end"""
        @test fmt(str_, 2, 1) == str

        str_ = """foo = let var1=value1,var2,var3=value3 body end"""
        str = """
        foo =
          let var1 = value1, var2, var3 = value3
            body
          end"""
        @test fmt(str_, 2, 43) == str
        @test fmt(str_, 2, 40) == str

        str = """
        foo =
          let var1 = value1,
            var2,
            var3 = value3

            body
          end"""
        @test fmt(str_, 2, 39) == str


        str = """
        foo =
          let var1 =
              value1,
            var2,
            var3 =
              value3

            body
          end"""
        @test fmt(str_, 2, 17) == str
        @test fmt(str_, 2, 1) == str

        str_ = """
        foo = let
          body
        end"""
        @test fmt(str_, 2, 9) == str_
        str = """
        foo =
          let
            body
          end"""
        @test fmt(str_, 2, 8) == str
        @test fmt(str_, 2, 1) == str

        str_ = """a, b = cond ? e1 : e2"""
        str = """
        a, b = cond ?
            e1 : e2"""
        @test fmt(str_, 4, 13) == str

        str = """
        a, b =
            cond ?
            e1 : e2"""
        @test fmt(str_, 4, 12) == str

        str = """
        begin
            variable_name =
                argument1 + argument2
        end"""
        @test fmt(str, 4, 40) == str

        str = """
        begin
            variable_name =
                argument1 +
                argument2
        end"""
        @test fmt(str, 4, 28) == str

        str = """
        begin
            variable_name =
                conditional ? expression1 : expression2
        end"""
        @test fmt(str, 4, 58) == str

        str = """
        begin
            variable_name =
                conditional ? expression1 :
                expression2
        end"""
        @test fmt(str, 4, 46) == str

        str = """
        begin
            variable_name = conditional ?
                expression1 : expression2
        end"""
        @test fmt(str, 4, 34) == str

        str = """
        begin
            variable_name =
                conditional ?
                expression1 :
                expression2
        end"""
        @test fmt(str, 4, 32) == str

        str = "shmem[pout*rows+row] += shmem[pin*rows+row] + shmem[pin*rows+row-offset]"

        str_ = """
        shmem[pout*rows+row] +=
               shmem[pin*rows+row] + shmem[pin*rows+row-offset]"""
        @test fmt(str, 7, 71) == str_
        str_ = """
        shmem[pout*rows+row] +=
               shmem[pin*rows+row] +
               shmem[pin*rows+row-offset]"""
        @test fmt(str, 7, 54) == str_

        str = """
        begin
           var = func(arg1, arg2, arg3) * num
        end"""
        @test fmt(str, 3, 37) == str

        str_ = """
        begin
           var =
              func(arg1, arg2, arg3) * num
        end"""
        @test fmt(str, 3, 36) == str_
        @test fmt(str, 3, 34) == str_

        str_ = """
        begin
           var =
              func(arg1, arg2, arg3) *
              num
        end"""
        @test fmt(str, 3, 33) == str_
        @test fmt(str, 3, 30) == str_

        str_ = """
        begin
           var =
              func(
                 arg1,
                 arg2,
                 arg3,
              ) * num
        end"""
        @test fmt(str, 3, 29) == str_

        str_ = """
        begin
           var =
              func(
                 arg1,
                 arg2,
                 arg3,
              ) *
              num
        end"""
        @test fmt(str, 3, 1) == str_

        str = """
        begin
            foo() =
                (one, x -> (true, false))
        end"""
        @test fmt(str, 4, 36) == str
        @test fmt(str, 4, 33) == str

        str = """
        begin
            foo() = (
                one,
                x -> (true, false),
            )
        end"""
        @test fmt(str, 4, 32) == str
        @test fmt(str, 4, 27) == str
        str = """
        begin
            foo() = (
                one,
                x -> (
                    true,
                    false,
                ),
            )
        end"""
        @test fmt(str, 4, 26) == str

        str = """
        ignored_f(f) = f in (
            GlobalRef(Base, :not_int),
            GlobalRef(Core.Intrinsics, :not_int),
            GlobalRef(Core, :(===)),
            GlobalRef(Core, :apply_type),
            GlobalRef(Core, :typeof),
            GlobalRef(Core, :throw),
            GlobalRef(Base, :kwerr),
            GlobalRef(Core, :kwfunc),
            GlobalRef(Core, :isdefined),
        )"""
        @test fmt(str) == str

        str = """
        ignored_f(f) = f in (foo(@foo(foo(
            GlobalRef(Base, :not_int),
            GlobalRef(Core.Intrinsics, :not_int),
            GlobalRef(Core, :(===)),
            GlobalRef(Core, :apply_type),
            GlobalRef(Core, :typeof),
            GlobalRef(Core, :throw),
            GlobalRef(Base, :kwerr),
            GlobalRef(Core, :kwfunc),
            GlobalRef(Core, :isdefined),
        ))))"""
        @test fmt(str) == str

        str = "var = \"a_long_function_stringggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg\""
        fmt(str, 4, 1) == str
    end

    @testset "op chain" begin
        @test fmt("a+b+c+d") == "a + b + c + d"
    end

    @testset "comparison chain" begin
        @test fmt("a<b==c≥d") == "a < b == c ≥ d"
    end

    @testset "single line block" begin
        @test fmt("(a;b;c)") == "(a; b; c)"
    end

    @testset "func call" begin
        @test fmt("func(a, b, c)") == "func(a, b, c)"
        @test fmt("func(a,b,c)") == "func(a, b, c)"
        @test fmt("func(a,b,c,)") == "func(a, b, c)"
        @test fmt("func(a,b,c, )") == "func(a, b, c)"
        @test fmt("func( a,b,c    )") == "func(a, b, c)"
        @test fmt("func(a, b, c) ") == "func(a, b, c)"
        @test fmt("func(a, b; c)") == "func(a, b; c)"
        @test fmt("func(  a, b; c)") == "func(a, b; c)"
        @test fmt("func(a  ,b; c)") == "func(a, b; c)"
        @test fmt("func(a=1,b; c=1)") == "func(a = 1, b; c = 1)"

        str = """
        func(;
          c = 1,
        )"""
        @test fmt("func(; c = 1)", 2, 1) == str

        @test fmt("func(; c = 1,)") == "func(; c = 1)"
        @test fmt("func(a;)") == "func(a;)"

        str = """
        func(;
            a,
            b,
        )"""
        @test fmt(str, 4, 1) == str

        str = """
        func(
            x;
            a,
            b,
        )"""
        @test fmt(str, 4, 1) == str
    end

    @testset "macro call" begin
        str = """
        @f(
            a,
            b;
            x
        )"""
        str_ = "@f(a, b; x)"
        @test fmt(str_) == str_
        @test fmt(str_, 4, 1) == str

        str = """
        @f(
            a;
            x
        )"""
        str_ = "@f(a; x)"
        @test fmt(str_) == str_
        @test fmt(str_, 4, 1) == str

        str = """
        @f(;
          x
        )"""
        str_ = "@f(; x)"
        @test fmt(str_) == str_
        @test fmt(str_, 2, 1) == str

        str = """
        @f(;
            a,
            b
        )"""
        @test fmt(str, 4, 1) == str

        str = """
        @f(
            x;
            a,
            b
        )"""
        @test fmt(str, 4, 1) == str

        str = """@warn("Text")"""
        @test fmt(str) == str
    end

    @testset "macro block" begin
        str = raw"""
        @spawn begin
            acc = acc′′
            for _ in _
                a
                b
                ccc = dddd(ee, fff, gggggggggggg)
            end
            return
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 41
    end

    @testset "begin" begin
        str = """
        begin
            arg
        end"""
        @test fmt("""
                    begin
                    arg
                    end""") == str
        @test fmt("""
                    begin
                        arg
                    end""") == str
        @test fmt("""
                    begin
                        arg
                    end""") == str
        @test fmt("""
                    begin
                            arg
                    end""") == str
        str = """
        begin
            begin
                arg
            end
        end"""
        @test fmt("""
                    begin
                    begin
                    arg
                    end
                    end""") == str
        @test fmt("""
                    begin
                                begin
                    arg
                    end
                    end""") == str
        @test fmt("""
                    begin
                                begin
                    arg
                            end
                    end""") == str

        str = """
        begin
            s = foo(aaa, bbbb, cccc)
            s = foo(
                aaaa,
                bbbb,
                cccc,
            )
        end"""
        @test fmt(str, 4, 28) == str

    end

    @testset "quote" begin
        str = """
        quote
            arg
        end"""
        @test fmt("""
        quote
            arg
        end""") == str
        @test fmt("""
        quote
        arg
        end""") == str
        @test fmt("""
        quote
                arg
            end""") == str

        str = """:(a = 10; b = 20; c = a * b)"""
        @test fmt(":(a = 10; b = 20; c = a * b)") == str

        str = """
        :(endidx = ndigits;
        while endidx > 1 && digits[endidx] == UInt8('0')
            endidx -= 1
        end;
        if endidx > 1
            print(out, '.')
            unsafe_write(out, pointer(digits) + 1, endidx - 1)
        end)"""

        str_ = """
    :(endidx = ndigits;
                while endidx > 1 && digits[endidx] == UInt8('0')
                    endidx -= 1
                end;
                if endidx > 1
                    print(out, '.')
                    unsafe_write(out, pointer(digits) + 1, endidx - 1)
                end)"""
        @test fmt(str_) == str
        @test fmt(str) == str

        str = """
        quote
            s = foo(aaa, bbbb, cccc)
            s = foo(
                aaaa,
                bbbb,
                cccc,
            )
        end"""
        @test fmt(str, 4, 28) == str

    end

    @testset "do" begin
        str = """
        map(args) do x
            y = 20
            return x * y
        end"""

        @test fmt("""
        map(args) do x
          y = 20
                            return x * y
            end""") == str

        str = """
        map(1:10, 11:20) do x, y
            x + y
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 24

        str = """
        map(1:10, 11:20) do x, y
            z = reallylongvariablename
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 30

        # issue 58

        str_ = """
        model = SDDP.LinearPolicyGraph(stages = 2, lower_bound = 1, direct_mode = false) do (subproblem1, subproblem2, subproblem3, subproblem4, subproblem5, subproblem6, subproblem7, subproblem8)
            body
        end"""
        str = """
        model = SDDP.LinearPolicyGraph(
            stages = 2,
            lower_bound = 1,
            direct_mode = false,
        ) do (
            subproblem1,
            subproblem2,
            subproblem3,
            subproblem4,
            subproblem5,
            subproblem6,
            subproblem7,
            subproblem8,
        )
            body
        end"""
        @test fmt(str_) == str

        str_ = """
        model = SDDP.LinearPolicyGraph(stages = 2, lower_bound = 1, direct_mode = false) do subproblem1, subproblem2
            body
        end"""
        str = """
        model = SDDP.LinearPolicyGraph(
            stages = 2,
            lower_bound = 1,
            direct_mode = false,
        ) do subproblem1, subproblem2
            body
        end"""
        @test fmt(str_) == str

    end

    @testset "for" begin
        str = """
        for iter in I
            arg
        end"""
        @test fmt("""
        for iter in I
            arg
        end""") == str
        @test fmt("""
        for iter in I
        arg
        end""") == str
        @test fmt("""
        for iter in I
          arg
        end""") == str

        str = """
        for iter in I, iter2 in I2
            arg
        end"""
        @test fmt("""
        for iter = I, iter2= I2
            arg
        end""") == str
        @test fmt("""
        for iter= I, iter2=I2
        arg
        end""") == str
        @test fmt("""
        for iter    = I, iter2 = I2
                arg
            end""") == str

        str = """
        for i = 1:10
            body
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 12

        str = """
        for i in 1:10
            bodybodybodybody
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 20

    end

    @testset "while" begin
        str = """
        while cond
            arg
        end"""
        @test fmt("""
        while cond
            arg
        end""") == str
        @test fmt("""
        while cond
        arg
        end""") == str
        @test fmt("""
        while cond
                arg
            end""") == str

        # This will be a FileH header
        # with no blocks
        str = """
        a = 1
        while a < 100
            a += 1
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 13

        str = """
        a = 1
        while a < 100
            a += 1
            thisisalongnameforabody
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 27
    end

    @testset "let" begin
        str = """
        let x = X
            arg
        end"""
        @test fmt("""
        let x=X
            arg
        end""") == str
        @test fmt("""
        let x=X
        arg
        end""") == str
        @test fmt("""
        let x=X
            arg
        end""") == str

        str = """
        let x = X, y = Y
            arg
        end"""
        @test fmt("""
        let x = X, y = Y
            arg
        end""") == str
        @test fmt("""
        let x = X, y = Y
        arg
        end""") == str

        str = """
        y, back = let
            body
        end"""
        @test fmt("""
        y,back = let
          body
        end""") == str

        str = """
        let x = a,
            # comment
            b,
            c

            body
        end"""
        @test fmt("""
        let x = a,
            # comment
               b,
              c
           body
           end""") == str

        str = """
        let x = X, y = Y
            body
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 16

        str = """
        let x = X, y = Y
        letthebodieshitthefloor
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 27
    end

    @testset "structs" begin
        str = """
        struct name
            arg::Any
        end"""

        str_ = """
        struct name
            arg
        end"""
        @test fmt(str_) == str

        str_ = """
        struct name
        arg
        end"""
        @test fmt(str_) == str

        str_ = """
        struct name
                arg
            end"""
        @test fmt(str_) == str

        t = run_pretty(str_, 80)
        @test length(t) == 12

        str = """
        mutable struct name
            reallylongfieldname::Any
        end"""

        str_ = """
        mutable struct name
            reallylongfieldname
        end"""
        @test fmt(str_) == str

        str_ = """
        mutable struct name
        reallylongfieldname
        end"""
        @test fmt(str_) == str

        str_ = """
        mutable struct name
                reallylongfieldname
            end"""
        @test fmt(str_) == str

        t = run_pretty(str_, 80)
        @test length(t) == 28


    end

    @testset "try" begin
        str = """
        try
            arg
        catch
            arg
        end"""
        @test fmt("""
        try
            arg
        catch
            arg
        end""") == str

        @test fmt("""
        try
        arg
        catch
        arg
        end""") == str

        @test fmt("""
        try
                arg
            catch
                arg
            end""") == str

        str = """
        try
            arg
        catch
            arg
        end"""
        @test fmt("""
        try
            arg
        catch
            arg
        end""") == str

        @test fmt("""
        try
        arg
        catch
        arg
        end""") == str

        @test fmt("""
        try
                arg
            catch
                arg
            end""") == str

        str = """
        try
            arg
        catch err
            arg
        end"""

        @test fmt("""
        try
            arg
        catch err
            arg
        end""") == str

        @test fmt("""
        try
        arg
        catch err
        arg
        end""") == str

        @test fmt("""
        try
                arg
            catch err
                arg
            end""") == str


        str = """
        try
            a111111
            a2
        catch error123
            b1
            b2
        finally
            c1
            c2
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 14

        str = """
        try
            a111111
            a2
        catch erro
            b1
            b2
        finally
            c1
            c2
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 11

    end

    @testset "if" begin
        str = """
        if cond1
            e1
            e2
        elseif cond2
            e3
            e4
        elseif cond33
            e5
            e6
        else
            e7
            e88888
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 13

        str = """
        if cond1
            e1
            e2
        elseif cond2
            e3
            e4
        elseif cond33
            e5
            e6
        else
            e7
            e888888888
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 14

    end

    @testset "docs" begin
        str = """
        \"""
        doc
        \"""
        function f()
            20
        end"""
        t = run_pretty(str, 80)
        @test length(t) == 12

        str = """
        \"""doc
        \"""
        function f()
            20
        end"""
        @test fmt(str) == str

        str = """
        \"""
        doc\"""
        function f()
            20
        end"""
        @test fmt(str) == str

        str = """
        \"""doc\"""
        function f()
            20
        end"""
        @test fmt(str) == str

        str = """
        "doc
        "
        function f()
            20
        end"""
        @test fmt(str) == str

        str = """
        "
        doc"
        function f()
            20
        end"""
        @test fmt(str) == str

        str = """
        "doc"
        function f()
            20
        end"""
        @test fmt(str) == str

        # test aligning to function identation
        str_ = """
            "doc"
        function f()
            20
        end"""
        str = """
        "doc"
        function f()
            20
        end"""
        @test fmt(str_) == str

        str = """\"""
                 doc for Foo
                 \"""
                 Foo"""
        @test fmt(str) == str
        t = run_pretty(str, 80)
        @test length(t) == 11

        str = """
        \"""
        doc
        \"""
        function f()    #  comment
            20
        end"""
        @test fmt(str) == str

        #
        # Issue 157
        str = raw"""
        @doc \"""
           foo()
        \"""
        foo() = bar()"""
        @test fmt(str) == str

        str = raw"""
        @doc doc\"""
           foo()
        \"""
        foo() = bar()"""
        @test fmt(str) == str

        str = raw"""@doc "doc for foo" foo"""
        @test fmt(str) == str

        str = raw"""@doc \"""doc for foo\""" foo"""
        @test fmt(str) == str

        str = raw"""@doc doc\"""doc for foo\""" foo()"""
        @test fmt(str) == str

        str = raw"""@doc foo"""
        @test fmt(str) == str

        # issue 160
        str = """
        module MyModule

        import Markdown: @doc_str

        @doc doc\"""
            foo()
        \"""
        foo() = bar()

        end # module"""
        @test fmt(str) == str
    end

    @testset "strings" begin
        str = """
        \"""
        Interpolate using `\\\$`
        \"""
        a"""
        @test fmt(str) == str

        str = """error("foo\\n\\nbar")"""
        @test fmt(str) == str

        str = """
        \"""
        \\\\
        \"""
        x"""
        @test fmt(str) == str

        str = """
        begin
            s = \"\"\"This is a multiline string.
                    This is another line.
                          Look another 1 that is indented a bit.

                          cool!\"\"\"
        end"""
        str_ = """
        begin
        s = \"\"\"This is a multiline string.
                This is another line.
                      Look another 1 that is indented a bit.

                      cool!\"\"\"
        end"""
        @test fmt(str_) == str


        str = """
        begin
            begin
                throw(ErrorException(\"""An error occured formatting \$filename. :-(

                                     Please file an issue at https://github.com/domluna/JuliaFormatter.jl/issues
                                     with a link to a gist containing the contents of the file. A gist
                                     can be created at https://gist.github.com/.\"""))
            end
        end"""
        str_ = """
        begin
        begin
           throw(ErrorException(\"""An error occured formatting \$filename. :-(

                                Please file an issue at https://github.com/domluna/JuliaFormatter.jl/issues
                                with a link to a gist containing the contents of the file. A gist
                                can be created at https://gist.github.com/.\"""))
           end
        end"""
        @test fmt(str_, 4, 200) == str
        @test fmt(str_, 4, 1) == str

        str = """
        foo() = llvmcall(\"""
                         llvm1
                         llvm2
                         \""")"""
        @test fmt(str) == str
        # nests and then unnests
        @test fmt(str, 2, 20) == str

        str_ = """
        foo() =
          llvmcall(\"""
                   llvm1
                   llvm2
                   \""")"""
        @test fmt(str, 2, 19) == str_

        # the length calculation is kind of wonky here
        # but it's still a worthwhile test
        str_ = """
        foo() =
            llvmcall(\"""
                     llvm1
                     llvm2
                     \""")"""
        @test fmt(str, 4, 19) == str_
        @test fmt(str, 4, 18) == str_

        str_ = """
        foo() =
          llvmcall(\"""
                   llvm1
                   llvm2
                   \""")"""
        @test fmt(str, 2, 10) == str_

        str = """
        str = \"""
        begin
            arg
        end\"""
        """
        @test fmt(str) == str

        str = """
        str = \"""
              begin
                  arg
              end\"""
        """
        @test fmt(str) == str

        str = raw"""@test :(x`s`flag) == :(@x_cmd "s" "flag")"""
        @test fmt(str) == str

        str = raw"""
        if free < min_space
            throw(ErrorException(\"""
            Free space: \$free Gb
            Please make sure to have at least \$min_space Gb of free disk space
            before downloading the $database_name database.
            \"""))
        end"""
        str_ = raw"""
        if free <
           min_space
            throw(ErrorException(\"""
            Free space: \$free Gb
            Please make sure to have at least \$min_space Gb of free disk space
            before downloading the $database_name database.
            \"""))
        end"""
        @test fmt(str) == str
        @test fmt(str, 4, 1) == str_

        str = """foo(r"hello"x)"""
        @test fmt(str, 4, 1) == str

        str = """foo(r`hello`x)"""
        @test fmt(str, 4, 1) == str

        str = """foo(r\"""hello\"""x)"""
        @test fmt(str, 4, 1) == str

        str = """foo(r```hello```x)"""
        @test fmt(str, 4, 1) == str

        str = """foo(\"""hello\""")"""
        @test fmt(str, 4, 1) == str

        str = """foo(```hello```)"""
        @test fmt(str, 4, 1) == str
    end

    @testset "comments" begin
        str = """
        module Foo
        # comment 0
        # comment 1
        begin

            # comment 2
            # comment 3

            begin



                # comment 4
                # comment 5
                a = 10
                # comment 6
            end

        end

        end"""
        @test fmt(str) == str
        t = run_pretty(str, 80)
        @test length(t) == 14

        str_ = """
        module Foo
        # comment 0
        # comment 1
        begin

        # comment 2
        # comment 3

        begin



        # comment 4
        # comment 5
        a = 10
        # comment 6
        end

        end

        end"""
        str = """
        module Foo
        # comment 0
        # comment 1
        begin

            # comment 2
            # comment 3

            begin



                # comment 4
                # comment 5
                a = 10
                # comment 6
            end

        end

        end"""
        @test fmt(str_) == str

        str = "# comment 0\n\n\n\n\na = 1\n\n# comment 1\n\n\n\n\nb = 2\n\n\nc = 3\n\n# comment 2\n\n"
        @test fmt(str) == str

        str = """
        #=
        hello
        world
        =#
        const a = \"hi there\""""
        @test fmt(str) == str

        str = """
        if a
            # comment above var
            var = 10
            # comment below var
        else
            something_else()
        end"""
        @test fmt(str) == str

        str = """
        begin
            a = 10 # foo
            b = 20           # foo
        end    # trailing comment"""
        str_ = """
        begin
        a = 10 # foo
        b = 20           # foo
        end    # trailing comment"""
        @test fmt(str_) == str

        str = """
        function bar(x, y)
            # single comment ending in a subscriptₙ
            x - y
        end"""
        @test fmt("""
        function bar(x, y)
            # single comment ending in a subscriptₙ
            x- y
        end""") == str

        str_ = """
        var = foo(      # eat
            a, b, # comment 1
            c, # comment 2
            # in between comment
            d # comment 3
        )        # pancakes"""
        str = """
        var = foo(      # eat
            a,
            b, # comment 1
            c, # comment 2
            # in between comment
            d, # comment 3
        )        # pancakes"""
        @test fmt(str_) == str

        str_ = """
        var = foo(      # eat
            a, b, # comment 1
            c, # comment 2
            d # comment 3
        )        # pancakes"""
        str = """
        var = foo(      # eat
            a,
            b, # comment 1
            c, # comment 2
            d, # comment 3
        )        # pancakes"""
        @test fmt(str_) == str

        str = """
        A ? # foo
        # comment 1

        B :    # bar
        # comment 2
        C"""
        @test fmt(str) == str

        str = """
        A ? B :
        # comment

        C"""
        @test fmt(str) == str

        str = """
        foo() = A ?
            # comment 1

            B : C"""
        @test fmt(str) == str
        str_ = """
        foo() =
           A ?
           # comment 1

           B :
           C"""
        @test fmt(str, 3, 1) == str_

        str = """
        foo = A ?
            # comment 1

            B : C"""
        @test fmt(str) == str
        str_ = """
        foo =
           A ?
           # comment 1

           B :
           C"""
        @test fmt(str, 3, 1) == str_

        str = """
        begin
            var =
                a +
                # comment
                b
        end
        """
        @test fmt(str) == str

        str = """
        begin
            var() =
                a +
                # comment
                b
        end
        """
        @test fmt(str) == str

        str_ = """
        begin
            var = a +  # inline
                  # comment

                  b
        end
        """
        str = """
        begin
            var =
                a +  # inline
                # comment

                b
        end
        """
        @test fmt(str_) == str

        str_ = """
        begin
            var = a +  # inline
                  b
        end
        """
        str = """
        begin
          var =
            a +  # inline
            b
        end
        """
        @test fmt(str_, 2, 92) == str

        str = """
        foo() = 10 where {
            # comment
            A,
            # comment
            B,
            # comment
        }"""
        @test fmt(str) == str

        str = """
        foo() = 10 where Foo{
            # comment
            A,
            # comment
            B,
            # comment
        }"""
        @test fmt(str) == str

        str = """
        foo() = Foo(
            # comment
            A,
            # comment
            B,
            # comment
        )"""
        @test fmt(str) == str

        str = """
        foo(
            # comment
            ;
            # comment
            a = b, # comment
            c = d,
            # comment
        )"""
        @test fmt(str) == str

        str = """
        foo(;
            a = b, # comment
            c = d,
            # comment
        )"""

        str_ = """
        foo(
            ;
            a = b, # comment
            c = d,
            # comment
        )"""
        @test fmt(str_) == str

        str_ = """
        foo(
            ;
            ;a = b, # comment
            c = d,
            # comment
        )"""
        @test fmt(str_) == str

        str_ = """
        foo( ;
            ;a = b, # comment
            c = d,
            # comment
        )"""
        @test fmt(str_) == str

        # str = """
        # [
        #  a b Expr();
        #  d e Expr()
        # ]"""
        # str_ = """
        # [
        # ;
        # ;
        # ;
        #  a b Expr();
        #  ;
        #  d e Expr();
        #  ;
        # ]"""
        # @test fmt(str_) == str

        # Issue #51
        # NOTE: `str_` has extra whitespace after
        # keywords on purpose
        str_ = "begin \n # comment\n end"
        str = """
        begin
          # comment
        end"""
        @test fmt(str_, 2, 92) == str

        str_ = "try \n # comment\n catch e\n # comment\nbody\n # comment\n finally \n # comment\n end"
        str = """
        try
              # comment
        catch e
              # comment
              body
              # comment
        finally
              # comment
        end"""
        @test fmt(str_, 6, 92) == str

        str = """a = "hello ##" # # # α"""
        @test fmt(str) == str

        # issue #65
        str = "1 # α"
        @test fmt(str) == str

        str = "# α"
        @test fmt(str) == str

        str = """
        #=
        α
        =#
        x = 1
        """
        @test fmt(str) == str

        str = """
        # comments
        # before
        # code

        #comment
        if a
            #comment
        elseif b
            #comment
        elseif c
            #comment
            if aa
                #comment
            elseif bb
                #comment
                #comment
            else
                #comment
            end
            #comment
        elseif cc
            #comment
        elseif dd
            #comment
            if aaa
                #comment
            elseif bbb
                #comment
            else
                #comment
            end
            #comment
        end
        #comment
        """
        @test fmt(str) == str

        str = """
        foo = [
            # comment
            1,
            2,
            3,
        ]"""
        @test fmt(str) == str

        # issue 152
        str = """
        try
        catch
        end   # comment"""
        str_ = """try; catch;  end   # comment"""
        @test fmt(str_) == str

        str = """
        try
        catch
        end   # comment
        a = 10"""
        str_ = """
        try; catch;  end   # comment
        a = 10"""
        @test fmt(str_) == str
    end

    @testset "pretty" begin
        str = """function foo end"""
        @test fmt("""
            function  foo
            end""") == str
        t = run_pretty(str, 80)
        @test length(t) == 16

        str = """function foo() end"""
        @test fmt("""
                     function  foo()
            end""") == str
        t = run_pretty(str, 80)
        @test length(t) == 18

        str = """function foo()
                     10
                     20
                 end"""
        @test fmt("""function foo() 10;  20 end""") == str
        t = run_pretty(str, 80)
        @test length(t) == 14

        str = """abstract type AbstractFoo end"""
        @test fmt("""abstract type
                     AbstractFoo
                end""") == str

        str = "primitive type A <: B 32 end"
        @test fmt("""primitive type
                     A   <: B
                     32
                end""") == str

        str = """for i = 1:10
                     1
                     2
                     3
                 end"""
        @test fmt("""for i=1:10 1; 2; 3 end""") == str

        str = """while true
                     1
                     2
                     3
                 end"""
        @test fmt("""while true 1; 2; 3 end""") == str

        str = """try
                     a
                 catch e
                     b
                 end"""
        @test fmt("""try a catch e b end""") == str

        str = """try
                     a1
                     a2
                 catch e
                     b1
                     b2
                 finally
                     c1
                     c2
                 end"""
        @test fmt("""try a1;a2 catch e b1;b2 finally c1;c2 end""") == str

        str = """map(a) do b, c
                     e
                 end"""
        @test fmt("""map(a) do b,c
                     e end""") == str

        str = """let a = b, c = d
                     e1
                     e2
                     e3
                 end"""
        @test fmt("""let a=b,c=d\ne1; e2; e3 end""") == str

        str = """let a, b
                     e
                 end"""
        @test fmt("""let a,b
                     e end""") == str

        str = """return a, b, c"""
        @test fmt("""return a,b,
                     c""") == str

        str = """begin
                     a
                     b
                     c
                 end"""
        @test fmt("""begin a; b; c end""") == str

        str = """begin end"""
        @test fmt("""begin \n            end""") == str

        str = """quote
                     a
                     b
                     c
                 end"""
        @test fmt("""quote a; b; c end""") == str

        str = """quote end"""
        @test fmt("""quote \n end""") == str

        str = """if cond1
                     e1
                     e2
                 end"""
        @test fmt("if cond1 e1;e2 end") == str

        str = """if cond1
                     e1
                     e2
                 else
                     e3
                     e4
                 end"""
        @test fmt("if cond1 e1;e2 else e3;e4 end") == str

        str = """begin
                     if cond1
                         e1
                         e2
                     elseif cond2
                         e3
                         e4
                     elseif cond3
                         e5
                         e6
                     else
                         e7
                         e8
                     end
                 end"""
        @test fmt("begin if cond1 e1; e2 elseif cond2 e3; e4 elseif cond3 e5;e6 else e7;e8  end end",) ==
              str

        str = """if cond1
                     e1
                     e2
                 elseif cond2
                     e3
                     e4
                 end"""
        @test fmt("if cond1 e1;e2 elseif cond2 e3; e4 end") == str

        str = """
        [a b c]"""
        @test fmt("[a   b         c   ]") == str

        str = """
        [a; b; c]"""
        @test fmt("[a;   b;         c;   ]") == str

        str = """
        T[a b c]"""
        @test fmt("T[a   b         c   ]") == str

        str = """
        T[a; b; c]"""
        @test fmt("T[a;   b;         c;   ]") == str

        str = """
        T[a; b; c; e d f]"""
        @test fmt("T[a;   b;         c;   e  d    f   ]") == str

        str = """
        T[a; b; c; e d f]"""
        @test fmt("T[a;   b;         c;   e  d    f    ;   ]") == str

        str = "T[a;]"
        @test fmt(str) == str

        str = "[a;]"
        @test fmt(str) == str

        str = """T[e for e in x]"""
        @test fmt("T[e  for e= x  ]") == str

        str = """T[e for e = 1:2:50]"""
        @test fmt("T[e  for e= 1:2:50  ]") == str

        str = """struct Foo end"""
        @test fmt("struct Foo\n      end") == str

        str = """
        struct Foo
            body::Any
        end"""
        @test fmt("struct Foo\n    body  end") == str

        str = """macro foo() end"""
        @test fmt("macro foo()\n      end") == str

        str = """macro foo end"""
        @test fmt("macro foo\n      end") == str

        str = """
        macro foo()
            body
        end"""
        @test fmt("macro foo()\n    body  end") == str

        str = """mutable struct Foo end"""
        @test fmt("mutable struct Foo\n      end") == str

        str = """
        mutable struct Foo
            body::Any
        end"""
        @test fmt("mutable struct Foo\n    body  end") == str

        str = """
        module A
        bodybody
        end"""
        @test fmt("module A\n    bodybody  end") == str
        t = run_pretty(str, 80)
        @test length(t) == 8

        str = """
        module Foo end"""
        @test fmt("module Foo\n    end") == str
        t = run_pretty(str, 80)
        @test length(t) == 14

        str = """
        baremodule A
        bodybody
        end"""
        @test fmt("baremodule A\n    bodybody  end") == str
        t = run_pretty(str, 80)
        @test length(t) == 12

        str = """
        baremodule Foo end"""
        @test fmt("baremodule Foo\n    end") == str
        t = run_pretty(str, 80)
        @test length(t) == 18

        str = """
        if cond1
        elseif cond2
        elseif cond3
        elseif cond4
        elseif cond5
        elseif cond6
        elseif cond7
        else
        end"""
        @test fmt(str) == str

        str = """
        try
        catch
        finally
        end"""
        @test fmt(str) == str

        str = """
        (args...; kwargs) -> begin
            body
        end"""
        @test fmt(str) == str

        @test fmt("ref[a: (b + c)]") == "ref[a:(b+c)]"
        @test fmt("ref[a in b]") == "ref[a in b]"
    end

    @testset "nesting" begin
        str = """
        function f(
            arg1::A,
            key1 = val1;
            key2 = val2,
        ) where {
            A,
            F{
                B,
                C,
            },
        }
            10
            20
        end"""
        str_ = "function f(arg1::A,key1=val1;key2=val2) where {A,F{B,C}} 10; 20 end"
        @test fmt(str_, 4, 1) == str

        str = """
        function f(
            arg1::A,
            key1 = val1;
            key2 = val2,
        ) where {
            A,
            F{B,C},
        }
            10
            20
        end"""
        @test fmt(str_, 4, 17) == str

        str = """
        function f(
            arg1::A,
            key1 = val1;
            key2 = val2,
        ) where {A,F{B,C}}
            10
            20
        end"""
        @test fmt(str_, 4, 18) == str

        str = """
        a |
        b |
        c |
        d"""
        @test fmt("a | b | c | d", 4, 1) == str


        str = """
        a, b, c, d"""
        @test fmt("a, b, c, d", 4, 10) == str

        str = """
        a,
        b,
        c,
        d"""
        @test fmt("a, b, c, d", 4, 9) == str

        str = """(a, b, c, d)"""
        @test fmt("(a, b, c, d)", 4, 12) == str

        str = """
        (
            a,
            b,
            c,
            d,
        )"""
        @test fmt("(a, b, c, d)", 4, 11) == str

        str = """{a, b, c, d}"""
        @test fmt("{a, b, c, d}", 4, 12) == str

        str = """
        {
            a,
            b,
            c,
            d,
        }"""
        @test fmt("{a, b, c, d}", 4, 11) == str

        str = """[a, b, c, d]"""
        @test fmt("[a, b, c, d]", 4, 12) == str

        str = """
        [
            a,
            b,
            c,
            d,
        ]"""
        @test fmt("[a, b, c, d]", 4, 11) == str

        str = """
        cond ?
        e1 :
        e2"""
        @test fmt("cond ? e1 : e2", 4, 1) == str

        str = """
        cond ? e1 :
        e2"""
        @test fmt("cond ? e1 : e2", 4, 12) == str

        str = """
        cond1 ? e1 :
        cond2 ? e2 :
        cond3 ? e3 :
        e4"""
        @test fmt("cond1 ? e1 : cond2 ? e2 : cond3 ? e3 : e4", 4, 13) == str

        # I'm an importer/exporter
        str = """
        export a,
            b"""
        @test fmt("export a,b", 4, 1) == str

        str = """
        using a,
          b"""
        @test fmt("using a,b", 2, 1) == str

        str_ = "using M1.M2.M3: bar, baz"
        str = """
        using M1.M2.M3:
            bar, baz"""
        @test fmt(str, 4, 24) == str_
        @test fmt(str_, 4, 23) == str
        @test fmt(str_, 4, 12) == str

        str = """
        using M1.M2.M3:
            bar,
            baz"""
        @test fmt(str_, 4, 11) == str

        str_ = "import M1.M2.M3: bar, baz"
        str = """
        import M1.M2.M3:
            bar, baz"""
        @test fmt(str, 4, 25) == str_
        @test fmt(str_, 4, 24) == str
        @test fmt(str_, 4, 12) == str

        str = """
        import M1.M2.M3:
            bar,
            baz"""
        @test fmt(str_, 4, 11) == str

        str_ = """
        using A,

        B, C"""
        str = "using A, B, C"
        @test fmt(str_) == str

        str_ = """
        using A,
                  # comment
        B, C"""
        str = """
        using A,
          # comment
          B,
          C"""
        @test fmt(str_, 2, 80) == str

        str_ = """
        using A,  #inline
                  # comment
        B, C#inline"""
        str = """
        using A,  #inline
          # comment
          B,
          C#inline"""
        @test fmt(str_, 2, 80) == str

        str = """
        @somemacro function (fcall_ | fcall_)
            body_
        end"""
        @test fmt("@somemacro function (fcall_ | fcall_) body_ end", 4, 37) == str

        str = """
        @somemacro function (
            fcall_ | fcall_,
        )
            body_
        end"""
        @test fmt("@somemacro function (fcall_ | fcall_) body_ end", 4, 36) == str
        @test fmt("@somemacro function (fcall_ | fcall_) body_ end", 4, 20) == str

        str = """
        @somemacro function (
            fcall_ |
            fcall_,
        )
            body_
        end"""
        @test fmt("@somemacro function (fcall_ | fcall_) body_ end", 4, 19) == str

        str = "Val(x) = (@_pure_meta; Val{x}())"
        @test fmt("Val(x) = (@_pure_meta ; Val{x}())", 4, 80) == str

        str = "(a; b; c)"
        @test fmt("(a;b;c)", 4, 100) == str

        str = """
        (
          a; b; c
        )"""
        @test fmt("(a;b;c)", 2, 1) == str

        str = "(x for x = 1:10)"
        @test fmt("(x   for x  in  1 : 10)", 4, 100) == str

        str = """
        (
          x for
          x = 1:10
        )"""
        @test fmt("(x   for x  in  1 : 10)", 2, 10) == str

        str = """
        (
          x for
          x =
            1:10
        )"""
        @test fmt("(x   for x  in  1 : 10)", 2, 1) == str

        # indent for TupleH with no parens
        str = """
        function foo()
            arg1,
            arg2
        end"""
        @test fmt("function foo() arg1, arg2 end", 4, 1) == str

        str = """
        function foo()
            # comment
            arg
        end"""
        @test fmt(str, 4, 1) == str

        str = """
        A where {
            B,
        }"""
        str_ = "A where {B}"
        @test fmt(str_) == str_
        @test fmt(str_, 4, 1) == str

        str = """
        foo(
          arg1,
        )"""
        str_ = "foo(arg1)"
        @test fmt(str_) == str_
        @test fmt(str, 2, 1) == str

        str = """
        [
          arg1,
        ]"""
        str_ = "[arg1]"
        @test fmt(str_) == str_
        @test fmt(str, 2, 1) == str

        str = """
        {
          arg1,
        }"""
        str_ = "{arg1}"
        @test fmt(str_) == str_
        @test fmt(str, 2, 1) == str

        str = """
        (
          arg1
        )"""
        str_ = "(arg1)"
        @test fmt(str_) == str_
        @test fmt(str_, 2, 1) == str



        # https://github.com/domluna/JuliaFormatter.jl/issues/9#issuecomment-481607068
        str = """
        this_is_a_long_variable_name = Dict{Symbol,Any}(
            :numberofpointattributes => NAttributes,
            :numberofpointmtrs => NMTr,
            :numberofcorners => NSimplex,
            :firstnumber => Cint(1),
            :mesh_dim => Cint(3),
        )"""

        str_ = """this_is_a_long_variable_name = Dict{Symbol,Any}(:numberofpointattributes => NAttributes,
               :numberofpointmtrs => NMTr, :numberofcorners => NSimplex, :firstnumber => Cint(1),
               :mesh_dim => Cint(3),)"""
        @test fmt(str_, 4, 80) == str

        str = """
        this_is_a_long_variable_name =
             Dict{
                  Symbol,
                  Any,
             }(
                  :numberofpointattributes =>
                       NAttributes,
                  :numberofpointmtrs =>
                       NMTr,
                  :numberofcorners =>
                       NSimplex,
                  :firstnumber =>
                       Cint(1),
                  :mesh_dim =>
                       Cint(3),
             )"""
        @test fmt(str_, 5, 1) == str

        str = """
        this_is_a_long_variable_name = (
            :numberofpointattributes => NAttributes,
            :numberofpointmtrs => NMTr,
            :numberofcorners => NSimplex,
            :firstnumber => Cint(1),
            :mesh_dim => Cint(3),
        )"""

        str_ = """this_is_a_long_variable_name = (:numberofpointattributes => NAttributes,
               :numberofpointmtrs => NMTr, :numberofcorners => NSimplex, :firstnumber => Cint(1),
               :mesh_dim => Cint(3),)"""
        @test fmt(str_, 4, 80) == str

        str = """
        begin
            a &&
            b
            a ||
            b
        end"""
        @test fmt(str, 4, 1) == str

        str = """
        begin
            a &&
            b ||
            c &&
            d
        end"""
        @test fmt("begin\n a && b || c && d\nend", 4, 1) == str

        str = """
        func(
            a,
            \"""this
            is another
            multi-line
            string.
            Longest line
            \""",
            foo(b, c),
        )"""

        str_ = """
        func(a, \"""this
                is another
                multi-line
                string.
                Longest line
                \""", foo(b, c))"""
        @test fmt(str_) == str
        str_ = """
        func(
            a,
            \"""this
            is another
            multi-line
            string.
            Longest line
            \""",
            foo(
                b,
                c,
            ),
        )"""
        @test fmt(str, 4, 1) == str_



        # Ref
        str = "a[1+2]"
        @test fmt("a[1 + 2]", 4, 1) == str

        str = "a[(1+2)]"
        @test fmt("a[(1 + 2)]", 4, 1) == str

        str_ = "(a + b + c + d)"
        @test fmt(str_, 4, length(str_)) == str_

        str = """
        (
          a +
          b +
          c +
          d
        )"""
        @test fmt(str_, 2, length(str_) - 1) == str
        @test fmt(str_, 2, 1) == str


        str_ = "(a <= b <= c <= d)"
        @test fmt(str_, 4, length(str_)) == str_

        str = """
        (
           a <=
           b <=
           c <=
           d
        )"""
        @test fmt(str_, 3, length(str_) - 1) == str
        @test fmt(str_, 3, 1) == str

        # Don't join the first argument in a comparison
        # or chainopcall node, even if possible.
        str_ = "const a = arg1 + arg2 + arg3"
        str = """
        const a =
            arg1 +
            arg2 +
            arg3"""
        @test fmt(str_, 4, 18) == str

        str_ = "const a = arg1 == arg2 == arg3"
        str = """
        const a =
            arg1 ==
            arg2 ==
            arg3"""
        @test fmt(str_, 4, 19) == str

        # https://github.com/domluna/JuliaFormatter.jl/issues/60
        str_ = """
        function write_subproblem_to_file(
                node::Node, filename::String;
                format::Symbol=:both, throw_error::Bool = false)
            body
        end"""
        str = """
        function write_subproblem_to_file(
            node::Node,
            filename::String;
            format::Symbol = :both,
            throw_error::Bool = false,
        )
            body
        end"""
        @test fmt(str_) == str

        # any pairing of argument, kawrg, or param should nest
        str = """
        f(
            arg;
            a = 1,
        )"""
        @test fmt("f(arg;a=1)", 4, 1) == str

        str = """
        f(
           arg,
           a = 1,
        )"""
        @test fmt("f(arg,a=1)", 3, 1) == str

        str = """
        f(
         a = 1;
         b = 2,
        )"""
        @test fmt("f(a=1; b=2)", 1, 1) == str

        str = """
        begin
            if foo
            elseif baz
            elseif a ||
                   b &&
                   c
            elseif bar
            else
            end
        end"""
        @test fmt(str, 4, 1) == str
    end

    @testset "nesting line offset" begin
        str = "a - b + c * d"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 5
        _, s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "c ? e1 : e2"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 2
        _, s = run_nest(str, 8)
        @test s.line_offset == 2
        _, s = run_nest(str, 1)
        @test s.line_offset == 2

        str = "c1 ? e1 : c2 ? e2 : c3 ? e3 : c4 ? e4 : e5"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 32
        _, s = run_nest(str, 30)
        @test s.line_offset == 22
        _, s = run_nest(str, 20)
        @test s.line_offset == 12
        _, s = run_nest(str, 10)
        @test s.line_offset == 2
        _, s = run_nest(str, 1)
        @test s.line_offset == 2

        str = "f(a, b, c) where {A,B,C}"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 15
        _, s = run_nest(str, 14)
        @test s.line_offset == 1
        _, s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "f(a, b, c) where Union{A,B,C}"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 20
        _, s = run_nest(str, 19)
        @test s.line_offset == 1
        _, s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "f(a, b, c) where {A}"
        _, s = run_nest(str, 100)
        # adds surrounding {...} after `where`
        @test s.line_offset == length(str)
        _, s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "f(a, b, c) where {A<:S}"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 14
        _, s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "f(a, b, c) where Union{A,B,Union{C,D,E}}"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 31
        _, s = run_nest(str, 30)
        @test s.line_offset == 1
        _, s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "f(a, b, c) where {A,{B, C, D},E}"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, 1)
        @test s.line_offset == 1

        str = "(a, b, c, d)"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 1

        str = "a, b, c, d"
        _, s = run_nest(str, 100)
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 1

        str = """
        splitvar(arg) =
            @match arg begin
                ::T_ => (nothing, T)
                name_::T_ => (name, T)
                x_ => (x, :Any)
            end"""
        _, s = run_nest(str, 96)
        @test s.line_offset == 3
        _, s = run_nest(str, 1)
        @test s.line_offset == 7

        str = "prettify(ex; lines = false) = ex |> (lines ? identity : striplines) |> flatten |> unresolve |> resyntax |> alias_gensyms"
        _, s = run_nest(str, 80)
        @test s.line_offset == 17

        str = "foo() = a + b"
        _, s = run_nest(str, length(str))
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 9
        _, s = run_nest(str, 1)
        @test s.line_offset == 5

        str_ = """
        @Expr(:scope_block, begin
                    body1
                    @Expr :break loop_cont
                    body2
                    @Expr :break loop_exit2
                    body3
                end)"""

        str = """
        @Expr(:scope_block, begin
            body1
            @Expr :break loop_cont
            body2
            @Expr :break loop_exit2
            body3
        end)"""
        @test fmt(str_, 4, 100) == str

        str = """
        @Expr(
            :scope_block,
            begin
                body1
                @Expr :break loop_cont
                body2
                @Expr :break loop_exit2
                body3
            end
        )"""
        @test fmt(str_, 4, 20) == str


        str = "export @esc, isexpr, isline, iscall, rmlines, unblock, block, inexpr, namify, isdef"
        _, s = run_nest(str, length(str))
        @test s.line_offset == length(str)
        _, s = run_nest(str, length(str) - 1)
        @test s.line_offset == 74
        _, s = run_nest(str, 73)
        @test s.line_offset == 9

        # https://github.com/domluna/JuliaFormatter.jl/issues/9#issuecomment-481607068
        str = """this_is_a_long_variable_name = Dict{Symbol,Any}(:numberofpointattributes => NAttributes,
               :numberofpointmtrs => NMTr, :numberofcorners => NSimplex, :firstnumber => Cint(1),
               :mesh_dim => Cint(3),)"""
        _, s = run_nest(str, 80)
        @test s.line_offset == 1

        str = """this_is_a_long_variable_name = (:numberofpointattributes => NAttributes,
               :numberofpointmtrs => NMTr, :numberofcorners => NSimplex, :firstnumber => Cint(1),
               :mesh_dim => Cint(3),)"""
        _, s = run_nest(str, 80)
        @test s.line_offset == 1

        str = "import A: foo, bar, baz"
        _, s = run_nest(str, 22)
        @test s.line_offset == 17
        _, s = run_nest(str, 16)
        @test s.line_offset == 7

    end

    @testset "additional length" begin
        str_ = "f(a, @g(b, c), d)"
        str = """
        f(
            a,
            @g(b, c),
            d,
        )"""
        @test fmt(str_, 4, 13) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "f(a, @g(b, c), d)"
        str = """
        f(
            a,
            @g(
                b,
                c
            ),
            d,
        )"""
        @test fmt(str_, 4, 12) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "(a, (b, c), d)"
        str = """
        (
            a,
            (b, c),
            d,
        )"""
        @test fmt(str_, 4, 11) == str
        @test fmt(str, 4, length(str)) == str_

        str = """
        (
            a,
            (
                b,
                c,
            ),
            d,
        )"""
        @test fmt(str_, 4, 10) == str

        str_ = "(a, {b, c}, d)"
        str = """
        (
            a,
            {b, c},
            d,
        )"""
        @test fmt(str_, 4, 13) == str
        @test fmt(str_, 4, 11) == str

        str = """
        (
            a,
            {
                b,
                c,
            },
            d,
        )"""
        @test fmt(str_, 4, 10) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "(a, [b, c], d)"
        str = """
        (
            a,
            [b, c],
            d,
        )"""
        @test fmt(str_, 4, 13) == str
        @test fmt(str_, 4, 11) == str

        str = """
        (
            a,
            [
                b,
                c,
            ],
            d,
        )"""
        @test fmt(str_, 4, 10) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "a, (b, c), d"
        str = """
        a,
        (b, c),
        d"""
        @test fmt(str_, 4, length(str_) - 1) == str
        @test fmt(str_, 4, 7) == str

        str = """
        a,
        (
            b,
            c,
        ),
        d"""
        @test fmt(str_, 4, 6) == str
        @test fmt(str, 4, length(str)) == str_

        str_ = "(var1,var2) && var3"
        str = """
        (var1, var2) &&
        var3"""
        @test fmt(str_, 4, 19) == str
        @test fmt(str_, 4, 15) == str

        str = """
        (
            var1,
            var2,
        ) && var3"""
        @test fmt(str_, 4, 14) == str

        str = """
        (
            var1,
            var2,
        ) &&
        var3"""
        @test fmt(str_, 4, 1) == str

        str_ = "(var1,var2) ? (var3,var4) : var5"
        str = """
        (var1, var2) ?
        (var3, var4) :
        var5"""
        @test fmt(str_, 4, 14) == str

        str = """
        (
            var1,
            var2,
        ) ?
        (
            var3,
            var4,
        ) :
        var5"""
        @test fmt(str_, 4, 13) == str

        str = """
        (var1, var2) ? (var3, var4) :
        var5"""
        @test fmt(str_, 4, 29) == str

        str = """
        (var1, var2) ?
        (var3, var4) : var5"""
        @test fmt(str_, 4, 28) == str

        str = """
        f(
            var1::A,
            var2::B,
        ) where {A,B}"""
        @test fmt("f(var1::A, var2::B) where {A,B}", 4, 30) == str

        str = """
        f(
            var1::A,
            var2::B,
        ) where {
            A,
            B,
        }"""
        @test fmt("f(var1::A, var2::B) where {A,B}", 4, 12) == str

        str = "foo(a, b, c)::Rtype where {A,B} = 10"
        str_ = "foo(a, b, c)::Rtype where {A,B,} = 10"
        @test fmt(str, 4, length(str)) == str
        @test fmt(str_, 4, length(str_)) == str

        str_ = """
        foo(a, b, c)::Rtype where {A,B} =
            10"""
        @test fmt(str, 4, 35) == str_
        @test fmt(str, 4, 33) == str_

        str_ = """
        foo(
            a,
            b,
            c,
        )::Rtype where {A,B} = 10"""
        @test fmt(str, 4, 32) == str_
        @test fmt(str, 4, 25) == str_

        str_ = """
        foo(
            a,
            b,
            c,
        )::Rtype where {A,B} =
            10"""
        @test fmt(str, 4, 24) == str_
        @test fmt(str, 4, 22) == str_

        str_ = """
        foo(
            a,
            b,
            c,
        )::Rtype where {
            A,
            B,
        } = 10"""
        @test fmt(str, 4, 21) == str_

        str_ = """
        foo(
          a,
          b,
          c,
        )::Rtype where {
          A,
          B,
        } =
          10"""
        @test fmt(str, 2, 1) == str_

        str_ = """
        foo(
              a,
              b,
              c,
        )::Rtype where {
              A,
              B,
        } = 10"""
        @test fmt(str, 6, 18) == str_

        str = "keytype(::Type{<:AbstractDict{K,V}}) where {K,V} = K"
        @test fmt(str, 4, 52) == str

        str_ = "transcode(::Type{THISISONESUPERLONGTYPE1234567}) where {T<:Union{Int32,UInt32}} = transcode(T, String(Vector(src)))"

        str = """
        transcode(
          ::Type{THISISONESUPERLONGTYPE1234567},
        ) where {T<:Union{Int32,UInt32}} = transcode(T, String(Vector(src)))"""
        @test fmt(str_, 2, 80) == str
        @test fmt(str_, 2, 68) == str

        str = """
        transcode(
          ::Type{THISISONESUPERLONGTYPE1234567},
        ) where {T<:Union{Int32,UInt32}} =
          transcode(T, String(Vector(src)))"""
        @test fmt(str_, 2, 67) == str
        @test fmt(str_, 2, 40) == str

        str = """
        transcode(
          ::Type{
            THISISONESUPERLONGTYPE1234567,
          },
        ) where {T<:Union{Int32,UInt32}} =
          transcode(T, String(Vector(src)))"""
        @test fmt(str_, 2, 39) == str

        str_ = "transcode(::Type{T}, src::AbstractVector{UInt8}) where {T<:Union{Int32,UInt32}} = transcode(T, String(Vector(src)))"
        str = """
        transcode(
          ::Type{T},
          src::AbstractVector{UInt8},
        ) where {T<:Union{Int32,UInt32}} = transcode(T, String(Vector(src)))"""
        @test fmt(str_, 2, 80) == str
        @test fmt(str_, 2, 68) == str

        str = """
        transcode(
          ::Type{T},
          src::AbstractVector{UInt8},
        ) where {T<:Union{Int32,UInt32}} =
          transcode(T, String(Vector(src)))"""
        @test fmt(str_, 2, 67) == str

        # issue 56
        str_ = "a_long_function_name(Array{Float64,2}[[1.0], [0.5 0.5], [0.5 0.5; 0.5 0.5], [0.5 0.5; 0.5 0.5]])"
        str = """
        a_long_function_name(Array{Float64,2}[
            [1.0],
            [0.5 0.5],
            [0.5 0.5; 0.5 0.5],
            [0.5 0.5; 0.5 0.5],
        ])"""
        @test fmt(str, 4, length(str)) == str_
        @test fmt(str_, 4, length(str_) - 1) == str

        # unary op
        str_ = "[1, 1]'"
        str = """
        [
          1,
          1,
        ]'"""
        @test fmt(str, 2, length(str)) == str_
        @test fmt(str_, 2, length(str_) - 1) == str
    end

    @testset "Trailing zeros" begin
        @test fmt("1.") == "1.0"
        @test fmt("a * 1. + b") == "a * 1.0 + b"
        @test fmt("1. + 2. * im") == "1.0 + 2.0 * im"
        @test fmt("[1., 2.]") == "[1.0, 2.0]"
        @test fmt("""
        1. +
            2.
        """) == "1.0 + 2.0\n"
    end

    @testset "Leading zeros" begin
        @test fmt(".1") == "0.1"
        @test fmt("a * .1 + b") == "a * 0.1 + b"
        @test fmt(".1 + .2 * im") == "0.1 + 0.2 * im"
        @test fmt("[.1, .2]") == "[0.1, 0.2]"
        @test fmt("""
        .1 +
            .2
        """) == "0.1 + 0.2\n"
    end

    # https://github.com/domluna/JuliaFormatter.jl/issues/77
    @testset "matrices" begin
        str_ = """
        [ a b expr()
        d e expr()]"""
        str = """
        [
          a b expr()
          d e expr()
        ]"""
        @test fmt(str_, 2, 92) == str

        str_ = """
        T[ a b Expr()
        d e Expr()]"""
        str = """
        T[
            a b Expr()
            d e Expr()
        ]"""
        @test fmt(str_) == str

        str_ = """
        [ a b Expr();
        d e Expr();]"""
        str = """
        [
           a b Expr()
           d e Expr()
        ]"""
        @test fmt(str_, 3, 92) == str
        str_ = "[a b Expr(); d e Expr()]"
        @test fmt(str_) == str_
        @test fmt(str_, 3, 1) == str

        str_ = """
        T[ a b Expr();
        d e Expr();]"""
        str = """
        T[
            a b Expr()
            d e Expr()
        ]"""
        @test fmt(str_) == str

        str_ = "T[a b Expr(); d e Expr()]"
        @test fmt(str_) == str_
        @test fmt(str_, 4, 1) == str

        str = """
        [
          0.0 0.0 0.0 1.0
          0.0 0.0 0.1 1.0
          0.0 0.0 0.2 1.0
          0.0 0.0 0.3 1.0
          0.0 0.0 0.4 1.0
          0.0 0.0 0.5 1.0
          0.0 0.0 0.6 1.0
          0.0 0.0 0.7 1.0
          0.0 0.0 0.8 1.0
          0.0 0.0 0.9 1.0
          0.0 0.0 1.0 1.0
          0.0 0.0 0.0 1.0
          0.0 0.1 0.1 1.0
          0.0 0.2 0.2 1.0
          0.0 0.3 0.3 1.0
          0.0 0.4 0.4 1.0
          0.0 0.5 0.5 1.0
          0.0 0.6 0.6 1.0
          0.0 0.7 0.7 1.0
          0.0 0.8 0.8 1.0
          0.0 0.9 0.9 1.0
          0.0 1.0 1.0 1.0
          0.0 0.0 0.0 1.0
          0.1 0.1 0.1 1.0
          0.2 0.2 0.2 1.0
          0.3 0.3 0.3 1.0
          0.4 0.4 0.4 1.0
          0.5 0.5 0.5 1.0
        ]"""
        @test fmt(str, 2, 92) == str
    end

    @testset "multi-variable `for` and `let`" begin
        str = """
        for a in x, b in y, c in z
            body
        end"""
        str_ = """
        for a in x,
            b in y,
            c in z
            body
        end"""
        @test fmt(str_) == str

        str_ = """
        for a in
            x,
            b in
            y,
            c in
            z

            body
        end"""
        @test fmt(str, 4, 1) == str_
        @test fmt(str_) == str

        str = """
        let a = x, b = y, c = z
            body
        end"""
        str_ = """
        let a = x,
            b = y,
            c = z
            body
        end"""
        @test fmt(str_) == str

        str_ = """
        let a = x,
            b = y,
            c = z

            body
        end"""
        @test fmt(str_) == str

        str_ = """
        let a =
                x,
            b =
                y,
            c =
                z

            body
        end"""
        @test fmt(str, 4, 1) == str_

        str = """
        let
            # comment
            list = [1, 2, 3]

            body
        end"""
        @test fmt(str) == str


        # issue 155
        str_ = raw"""
        @testset begin
            @testset "some long title $label1 $label2" for (
                                                               label1,
                                                               x1,
                                                           ) in [
                                                               (
                                                                   "label-1-1",
                                                                   medium_sized_expression,
                                                               ),
                                                               (
                                                                   "label-1-2",
                                                                   medium_sized_expression,
                                                               ),
                                                           ],
                                                           (
                                                               label2,
                                                               x2,
                                                           ) in [
                                                               (
                                                                   "label-2-1",
                                                                   medium_sized_expression,
                                                               ),
                                                               (
                                                                   "label-2-2",
                                                                   medium_sized_expression,
                                                               ),
                                                           ]

                @test x1 == x2
            end
        end"""
        str = raw"""@testset begin
            @testset "some long title $label1 $label2" for (label1, x1) in [
                    ("label-1-1", medium_sized_expression),
                    ("label-1-2", medium_sized_expression),
                ],
                (label2, x2) in [
                    ("label-2-1", medium_sized_expression),
                    ("label-2-2", medium_sized_expression),
                ]

                @test x1 == x2
            end
        end"""
        @test fmt(str_) == str
    end

    @testset "single newline at end of file" begin
        str = "a = 10\n"

        f1 = tempname() * ".jl"
        open(f1, "w") do io
            write(io, "a = 10\n\n\n\n\n\n")
        end
        format_file(f1)
        format_file(f1)
        open(f1) do io
            res = read(io, String)
            @test res == str
        end
        rm(f1)
    end

    @testset "trailing comma - breaking cases" begin
        # A trailing comma here is ambiguous
        # It'll cause a parsing error.
        str = """
        gen2 = Iterators.filter(
            x -> x[1] % 2 == 0 && x[2] % 2 == 0,
            (x, y) for x = 1:10, y = 1:10
        )"""
        str_ = "gen2 = Iterators.filter(x -> x[1] % 2 == 0 && x[2] % 2 == 0, (x, y) for x = 1:10, y = 1:10)"

        @test fmt(str_, 4, 80) == str

        # With macro calls, a trailing comma can
        # change the semantics of the macro.
        #
        # Keeping this in mind it should not be
        # automatically added.
        str = """
        @func(
            a,
            b,
            c
        )"""
        @test fmt("@func(a, b, c)", 4, 1) == str

        str = """
        @func(
            a,
            b,
            c,
        )"""
        @test fmt("@func(a, b, c,)", 4, 1) == str

    end

    @testset "comphrehensions types" begin
        str_ = "var = (x, y) for x = 1:10, y = 1:10"
        str = """
        var = (x, y) for
        x = 1:10, y = 1:10"""
        @test fmt(str_, 4, length(str_) - 1) == str
        @test fmt(str_, 4, 18) == str

        str = """
        var = (x, y) for
        x = 1:10,
        y = 1:10"""
        @test fmt(str_, 4, 17) == str

        str_ = """
        begin
        weights = Dict((file, i) => w for (file, subject) in subjects for (
                i,
                w,
            ) in enumerate(weightfn.(eachrow(subject.events))))
        end"""
        str = """
        begin
            weights = Dict(
                (file, i) => w for (file, subject) in subjects
                for (i, w) in enumerate(weightfn.(eachrow(subject.events)))
            )
        end"""
        @test fmt(str_, 4, 90) == str

        str = """
        begin
            weights = Dict(
                (file, i) => w for (file, subject) in subjects
                for
                (i, w) in
                enumerate(weightfn.(eachrow(subject.events)))
            )
        end"""
        @test fmt(str_, 4, 60) == str

        str = """
        begin
            weights = Dict(
                (file, i) => w
                for (file, subject) in subjects
                for
                (i, w) in
                enumerate(weightfn.(eachrow(subject.events)))
            )
        end"""
        @test fmt(str_, 4, 50) == str
    end

    @testset "Splitpath issue" begin
        # TODO(odow): seet the TODO in src/JuliaFormatter.jl. Remove once
        # JuliaFormatter.jl drops support for Julia 1.0.
        dirs = JuliaFormatter.splitpath(@__DIR__)
        @test length(dirs) > 2
        @test dirs[end] == "test"
        @test occursin("JuliaFormatter", dirs[end-1])
    end

    @testset "invisbrackets" begin
        str = """
        some_function(
            (((
                very_very_very_very_very_very_very_very_very_very_very_very_long_function_name(
                    very_very_very_very_very_very_very_very_very_very_very_very_long_argument,
                    very_very_very_very_very_very_very_very_very_very_very_very_long_argument,
                ) for x in xs
            ))),
            another_argument,
        )"""
        @test fmt(str) == str

        str_ = """
some_function(
(((
               very_very_very_very_very_very_very_very_very_very_very_very_long_function_name(
                   very_very_very_very_very_very_very_very_very_very_very_very_long_argument,
                   very_very_very_very_very_very_very_very_very_very_very_very_long_argument,
               )
               for x in xs
))),
           another_argument,
        )"""
        @test fmt(str_) == str

        str = """
        if ((
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
        ))
          nothing
        end"""
        @test fmt(str, 2, 92) == str

        str = """
        begin
                if ((
                        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
                        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
                        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
                ))
                        nothing
                end
        end"""
        @test fmt(str, 8, 92) == str

        #
        # Don't nest the op if an arg is invisbrackets
        #

        str_ = """
        begin
        if foo
        elseif baz
        elseif (a || b) && c
        elseif bar
        else
        end
        end"""

        str = """
        begin
            if foo
            elseif baz
            elseif (a || b) && c
            elseif bar
            else
            end
        end"""
        @test fmt(str_, 4, 24) == str

        str = """
        begin
            if foo
            elseif baz
            elseif (a || b) &&
                   c
            elseif bar
            else
            end
        end"""
        @test fmt(str_, 4, 23) == str

        str = """
        begin
            if foo
            elseif baz
            elseif (
                a || b
            ) && c
            elseif bar
            else
            end
        end"""
        @test fmt(str_, 4, 15) == str

        str = """
        begin
            if foo
            elseif baz
            elseif (
                a ||
                b
            ) && c
            elseif bar
            else
            end
        end"""
        @test fmt(str_, 4, 14) == str
        @test fmt(str_, 4, 10) == str

        str = """
        begin
            if foo
            elseif baz
            elseif (
                a ||
                b
            ) &&
                   c
            elseif bar
            else
            end
        end"""
        @test fmt(str_, 4, 9) == str
        @test fmt(str_, 4, 1) == str
    end

    @testset "unnest" begin
        str = """
        let X = LinearAlgebra.Symmetric{T,S} where {S<:(AbstractArray{U,2} where {U<:T})} where {T},
            Y = Union{
                LinearAlgebra.Hermitian{T,S} where {S<:(AbstractArray{U,2} where {U<:T})} where T,
                LinearAlgebra.Symmetric{T,S} where {S<:(AbstractArray{U,2} where {U<:T})} where T,
            }

            @test X <: Y
        end"""
        @test fmt(str, 4, 92) == str

        str = """
        let X = LinearAlgebra.Symmetric{
                T,
                S,
            } where {S<:(AbstractArray{U,2} where {U<:T})} where {T},
            Y = Union{
                LinearAlgebra.Hermitian{T,S} where {S<:(AbstractArray{U,2} where {U<:T})} where T,
                LinearAlgebra.Symmetric{T,S} where {S<:(AbstractArray{U,2} where {U<:T})} where T,
            }

            @test X <: Y
        end"""
        @test fmt(str, 4, 90) == str

        str = """
        ys = map(xs) do x
            return (
                very_very_very_very_very_very_very_very_very_very_very_long_expr,
                very_very_very_very_very_very_very_very_very_very_very_long_expr,
            )
        end"""
        @test fmt(str) == str
    end

    @testset "issue 137" begin
        str = """
        (
            let x = f() do
                    body
                end
                x
            end for x in xs
        )"""
        str_ = """
        (
               let x = f() do
                       body
                   end
                   x
               end for x in xs
         )"""
        @test fmt(str_) == str

        str = """
        (
            let
                x = f() do
                    body
                end
                x
            end for x in xs
        )"""
        str_ = """
        (
          let
              x = f() do
                  body
              end
              x
          end for x in xs)"""
        @test fmt(str_) == str

        str = """
        let n = try
                ..
            catch
                ..
            end
            ..
        end"""
        @test fmt(str) == str

        str = """
        let n = let
                ..
            end
            ..
        end"""
        @test fmt(str) == str

        str = """
        let n = begin
                ..
            end
            ..
        end"""
        @test fmt(str) == str
    end

    @testset "Block inside iterator/array comprehension #170" begin
        str_ = """
        ys = ( if p1(x)
                 f1(x)
        elseif p2(x)
            f2(x)
        else
            f3(x)
        end for    x in xs)
        """
        str = """
        ys = (
            if p1(x)
                f1(x)
            elseif p2(x)
                f2(x)
            else
                f3(x)
            end for x in xs
        )
        """
        @test fmt(str_) == str

        str = """
        ys = map(xs) do x
            if p1(x)
                f1(x)
            elseif p2(x)
                f2(x)
            else
                f3(x)
            end
        end
        """
        @test fmt(str) == str

        str_ = """
        y1 = Any[if true
            very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_long_expr
        end for i in 1:1]"""
        str = """
        y1 = Any[
            if true
                very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_long_expr
            end for i = 1:1
        ]"""
        @test fmt(str_) == str
        _, s = run_nest(str_, 100)
        @test s.line_offset == 1

        str_ = """
        y1 = [if true
            very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_long_expr
        end for i in 1:1]"""
        str = """
        y1 = [
            if true
                very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_long_expr
            end for i = 1:1
        ]"""
        @test fmt(str_) == str
        _, s = run_nest(str_, 100)
        @test s.line_offset == 1

        str_ = """
        y1 = [if true
            short_expr
        end for i in 1:1]"""
        str = """
        y1 = [
            if true
                short_expr
            end for i = 1:1
        ]"""
        @test fmt(str_) == str
        _, s = run_nest(str_, 100)
        @test s.line_offset == 1

    end

    @testset "multiline / #139" begin
        str_ = """
        m = match(r\"""
                  (
                      pattern1 |
                      pattern2 |
                      pattern3
                  )
                  \"""x, aaa, str)"""
        str = """
        m = match(
            r\"""
            (
                pattern1 |
                pattern2 |
                pattern3
            )
            \"""x,
            aaa,
            str,
        )"""
        @test fmt(str_) == str

        str_ = """
        m = match(r```
                  (
                      pattern1 |
                      pattern2 |
                      pattern3
                  )
                  ```x, aaa, str)"""
        str = """
        m = match(
            r```
            (
                pattern1 |
                pattern2 |
                pattern3
            )
            ```x,
            aaa,
            str,
        )"""
        @test fmt(str_) == str

        str_ = """
        y = similar([
            1
            2
            3
        ], (4, 5))"""
        str = """
        y = similar(
            [
                1
                2
                3
            ],
            (4, 5),
        )"""
        @test fmt(str_) == str

        str_ = """
        y = similar(T[
            1
            2
            3
        ], (4, 5))"""
        str = """
        y = similar(
            T[
                1
                2
                3
            ],
            (4, 5),
        )"""
        @test fmt(str_) == str


    end


    @testset "BracesCat / Issue 150" begin
        str_ = "const SymReg{B,MT} = ArrayReg{B,Basic,MT} where {MT <:AbstractMatrix{Basic}}"
        str = "const SymReg{B,MT} = ArrayReg{B,Basic,MT} where {MT<:AbstractMatrix{Basic}}"
        @test fmt(str_, whitespace_typedefs = false) == str

        str = "const SymReg{B, MT} = ArrayReg{B, Basic, MT} where {MT <: AbstractMatrix{Basic}}"
        @test fmt(str_, whitespace_typedefs = true) == str
    end

    @testset "remove excess newlines" begin
        str_ = """
        var = foo(a,

        b,     c,





        d)"""
        str = "var = foo(a, b, c, d)"
        @test fmt(str_) == str

        str = """
        var =
            foo(
                a,
                b,
                c,
                d,
            )"""
        @test fmt(str_, 4, 1) == str

        str_ = """
        var = foo(a,

        b,     c,


        # comment !!!


        d)"""
        str = """
        var = foo(
            a,
            b,
            c,


            # comment !!!


            d,
        )"""
        @test fmt(str_) == str

        str = """
        var = foo(
            a,
            b,
            c,

            # comment !!!

            d,
        )"""
        @test fmt(str_, remove_extra_newlines = true) == str

        str_ = """
        a = 10

        # foo1
        # ooo



        # aooo


        # aaaa
        b = 20



        # hello
        """
        str = """
        a = 10

        # foo1
        # ooo

        # aooo

        # aaaa
        b = 20

        # hello
        """
        @test fmt(str, remove_extra_newlines = true) == str

        str_ = """
        var =

            func(a,

            b,

            c)"""
        str = """var = func(a, b, c)"""
        @test fmt(str_) == str
        @test fmt(str_, remove_extra_newlines = true) == str

        str_ = """
        var =

            a &&


        b &&  
        c"""
        str = """var = a && b && c"""
        @test fmt(str_) == str
        @test fmt(str_, remove_extra_newlines = true) == str

        str_ = """
        var =

            a ?


        b :          



        c"""
        str = """var = a ? b : c"""
        @test fmt(str_) == str
        @test fmt(str_, remove_extra_newlines = true) == str

        str_ = """
        var =

            a +


        b +          



        c"""
        str = """var = a + b + c"""
        @test fmt(str_) == str
        @test fmt(str_, remove_extra_newlines = true) == str

        str_ = """
        var =

            a   ==


        b   ==          



        c"""
        str = """var = a == b == c"""
        @test fmt(str_) == str
        @test fmt(str_, remove_extra_newlines = true) == str
    end

    @testset "#183" begin
        str_ = """
        function f(args...)

            next!(s.progress;
            # comment
            )
            nothing
        end"""
        str = """
        function f(args...)

            next!(s.progress;
            # comment
        )
            nothing
        end"""
        @test fmt(str_) == str

        # NOTE: when this passes delete the above test
        str = """
        function f(args...)

            next!(
                s.progress;
                # comment
            )
            nothing
        end"""
        @test_broken fmt(str_) == str
    end

    @testset "#189" begin
        str_ = """
    D2 = [
            (b_hat * y - delta_hat[i] * y) * gamma[i] + (b * y_hat - delta[i] * y_hat) *
                                                            gamma_hat[i] + (b_hat - y_hat) *
                                                                           delta[i] + (b - y) *
                                                                                      delta_hat[i] - delta[i] * delta_hat[i]
            for i = 1:8
        ]"""
        str = """
        D2 = [
            (b_hat * y - delta_hat[i] * y) * gamma[i] +
            (b * y_hat - delta[i] * y_hat) * gamma_hat[i] +
            (b_hat - y_hat) * delta[i] +
            (b - y) * delta_hat[i] - delta[i] * delta_hat[i] for i = 1:8
        ]"""
        @test fmt(str_) == str

    end

    @testset "#193" begin
        str = """
        module Module
        # comment
        end"""
        @test fmt(str) == str

        str = """
        module Module
        # comment
        @test
        # comment
        end"""
        @test fmt(str) == str
    end

    @testset "#194" begin
        str_ = """
        function mystr( str::String )
        return SubString( str, 1:
        3 )
        end"""
        str = """
        function mystr(str::String)
            return SubString(str, 1:3)
        end"""
        @test fmt(str_) == str
    end

    @testset "align ChainOpCall indent" begin
        str_ = """
        function _()
            return some_expression *
            some_expression *
            some_expression *
            some_expression *
            some_expression *
            some_expression *
            some_expression
        end"""
        str = """
        function _()
            return some_expression *
                   some_expression *
                   some_expression *
                   some_expression *
                   some_expression *
                   some_expression *
                   some_expression
        end"""
        @test fmt(str_) == str

        str_ = """
        @some_macro some_expression *
        some_expression *
        some_expression *
        some_expression *
        some_expression *
        some_expression *
        some_expression"""
        str = """
        @some_macro some_expression *
                    some_expression *
                    some_expression *
                    some_expression *
                    some_expression *
                    some_expression *
                    some_expression"""
        @test fmt(str_) == str

        str_ = """
        if some_expression && some_expression && some_expression && some_expression

            body
        end"""
        str = """
        if some_expression &&
           some_expression &&
           some_expression &&
           some_expression

            body
        end"""
        @test fmt(str_, m = 74) == str
        @test fmt(str, m = 75) == str_

        str_ = """
        if argument1 && argument2 && (argument3 || argument4 || argument5) && argument6

            body
        end"""
        str = """
        if argument1 &&
           argument2 &&
           (argument3 || argument4 || argument5) &&
           argument6

            body
        end"""
        @test fmt(str_, m = 43) == str

        str = """
        if argument1 &&
           argument2 &&
           (
               argument3 ||
               argument4 ||
               argument5
           ) &&
           argument6

            body
        end"""
        @test fmt(str_, m = 42) == str
    end

    @testset "issue 200" begin
        str_ = """
        begin
            f() do
                @info @sprintf \"\"\"
                Δmass   = %.16e\"\"\" abs(weightedsum(Q) - weightedsum(Qe)) / weightedsum(Qe)
            end
        end"""

        # NOTE: this looks slightly off because we're compensating for escaping quotes
        str = """
        begin
            f() do
                @info @sprintf \"\"\"
                Δmass   = %.16e\"\"\" abs(weightedsum(Q) - weightedsum(Qe)) /
                                   weightedsum(Qe)
            end
        end"""
        @test fmt(str_, m = 81) == str
        @test fmt(str, m = 82) == str_
    end

    @testset "issue 202" begin
        str_ = """
        @inline function _make_zop_getvalues(iterators)
            types = map(iterators) do itr
                t =     constructorof(typeof(itr))::Union{Iterators.ProductIterator,CartesianIndices}
                Val(t)
            end
            return function (xs) end
        end"""
        str = """
        @inline function _make_zop_getvalues(iterators)
            types = map(iterators) do itr
                t = constructorof(typeof(itr))::Union{Iterators.ProductIterator,CartesianIndices}
                Val(t)
            end
            return function (xs) end
        end"""
        @test fmt(str_, m = 92) == str

        str_ = """
        @vlplot(
            data = dataset("cars"),
            facet = {row = {field = :Origin, type = :nominal}},
            spec = {
                layer = [
                    {
                        mark = :point,
                        encoding =     {x = {field = :Horsepower}, y = {field = :Miles_per_Gallon}},
                    },
                    {
                        mark = {type = :rule, color = :red},
                        data = {values = [{ref = 10}]},
                        encoding = {y = {field = :ref, type = :quantitative}},
                    },
                ],
            }
        )"""
        str = """
        @vlplot(
            data = dataset("cars"),
            facet = {row = {field = :Origin, type = :nominal}},
            spec = {
                layer = [
                    {
                        mark = :point,
                        encoding = {x = {field = :Horsepower}, y = {field = :Miles_per_Gallon}},
                    },
                    {
                        mark = {type = :rule, color = :red},
                        data = {values = [{ref = 10}]},
                        encoding = {y = {field = :ref, type = :quantitative}},
                    },
                ],
            }
        )"""
        @test fmt(str_, m = 92) == str
    end

    @testset "issue 207" begin
        str_ = """
        @traitfn function predict_ar(m::TGP, p::Int = 3, n::Int = 1; y_past = get_y(m)) where {T,TGP<:AbstractGP{T};IsMultiOutput{TGP}}
        end"""

        str = """
        @traitfn function predict_ar(
            m::TGP,
            p::Int = 3,
            n::Int = 1;
            y_past = get_y(m),
        ) where {T,TGP<:AbstractGP{T};IsMultiOutput{TGP}} end"""
        @test fmt(str_, m = 92) == str

        str = """
        @traitfn function predict_ar(
            m::TGP,
            p::Int = 3,
            n::Int = 1;
            y_past = get_y(m),
        ) where {T, TGP <: AbstractGP{T}; IsMultiOutput{TGP}} end"""
        @test fmt(str_, m = 92, whitespace_typedefs = true) == str

        str_ = """
        @traitfn function predict_ar(m::TGP, p::Int = 3, n::Int = 1; y_past = get_y(m)) where C <: Union{T,TGP<:AbstractGP{T};IsMultiOutput{TGP}}
        end"""

        str = """
        @traitfn function predict_ar(
            m::TGP,
            p::Int = 3,
            n::Int = 1;
            y_past = get_y(m),
        ) where {C<:Union{T,TGP<:AbstractGP{T};IsMultiOutput{TGP}}} end"""
        @test fmt(str_, m = 92) == str

        str = """
        @traitfn function predict_ar(
            m::TGP,
            p::Int = 3,
            n::Int = 1;
            y_past = get_y(m),
        ) where {C <: Union{T, TGP <: AbstractGP{T}; IsMultiOutput{TGP}}} end"""
        @test fmt(str_, m = 92, whitespace_typedefs = true) == str

    end


end

@testset "Format Options" begin
    @testset "whitespace in typedefs" begin
        str_ = "Foo{A,B,C}"
        str = "Foo{A, B, C}"
        @test fmt(str_, whitespace_typedefs = true) == str

        str_ = """
        struct Foo{A<:Bar,Union{B<:Fizz,C<:Buzz},<:Any}
            a::A
        end"""
        str = """
        struct Foo{A <: Bar, Union{B <: Fizz, C <: Buzz}, <:Any}
            a::A
        end"""
        @test fmt(str_, whitespace_typedefs = true) == str

        str_ = """
        function foo() where {A,B,C{D,E,F{G,H,I},J,K},L,M<:N,Y>:Z}
            body
        end
        """
        str = """
        function foo() where {A, B, C{D, E, F{G, H, I}, J, K}, L, M <: N, Y >: Z}
            body
        end
        """
        @test fmt(str_, whitespace_typedefs = true) == str

        str_ = "foo() where {A,B,C{D,E,F{G,H,I},J,K},L,M<:N,Y>:Z} = body"
        str = "foo() where {A, B, C{D, E, F{G, H, I}, J, K}, L, M <: N, Y >: Z} = body"
        @test fmt(str_, whitespace_typedefs = true) == str
    end

    @testset "whitespace ops in indices" begin
        str = "arr[1 + 2]"
        @test fmt("arr[1+2]", m = 1, whitespace_ops_in_indices = true) == str

        str = "arr[(1 + 2)]"
        @test fmt("arr[(1+2)]", m = 1, whitespace_ops_in_indices = true) == str

        str_ = "arr[1:2*num_source*num_dump-1]"
        str = "arr[1:(2 * num_source * num_dump - 1)]"
        @test fmt(str_, m = 1, whitespace_ops_in_indices = true) == str

        str_ = "arr[2*num_source*num_dump-1:1]"
        str = "arr[(2 * num_source * num_dump - 1):1]"
        @test fmt(str_, m = 1, whitespace_ops_in_indices = true) == str

        str = "arr[(a + b):c]"
        @test fmt("arr[(a+b):c]", m = 1, whitespace_ops_in_indices = true) == str

        str = "arr[a in b]"
        @test fmt(str, m = 1, whitespace_ops_in_indices = true) == str

        str_ = "a:b+c:d-e"
        str = "a:(b + c):(d - e)"
        @test fmt(str_, m = 1, whitespace_ops_in_indices = true) == str

        # issue 180
        str_ = "s[m+i+1]"
        str = "s[m+i+1]"
        @test fmt(str, m = 1) == str

        str = "s[m + i + 1]"
        @test fmt(str_, m = 1, whitespace_ops_in_indices = true) == str
    end

    @testset "rewrite import to using" begin
        str_ = "import A"
        str = "using A: A"
        @test fmt(str_, import_to_using = true) == str

        str_ = """
        import A,

        B, C"""
        str = """
        using A: A
        using B: B
        using C: C"""
        @test_broken fmt(str_, import_to_using = true) == str

        str_ = """
        import A,
               # comment
        B, C"""
        str = """
        using A: A
        # comment
        using B: B
        using C: C"""
        @test fmt(str_, import_to_using = true) == str

        str_ = """
        import A, # inline
               # comment
        B, C # inline"""
        str = """
        using A: A # inline
        # comment
        using B: B
        using C: C # inline"""
        @test fmt(str_, import_to_using = true) == str

        str_ = """
        import ..A, .B, ...C"""
        str = """
        using ..A: A
        using .B: B
        using ...C: C"""
        @test fmt(str_, import_to_using = true) == str
        t = run_pretty(str_, 80, opts = Options(import_to_using = true))
        @test t.len == 13
    end

    @testset "always convert `=` to `in` (for loops)" begin
        str_ = """
        for i = 1:n
            println(i)
        end"""
        str = """
        for i in 1:n
            println(i)
        end"""
        @test fmt(str_, always_for_in = true) == str
        @test fmt(str, always_for_in = true) == str

        str_ = """
        for i = I1, j in I2
            println(i, j)
        end"""
        str = """
        for i in I1, j in I2
            println(i, j)
        end"""
        @test fmt(str_, always_for_in = true) == str
        @test fmt(str, always_for_in = true) == str

        str_ = """
        for i = 1:30, j = 100:-2:1
            println(i, j)
        end"""
        str = """
        for i in 1:30, j in 100:-2:1
            println(i, j)
        end"""
        @test fmt(str_, always_for_in = true) == str
        @test fmt(str, always_for_in = true) == str

        str_ = "[(i,j) for i=I1,j=I2]"
        str = "[(i, j) for i in I1, j in I2]"
        @test fmt(str_, always_for_in = true) == str
        @test fmt(str, always_for_in = true) == str

        str_ = "((i,j) for i=I1,j=I2)"
        str = "((i, j) for i in I1, j in I2)"
        @test fmt(str_, always_for_in = true) == str
        @test fmt(str, always_for_in = true) == str

        str_ = "[(i, j) for i = 1:2:10, j = 100:-1:10]"
        str = "[(i, j) for i in 1:2:10, j in 100:-1:10]"
        @test fmt(str_, always_for_in = true) == str
        @test fmt(str, always_for_in = true) == str
    end

    @testset "rewrite x |> f to f(x)" begin
        @test fmt("x |> f", pipe_to_function_call = true) == "f(x)"

        str_ = "var = func1(arg1) |> func2 |> func3 |> func4 |> func5"
        str = "var = func5(func4(func3(func2(func1(arg1)))))"
        @test fmt(str_, pipe_to_function_call = true) == str
        @test fmt(str_, pipe_to_function_call = true, margin = 1) == fmt(str)
    end

    @testset "function shortdef to longdef" begin
        str_ = "foo(a) = bodybodybody"
        str = """
        function foo(a)
            bodybodybody
        end"""
        @test fmt(str_, 4, length(str_), short_to_long_function_def = true) == str_
        @test fmt(str_, 4, length(str_) - 1, short_to_long_function_def = true) == str

        # t, _ = run_nest(str_, length(str_)-1, style=YASStyle())
        # @test length(t) == 15

        str_ = "foo(a::T) where {T} = bodybodybodybodybodybodyb"
        str = """
        function foo(a::T) where {T}
            bodybodybodybodybodybodyb
        end"""
        @test fmt(str_, 4, length(str_), short_to_long_function_def = true) == str_
        @test fmt(str_, 4, length(str_) - 1, short_to_long_function_def = true) == str

        str_ = "foo(a::T)::R where {T} = bodybodybodybodybodybodybody"
        str = """
        function foo(a::T)::R where {T}
            bodybodybodybodybodybodybody
        end"""
        @test fmt(str_, 4, length(str_), short_to_long_function_def = true) == str_
        @test fmt(str_, 4, length(str_) - 1, short_to_long_function_def = true) == str
    end

end

yasfmt1(s, i, m; kwargs...) = fmt1(s; kwargs..., i = i, m = m, style = YASStyle())
yasfmt(s, i, m; kwargs...) = fmt(s; kwargs..., i = i, m = m, style = YASStyle())

@testset "YAS alignment" begin
    @testset "basic" begin
        str_ = "foo(; k =v)"
        str = "foo(; k=v)"
        @test yasfmt(str_, 4, 80) == str

        str_ = "a = (arg1, arg2, arg3)"
        str = """
        a = (arg1, arg2,
             arg3)"""
        @test yasfmt(str_, 4, length(str_) - 1) == str
        @test yasfmt(str_, 4, 16) == str

        str = """
        a = (arg1,
             arg2,
             arg3)"""
        @test yasfmt(str_, 4, 15) == str
        @test yasfmt(str_, 4, 1) == str

        str_ = "a = [arg1, arg2, arg3]"
        str = """
        a = [arg1, arg2,
             arg3]"""
        @test yasfmt(str_, 4, length(str_) - 1) == str
        @test yasfmt(str_, 4, 16) == str

        str = """
        a = [arg1,
             arg2,
             arg3]"""
        @test yasfmt(str_, 4, 15) == str
        @test yasfmt(str_, 4, 1) == str

        str_ = "a = {arg1, arg2, arg3}"
        str = """
        a = {arg1,arg2,arg3}"""
        @test yasfmt(str_, 4, 20) == str

        str = """
        a = {arg1,arg2,
             arg3}"""
        @test yasfmt(str_, 4, 19) == str
        @test yasfmt(str_, 4, 15) == str

        str = """
        a = {arg1,
             arg2,
             arg3}"""
        @test yasfmt(str_, 4, 14) == str
        @test yasfmt(str_, 4, 1) == str

        str_ = "a = Union{arg1, arg2, arg3}"
        str = """
        a = Union{arg1,arg2,arg3}"""
        @test yasfmt(str_, 4, 25) == str

        str = """
        a = Union{arg1,arg2,
                  arg3}"""
        @test yasfmt(str_, 4, 24) == str
        @test yasfmt(str_, 4, 20) == str

        str = """
        a = Union{arg1,
                  arg2,
                  arg3}"""
        @test yasfmt(str_, 4, 19) == str
        @test yasfmt(str_, 4, 1) == str

        str_ = "a = fcall(arg1,arg2,arg3)"
        str = """
        a = fcall(arg1, arg2, arg3)"""
        @test yasfmt(str_, 4, length(str)) == str

        str = """
        a = fcall(arg1, arg2,
                  arg3)"""
        @test yasfmt(str_, 4, 26) == str
        @test yasfmt(str_, 4, 21) == str

        str = """
        a = fcall(arg1,
                  arg2,
                  arg3)"""
        @test yasfmt(str_, 4, 20) == str
        @test yasfmt(str_, 4, 1) == str

        str_ = "a = @call(arg1,arg2,arg3)"
        str = """
        a = @call(arg1, arg2, arg3)"""
        @test yasfmt(str_, 4, length(str)) == str

        str = """
        a = @call(arg1, arg2,
                  arg3)"""
        @test yasfmt(str_, 4, 26) == str
        @test yasfmt(str_, 4, 21) == str

        str = """
        a = @call(arg1,
                  arg2,
                  arg3)"""
        @test yasfmt(str_, 4, 20) == str
        @test yasfmt(str_, 4, 1) == str

        str_ = "a = array[arg1,arg2,arg3]"
        str = """
        a = array[arg1, arg2, arg3]"""
        @test yasfmt(str_, 4, length(str)) == str

        str = """
        a = array[arg1, arg2,
                  arg3]"""
        @test yasfmt(str_, 4, 26) == str
        @test yasfmt(str_, 4, 21) == str

        str = """
        a = array[arg1,
                  arg2,
                  arg3]"""
        @test yasfmt(str_, 4, 20) == str
        @test yasfmt(str_, 4, 1) == str

    end

    # more complicated samples
    @testset "pretty" begin
        str_ = "comp = [a * b for a in 1:10, b in 11:20]"
        str = """
        comp = [a * b
                for a in 1:10, b in 11:20]"""
        @test yasfmt(str_, 2, length(str_) - 1, always_for_in = true) == str
        @test yasfmt(str_, 2, 34, always_for_in = true) == str

        str = """
        comp = [a * b
                for a in 1:10,
                    b in 11:20]"""
        @test yasfmt(str_, 2, 33, always_for_in = true) == str

        str = """
        comp = [a *
                b
                for a in
                    1:10,
                    b in
                    11:20]"""
        @test yasfmt(str_, 2, 1, always_for_in = true) == str

        str_ = "comp = Typed[a * b for a in 1:10, b in 11:20]"
        str = """
        comp = Typed[a * b
                     for a in 1:10, b in 11:20]"""
        @test yasfmt(str_, 2, length(str_) - 1, always_for_in = true) == str
        @test yasfmt(str_, 2, 39, always_for_in = true) == str

        str = """
        comp = Typed[a * b
                     for a in 1:10,
                         b in 11:20]"""
        @test yasfmt(str_, 2, 38, always_for_in = true) == str

        str = """
        comp = Typed[a *
                     b
                     for a in
                         1:10,
                         b in
                         11:20]"""
        @test yasfmt(str_, 2, 1, always_for_in = true) == str

        str_ = "foo(arg1, arg2, arg3) == bar(arg1, arg2, arg3)"
        str = """
        foo(arg1, arg2, arg3) ==
        bar(arg1, arg2, arg3)"""
        @test yasfmt(str, 2, length(str_)) == str_
        @test yasfmt(str_, 2, length(str_) - 1) == str
        @test yasfmt(str_, 2, 24) == str

        str = """
        foo(arg1, arg2,
            arg3) ==
        bar(arg1, arg2, arg3)"""
        @test yasfmt(str_, 2, 23) == str
        @test yasfmt(str_, 2, 21) == str

        str = """
        foo(arg1, arg2,
            arg3) ==
        bar(arg1, arg2,
            arg3)"""
        @test yasfmt(str_, 2, 20) == str
        @test yasfmt(str_, 2, 15) == str

        str = """
        foo(arg1,
            arg2,
            arg3) ==
        bar(arg1,
            arg2,
            arg3)"""
        @test yasfmt(str_, 2, 14) == str
        @test yasfmt(str_, 2, 1) == str

        str_ = """
        function func(arg1::Type1, arg2::Type2, arg3) where {Type1,Type2}
          body
        end"""
        str = """
        function func(arg1::Type1, arg2::Type2,
                      arg3) where {Type1,Type2}
          body
        end"""
        @test yasfmt(str_, 2, 64) == str
        @test yasfmt(str_, 2, 39) == str

        str = """
        function func(arg1::Type1,
                      arg2::Type2,
                      arg3) where {Type1,
                                   Type2}
          body
        end"""
        @test yasfmt(str_, 2, 31) == str
        @test yasfmt(str_, 2, 1) == str

        str_ = """
        @test TimeSpan(spike_annotation) == TimeSpan(first(spike_annotation), last(spike_annotation))"""
        str = """
        @test TimeSpan(spike_annotation) ==
              TimeSpan(first(spike_annotation), last(spike_annotation))"""
        @test yasfmt(str_, 4, length(str_) - 1) == str
        @test yasfmt(str_, 4, 63) == str
        str_ = """
        @test TimeSpan(spike_annotation) == TimeSpan(first(spike_annotation), last(spike_annotation))"""
        str = """
        @test TimeSpan(spike_annotation) ==
              TimeSpan(first(spike_annotation),
                       last(spike_annotation))"""
        @test yasfmt(str_, 4, 62) == str


        str_ = raw"""ecg_signal = signal_from_template(eeg_signal; channel_names=[:avl, :avr], file_extension=Symbol("lpcm.zst"))"""
        str = raw"""
        ecg_signal = signal_from_template(eeg_signal; channel_names=[:avl, :avr],
                                          file_extension=Symbol("lpcm.zst"))"""
        @test yasfmt(str_, 4, length(str_) - 1) == str
        @test yasfmt(str_, 4, 73) == str

        str = raw"""
        ecg_signal = signal_from_template(eeg_signal;
                                          channel_names=[:avl, :avr],
                                          file_extension=Symbol("lpcm.zst"))"""
        @test yasfmt(str_, 4, 72) == str
        str = raw"""
        ecg_signal = signal_from_template(eeg_signal;
                                          channel_names=[:avl,
                                                         :avr],
                                          file_extension=Symbol("lpcm.zst"))"""
        @test yasfmt(str_, 4, 1) == str


    end

    @testset "inline comments with arguments" begin
        str_ = """
        var = fcall(arg1,
            arg2, arg3, # comment
                            arg4, arg5)"""
        str = """
        var = fcall(arg1, arg2, arg3, # comment
                    arg4, arg5)"""
        @test yasfmt(str_, 4, 80) == str
        @test yasfmt(str_, 4, 29) == str

        str = """
        var = fcall(arg1, arg2,
                    arg3, # comment
                    arg4, arg5)"""
        @test yasfmt(str_, 4, 28) == str
        @test yasfmt(str_, 4, 23) == str

        str = """
        var = fcall(arg1,
                    arg2,
                    arg3, # comment
                    arg4,
                    arg5)"""
        @test yasfmt(str_, 4, 22) == str
        @test yasfmt(str_, 4, 1) == str

        str_ = """
        comp = [
        begin
                    x = a * b + c
                    y = x^2 + 3x # comment 1
            end
                       for a in 1:10,  # comment 2
                    b in 11:20,
           c in 300:400]"""

        str = """
        comp = [begin
                  x = a * b + c
                  y = x^2 + 3x # comment 1
                end
                for a = 1:10,  # comment 2
                    b = 11:20, c = 300:400]"""
        @test yasfmt(str_, 2, 80) == str
        @test yasfmt(str_, 2, 35) == str

        str = """
        comp = [begin
                  x = a * b + c
                  y = x^2 + 3x # comment 1
                end
                for a = 1:10,  # comment 2
                    b = 11:20,
                    c = 300:400]"""
        @test yasfmt(str_, 2, 34) == str

        str_ = """
        ys = ( if p1(x)
                 f1(x)
        elseif p2(x)
            f2(x)
        else
            f3(x)
        end for    x in xs)
        """
        str = """
        ys = (if p1(x)
                f1(x)
              elseif p2(x)
                f2(x)
              else
                f3(x)
              end
              for x in xs)
        """
        @test yasfmt(str_,2,80) == str

    end

    @testset "inline comments with arguments" begin
        # parsing error is newline is placed front of `for` here
        str_ = "var = (x, y) for x = 1:10, y = 1:10"
        str = """
        var = (x, y) for x = 1:10,
                         y = 1:10"""
        @test yasfmt(str_, 4, length(str_) - 1) == str
    end

    @testset "invisbrackets" begin
        str_ = """
        if ((
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
        ))
          nothing
        end"""
        str = """
        if ((aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
             aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ||
             aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa))
          nothing
        end"""
        @test yasfmt(str_, 2, 92) == str
    end

    @testset "#189" begin
        str_ = """
    D2 = [
            (b_hat * y - delta_hat[i] * y) * gamma[i] + (b * y_hat - delta[i] * y_hat) *
                                                            gamma_hat[i] + (b_hat - y_hat) *
                                                                           delta[i] + (b - y) *
                                                                                      delta_hat[i] - delta[i] * delta_hat[i]
            for i = 1:8
        ]"""
        str = """
        D2 = [(b_hat * y - delta_hat[i] * y) * gamma[i] +
              (b * y_hat - delta[i] * y_hat) * gamma_hat[i] +
              (b_hat - y_hat) * delta[i] +
              (b - y) * delta_hat[i] - delta[i] * delta_hat[i]
              for i = 1:8]"""
        @test yasfmt(str_,2,60) == str

    end

end

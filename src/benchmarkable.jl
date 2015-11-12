# The @benchmarkable macro combines a tuple of expressions into a function
# that implements the "benchmarkable" protocol. We assume that precompilation,
# when required, will be handled elsewhere; as such, we make no extra calls to
# the core expression that we want to benchmark.
#
# Arguments:
#
#     name: The name of the function that will be generated.
#
#     setup: An expression that will be executed before the core
#         expression starts executing.
#
#     core: The core expression that will be executed.
#
#     teardown: An expression that will be executed after the core
#         expression finishes executing.
#
# Generates:
#
#     A function expression that defines a new function of three-arguments,
#     which are:
#
#     (1): s::Samples: A Samples object in which benchmark data will be stored.
#
#     (2): n_samples::Integer: The number of samples that will be gathered.
#
#     (3): n_evals::Integer: The number of times the core expression will be
#         evaluated per sample.

macro benchmarkable(name, setup, core, teardown)
    # We only support function calls to be passed in `core`, but some syntaxes
    # have special parsing that will lower to a function call upon expansion
    # (e.g., A[i] or user macros). The tricky thing is that keyword functions
    # *also* have a special lowering step that we don't want (they are harder to
    # work with and would obscure some of the overhead of keyword arguments). So
    # we only expand the passed expression if it is not already a function call.
    expr = (core.head == :call) ? core : expand(core)
    expr.head == :call || throw(ArgumentError("expression to benchmark must be a function call"))
    f = expr.args[1]
    fargs = expr.args[2:end]
    nargs = length(expr.args)-1

    # Pull out the arguments -- both positional and keywords
    userargs = Any[]  # The actual expressions the user wrote
    args = Symbol[gensym("arg_$i") for i in 1:nargs] # The local argument names
    posargs = Symbol[] # The names that are positional arguments
    kws = Expr[]       # Names that are used in keyword arguments
    for i in 1:nargs
        if isa(fargs[i], Expr) && fargs[i].head == :kw
            push!(kws, Expr(:kw, fargs[i].args[1], args[i]))
            push!(userargs, fargs[i].args[2])
        else
            push!(posargs, args[i])
            push!(userargs, fargs[i])
        end
    end

    benchfn = gensym("bench")
    innerfn = gensym("inner")

    # Strategy: we create *three* functions:
    # * The outermost function is the entry point. It's simply a closure around
    #   the expressions the user passed in `core` as the arguments to the
    #   benchmarked function. This allows the arguments to be considered setup,
    #   which are evaluated in the correct scope. However, that means that
    #   within this outermost function, the arguments probably aren't
    #   concretely typed. This means that if we were to run the benchmarking
    #   function in this outermost function, we'd end up benchmarking dynamic
    #   dispatch most of the time.  So we introduce a function barrier here.
    # * The second level (`benchfn`) is the benchmarking loop.  Here is where
    #   the real work gets done.  However, if we were to call the benchmarked
    #   function directly here, it might get inlined.  And if it gets inlined,
    #   then LLVM can use optimizations that interact with the test loop itself.
    #   No longer are we simply testing the benchmarked function; we are testing
    #   the benchmark loops.  So in order to circumvent this, we introduce a
    #   third function that is explicitly marked `@noinline`
    # * It is within this third, `inner` function that we call the user's
    #   function that they want to benchmark. This means that all timings will
    #   include the overhead of at least one function call. But it also means
    #   that we can prevent LLVM from doing optimizations that are related to
    #   the benchmarking itself: it must always call the inner function in the
    #   benchmarking function (since at the mid-level it doesn't know what that
    #   function might do), and within the inner function it can only eliminate
    #   code that's unrelated to the return value (since it doesn't know what
    #   the caller might do).
    quote
        function $(esc(name))(
                s::Samples,
                n_samples::Integer,
                evaluations::Integer,
            )
            $(benchfn)(s, n_samples, evaluations, $(map(esc, userargs)...))
        end
        function $(benchfn)(
                s::Samples,
                n_samples::Integer,
                evaluations::Integer,
                $(args...)
            )
            # Execute the setup expression exactly once
            $(esc(setup))

            # Generate n_samples by evaluating the core
            for _ in 1:n_samples
                # Store pre-evaluation state information
                stats = Base.gc_num()
                time_before = time_ns()

                # Evaluate the core expression n_evals times.
                for _ in 1:evaluations
                    out = $(innerfn)($(args...))
                end

                # get time before comparing GC info
                elapsed_time = time_ns() - time_before

                # Compare post-evaluation state with pre-evaluation state.
                diff = Base.GC_Diff(Base.gc_num(), stats)
                bytes = diff.allocd
                allocs = diff.malloc + diff.realloc + diff.poolalloc + diff.bigalloc
                gc_time = diff.total_time

                # Append data for this sample to the Samples objects.
                push!(s, evaluations, elapsed_time, gc_time, bytes, allocs)
            end

            # Execute the teardown expression exactly once
            $(esc(teardown))

            # The caller receives all data via the mutated Results object.
            return
        end
        @noinline function $(innerfn)($(map(esc, args)...))
            $(esc(f))($(map(esc, posargs)...), $(map(esc, kws)...))
        end

        # "return" the outermost entry point as the final expression
        $(esc(name))
    end
end

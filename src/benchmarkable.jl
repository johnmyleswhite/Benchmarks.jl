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

# recursively add non-constant symbols in module m to a list
find_nonconsts(m, x::Any, list) = list
find_nonconsts(m, s::Symbol, list) = isconst(m, s) ? list : push!(list, s)
function find_nonconsts(m, e::Expr, list)
    e.head == :line && return # skip line nodes
    map(a->find_nonconsts(m,a,list), e.args)
    list
end

macro benchmarkable(name, setup, core, teardown)
    inner = gensym(:inner)
    # Go through the passed core expression and determine non-constant bindings
    nonconst = unique(find_nonconsts(current_module(), core, Symbol[]))
    # We assign these non-const bindings to a local constant binding
    # in order to ensure we aren't timing untyped dispatch lookup
    nonconst_locals = map(gensym, nonconst)
    decls = Expr(:block, map((r,s)->:(const $r = $(esc(s))), nonconst_locals, nonconst)...)
    quote
        @noinline function $(inner)($(map(esc, nonconst)...))
            $(esc(core))
        end
        $decls
        function $(esc(name))(
                s::Samples,
                n_samples::Integer,
                evaluations::Integer,
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
                    out = $(inner)($(nonconst_locals...))
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
    end
end

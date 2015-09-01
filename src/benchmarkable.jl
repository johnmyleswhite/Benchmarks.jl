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
    quote
        function $(esc(name))(s::Samples, n_samples::Integer, n_evals::Integer)
            # Execute the setup expression exactly once
            $(esc(setup))

            # Generate n_samples by evaluating the core
            for _ in 1:n_samples
                # Store pre-evaluation state information
                stats = Base.gc_num()
                time_before = time_ns()

                # Evaluate the core expression n_evals times.
                for _ in 1:n_evals
                    out = $(esc(core))
                end

                # get time before comparing GC info
                elapsed_time = time_ns() - time_before

                # Compare post-evaluation state with pre-evaluation state.
                diff = Base.GC_Diff(Base.gc_num(), stats)
                bytes = diff.allocd
                allocs = diff.malloc + diff.realloc + diff.poolalloc + diff.bigalloc

                # Append data for this sample to the Samples objects.
                push!(s.n_evals, n_evals)
                push!(s.elapsed_times, elapsed_time)
                push!(s.bytes_allocated, bytes)
                push!(s.gc_times, diff.total_time)
                push!(s.num_allocations, allocs)
            end

            # Execute the teardown expression exactly once
            $(esc(teardown))

            # The caller receives all data via the mutated Results object.
            return
        end
    end
end

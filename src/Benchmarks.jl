# We stop if:
#
# * We accumulate enough samples
# * We use up our time budget
# * We find that the linear model of time almost perfectly fits the data
module Benchmarks
    # We assign every benchmarking session a unique UUID for logging.
    import UUID

    # Estimate the best-case resolution of benchmark timings based on the
    # system clock in nanoseconds.
    function estimate_clock_resolution(n_samples::Integer = 10_000)
        t = typemax(Float64)

        for s in 1:n_samples
            t1 = Base.time_ns()
            t2 = Base.time_ns()
            t = min(t, convert(Float64, t2 - t1))
        end

        t
    end

    # A Plan object consists of:
    #
    # * The number of times the core expression will be executed to generate a
    #   single sample.
    # * The number of samples that will be gathered for downstream statistical
    #   analysis.
    immutable Plan
        n_calls::Int
        n_samples::Int
    end

    # A Samples object contains four equal lengths vector that contain:
    #
    # * The elapsed time in nanoseconds for every sample.
    # * The total number of bytes allocated for every sample.
    # * The elapsed GC in nanoseconds for every sample.
    # * The total number of allocation operations for every sample.
    immutable Samples
        elapsed_times::Vector{Float64}
        bytes_allocated::Vector{Int}
        gc_times::Vector{Float64}
        num_allocations::Vector{Int}
    end

    # We construct a Samples object based on a Plan object by allocating arrays
    # to store information about every sample.
    function Samples(p::Plan)
        Samples(
            Array(Float64, p.n_samples),
            Array(Int, p.n_samples),
            Array(Float64, p.n_samples),
            Array(Int, p.n_samples),
        )
    end

    # An Environment object stores information about the environment in which
    # a suite of benchmarks were executed. We log information about:
    #
    # * A random UUID to uniquely identify each run.
    # * The time when a suite began executing.
    # * The SHA1 for the Julia Git revision we're working from.
    # * The SHA1 for the repo's current Git revision.
    # * The OS we're operating under.
    # * The number of CPU cores available.
    # * The architecture we're operating under.
    # * Was BLAS configured to use 64-bits?
    # * The word size of the host machine.
    immutable Environment
        uuid::UTF8String
        timestamp::UTF8String
        julia_sha1::UTF8String
        repo_sha1::Nullable{UTF8String}
        os::UTF8String
        cpu_cores::Int
        arch::UTF8String
        machine::UTF8String
        use_blas64::Bool
        word_size::Int

        function Environment()
            uuid = string(UUID.v4())
            timestamp = Libc.strftime("%Y-%m-%d %H:%M:%S", round(Int, time()))
            julia_sha1 = Base.GIT_VERSION_INFO.commit
            repo_sha1 = if isdir(".git")
                sha1 = ""
                try
                    sha1 = readchomp(`git rev-parse HEAD`)
                end
                if isempty(sha1)
                    Nullable{UTF8String}()
                else
                    Nullable{UTF8String}(utf8(sha1))
                end
            else
                Nullable{UTF8String}()
            end
            os = string(OS_NAME)
            cpu_cores = CPU_CORES
            arch = string(Base.ARCH)
            machine = Base.MACHINE
            use_blas64 = Base.USE_BLAS64
            word_size = Base.WORD_SIZE

            new(
                uuid,
                timestamp,
                julia_sha1,
                repo_sha1,
                os,
                cpu_cores,
                arch,
                machine,
                use_blas64,
                word_size,
            )
        end
    end

    # A Benchmark object contains:
    #
    # * A name.
    # * A function that implements the "benchmarkable" protocol.
    # * A Plan that determines the execution of the "benchmarkable" function.
    # * A Samples object to store the results of benchmarking the function.
    immutable Benchmark
        name::UTF8String
        f!::Function
        plan::Plan
        samples::Samples
    end

    # A benchmark suite consists of:
    #
    # * A category name.
    # * A vector of benchmarks.
    immutable Suite
        category_name::UTF8String
        benchmarks::Vector{Benchmark}
    end

    # Combine a set of expressions into a function that implements the
    # "benchmarkable" protocol. We assume that precompilation, when
    # appropriate, will be handled elsewhere.
    #
    # Arguments:
    #
    #     name: The name of the resulting function.
    #
    #     setup: An expression that will be executed before the core
    #         expression starts executing.
    #
    #     body: The core expression that will be timed.
    #
    #     teardown: An expression that will be executed after the core
    #         expression.
    macro benchmarkable(name, setup, body, teardown)
        quote
            function $(esc(name))(p::Plan, s::Samples)
                $(esc(setup))

                for sample in 1:p.n_samples
                    stats = Base.gc_num()
                    elapsed_time = time_ns()

                    for c in 1:p.n_calls
                        out = $(esc(body))
                    end

                    diff = Base.GC_Diff(Base.gc_num(), stats)
                    bytes = diff.total_allocd + diff.allocd
                    allocs = diff.malloc + diff.realloc + diff.poolalloc

                    s.elapsed_times[sample] = time_ns() - elapsed_time
                    s.bytes_allocated[sample] = bytes
                    s.gc_times[sample] = diff.total_time
                    s.num_allocations[sample] = allocs
                end

                $(esc(teardown))

                return
            end
        end
    end

    # Execute a "benchmarkable" function using an increasing number of calls
    # per sample. The use of multiple calls per samples allows us to ensure
    # that microbenchmarks, which may run faster than the system clock can
    # track, are executed enough times per sample to yield unbiased estimates
    # of the per-call time cost of the expression.
    #
    # Arguments:
    #
    #     f!: A benchmarkable function
    #
    #     budget: The maximum amount of time in seconds we want to spend running
    #         this specific benchmark. Defaults to 5 minutes.
    #
    #     limit: The longest time in seconds we are willing to spend on
    #        executing a single call.
    function execute(
            f!::Function,
            requested_samples::Integer = 100,
            budget::Integer = 60,
            τ::Float64 = 0.95,
            α::Float64 = 1.1,
            x_samples::Integer = 250,
            verbose::Bool = true,
        )
        # Convert our time budget to nanoseconds.
        budget_ns = 10^9 * budget

        # Record the total amount of time we spend running this benchmark.
        cumulative_time_ns = 0.0
        cumulative_samples = 0

        # Run the "benchmarkable" function at least once.
        p = Plan(1, 1)
        s = Samples(p)
        f!(p, s)

        # Estimate the elapsed time for the very first call, which may be
        # biased upwards because the time includes JIT compilation time.
        initial_time_ns = s.elapsed_times[1]

        # Increment the total amount of time we've spent benchmarking.
        cumulative_time_ns += initial_time_ns
        cumulative_samples += 1

        # We stop benchmarking f! if we've already exhausted our sample or time
        # budget.
        if cumulative_time_ns > budget_ns || requested_samples == 1
            # TODO: Return a Result object.
            return p, s, Float64[], Float64[]
        end

        # We determine the maximum number of samples we could record given
        # our time budget.
        max_samples = floor(Integer, budget_ns / initial_time_ns)

        # We stop benchmarking if running f! one more time would put us over
        # our time budget.
        if max_samples <= 1
            # TODO: Return a Result object.
            return p, s, Float64[], Float64[]
        end

        # Having reached here, we can afford to record multiple samples without
        # using up our time budget. The core question now is:
        #
        # * Is the function being measured so fast that a single sample needs
        #   to include multiple calls before our samples can provide unbiased
        #   estimates of the execution time?
        #
        # To determine this, we first execute f! one more time. This provides
        # our first reliable estimate of the execution time without any
        # possible compilation costs.
        p = Plan(1, 1)
        s = Samples(p)
        f!(p, s)

        # We increment our total time spent benchmarking.
        unbiased_time_ns = s.elapsed_times[1]
        cumulative_time_ns += unbiased_time_ns

        # If we've used up our sample budget or time budget, we stop.
        cumulative_samples = 1
        if cumulative_time_ns > budget_ns || requested_samples == 2
            # TODO: Return a Result object.
            return p, s, Float64[], Float64[]
        end

        # We recompute the maximum number of samples we could record given
        # our time budget.
        max_samples = floor(Integer, budget_ns / unbiased_time_ns)

        # Now we either:
        #
        # * Execute all of the samples requested by the user.
        # * Execute as many calls as we can without using up our time budget.
        # * Execute as many calls as needed for OLS to converge.
        if unbiased_time_ns > 1_000 * estimate_clock_resolution()
            n_samples = min(max_samples, requested_samples)
            p = Plan(1, n_samples)
            s = Samples(p)
            f!(p, s)
            # TODO: Return a Result object
            return p, s, Float64[], Float64[]
        end

        # If we've reached this point, we have ample time budget and need to
        # measure a very fast function. Because f! is fast enough that the
        # system clock resolution is
        # a problem for us, we'll go a geometric search through execution plans
        # to ensure that our estimates aren't severely biased by the clock's
        # resolution. To do that, we'll use an OLS regression in which we
        # regress the total sample time against the number of calls per sample.
        # When the linear model is almost a perfect fit to the data, we're
        # confident that we're getting good timings.
        x = Float64[]
        y = Float64[]

        # We start by executing two calls per sample.
        n_calls = 2.0

        # Loop through a geometrically increasing set of values for n_calls
        # before we decide that we've done enough work.
        finished = false
        a, b = NaN, NaN
        while !finished
            # Gather many samples.
            p = Benchmarks.Plan(ceil(Integer, n_calls), x_samples)
            s = Benchmarks.Samples(p)
            f!(p, s)

            # We augment our cumulative use of our time budget.
            cumulative_time_ns += sum(s.elapsed_times)

            # Add the new timing observations to our accumulated data set.
            for i in 1:length(s.elapsed_times)
                push!(x, n_calls)
            end
            append!(y, s.elapsed_times)

            # Perform an OLS regression to estimate the per-call time.
            a, b = linreg(x, y)
            r_squared = 1 - var(a + b * x - y) / var(y)

            # If desired, print out information about progress.
            if verbose
                @printf("%f,%f,%f,%f\n", n_calls, a, b, r_squared)
            end

            # Abort when appropriate.
            if r_squared > τ || cumulative_time_ns > budget_ns
                finished = true
            end

            # Increase the number of calls per sample we use in the next step.
            n_calls *= α
        end

        if verbose
            writecsv("sin_benchmark.csv", hcat(x, y))
        end

        return p, s, x, y
    end

    function summarize(p, r)
        m = mean(r.elapsed_times ./ p.n_calls)
        sem = std(r.elapsed_times ./ p.n_calls) / sqrt(p.n_samples)
        lower, upper = m - 1.96 * sem, m + 1.96 * sem
        @printf(
            "CI = [%.2f ns, %.2f ns]\n",
            lower,
            upper,
        )
    end
end

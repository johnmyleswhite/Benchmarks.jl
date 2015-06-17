module Benchmarks
    # We assign every benchmarking session a random UUID
    import UUID

    # Estimate the best-case resolution of benchmark timings based on the system
    # clock in nanoseconds.
    function estimate_clock_resolution(n_samples::Integer = 10_000)
        t = typemax(Float64)

        for s in 1:n_samples
            t1 = Base.time_ns()
            t2 = Base.time_ns()
            t = min(t, convert(Float64, t2 - t1))
        end

        return t
    end

    # A plan consists of:
    # * The number of times the core expression will be executed to generate a
    #   single sample.
    # * The number of samples that will be gathered for downstream statistical
    #   analysis.
    immutable Plan
        n_calls::Int
        n_samples::Int
    end

    # We store:
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

    # We construct a Samples object based on a plan by allocating arrays
    # to store information about every sample.
    function Samples(p::Plan)
        Samples(
            Array(Float64, p.n_samples),
            Array(Int, p.n_samples),
            Array(Float64, p.n_samples),
            Array(Int, p.n_samples),
        )
    end

    # We resize an existing Samples object by resizing every internal
    # array.
    function Base.resize!(s::Samples, p::Plan)
        resize!(s.elapsed_times, p.n_samples)
        resize!(s.bytes_allocated, p.n_samples)
        resize!(s.gc_times, p.n_samples)
        resize!(s.num_allocations, p.n_samples)
        return
    end

    # We store information about the environment in which our benchmarks
    # were executed. For now, this consists of:
    #
    # * A random UUID to uniquely identify each run
    # * The time when a suite began executing
    # * The SHA1 for the Julia Git revision we're working from
    # * The SHA1 for the repo's current Git revision
    # * The OS we're operating under
    # * The number of CPU cores available
    # * The architecture we're operating under
    # * Was BLAS configured to use 64-bits?
    # * The word size of the host machine
    immutable Environment
        uuid::UTF8String
        timestamp::UTF8String
        julia_sha1::UTF8String
        repo_sha1::Nullable{UTF8String}
        os::UTF8String
        cpu_cores::Int
        arch::UTF8String
        use_blas64::Bool
        word_size::Int

        function Environment()
            uuid = UUID.v4()
            timestamp = Libc.strftime("%Y-%m-%d %H:%M:%S", round(Int, time()))
            julia_revision = Base.GIT_VERSION_INFO.commit
            repo_revision = if isdir(".git")
                sha1 = ""
                try
                    sha1 = readchomp(`git rev-parse HEAD`)
                end
                if isempty(sha1)
                    Nullable{UTF8String}()
                else
                    Nullable{UTF8String}(sha1)
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
                string(uuid),
                timestamp,
                julia_revision,
                repo_revision,
                os,
                cpu_cores,
                arch,
                machine,
                use_blas64,
                word_size,
            )
        end
    end

    # A benchmark consists of:
    # * A name
    # * A function that implements the "benchmarkable" protocol
    # * A plan that determines the execution of the Benchmarkable function
    # * A samples array to store the results of benchmarking the function
    immutable Benchmark
        name::UTF8String
        f!::Function
        plan::Plan
        samples::Samples
    end

    # A suite consists of:
    # * A category name
    # * A vector of benchmarks.
    immutable Suite
        category_name::UTF8String
        benchmarks::Vector{Benchmark}
    end

    # Translate a set of expressions into a function that implements the
    # "benchmarkable" protocol. We assume that precompilation, when
    # appropriate, will be handled elsewhere.
    macro benchmarkable(name, setup, body, teardown)
        quote
            function $(esc(name))(p::Plan, s::Samples)
                $(esc(setup))
                for sample in 1:p.n_samples
                    stats = Base.gc_num()
                    elapsedtime = time_ns()
                    for c in 1:p.n_calls
                        out = $(esc(body))
                    end
                    diff = Base.GC_Diff(Base.gc_num(), stats)
                    bytes = diff.total_allocd + diff.allocd
                    allocs = diff.malloc + diff.realloc + diff.poolalloc
                    s.elapsed_times[sample] = time_ns() - elapsedtime
                    s.bytes_allocated[sample] = bytes
                    s.gc_times[sample] = diff.total_time
                    s.num_allocations[sample] = allocs
                end
                $(esc(teardown))
                return
            end
        end
    end

    # Execute a benchmarkable function using an increasing number of calls per
    # sample. This allows to ensure that microbenchmarks, which may run faster
    # than the system clock can track, are executed enough times per sample to
    # yield valid estimates.
    # TODO: Specify a time budget?
    # TODO: Execute function exactly once if the initial execution (which may
    #       involve compilation) takes longer than a fixed time limit.
    function execute(
            f!::Function,
            limit::Integer = 60,
            τ::Float64 = 0.95,
            α::Float64 = 1.1,
            x_samples::Integer = 250,
            verbose::Bool = true,
        )
        # Start by measuring time using a (1, 1) sampling plan
        p = Plan(1, 1)
        s = Samples(p)

        # Run the benchmarkable function at least once
        f!(p, s)

        # Estimate the elapsed time for the very first call, which may include
        # JIT compilation time
        initial_time = s.elapsed_times[1]

        # If the initial time estimate is longer than our limit, we won't ever
        # run the function again.
        if initial_time > 10^9 * limit
            return p, s, Float64[], Float64[]
        end

        # If the function was fast enough that we're willing to run it again,
        # we do run it again to generate a timing estimate that won't include
        # any JIT compilation time.
        f!(p, s)

        # Now estimate the elapsed time from a single JIT-less call
        naive_time = s.elapsed_times[1]

        # We determine the best case timing estimate we could ever hope for
        # compare our naive time against.
        resolution = estimate_clock_resolution()

        # If the elapsed time is more than 10,000 times longer than the clock
        # resolution, we can safely use a (1, 1) plan for benchmarking.
        if naive_time > 10_000 * resolution
            # TODO: Generate many samples here.
            return p, s, Float64[], Float64[]
        end

        # If the function is fast enough that the system clock resolution is
        # a problem for us, we'll go a geometric search through execution plans
        # to ensure that our estimates aren't severely biased by the clock's
        # resolution. To do that, we'll use an OLS regression in which we
        # regress the total sample time against the number of calls per sample.
        # When the linear model is almost a perfect fit to the data, we're
        # confident that we're getting good timings.
        x = Float64[]
        y = Float64[]

        # Start with two calls per sample
        n_calls = 2.0

        # Loop through a geometrically increasing set of values for n_calls
        # before we decide that we've done enough work.
        finished = false
        a, b = NaN, NaN
        while !finished
            # Use enough samples
            p = Benchmarks.Plan(ceil(Integer, n_calls), x_samples)
            s = Benchmarks.Samples(p)
            f!(p, s)

            # Add the new timing observations to our accumulated data set.
            for i in 1:length(s.elapsed_times)
                push!(x, n_calls)
            end
            append!(y, s.elapsed_times)

            # Perform an OLS regression to estimate the per-call time.
            a, b = linreg(x, y)
            r_squared = 1 - var(a + b * x - y) / var(y)
            if verbose
                @printf("%f,%f,%f,%f\n", n_calls, a, b, r_squared)
            end
            if r_squared > τ
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

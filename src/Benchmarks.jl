module Benchmarks
    # We assign every benchmarking session a random UUID
    import UUID

    @doc """
    Estimate the best-case resolution of benchmark timings based on the system
    clock in nanoseconds.
    """ ->
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
    function Base.resize!(s::Samples, n::Integer)
        resize!(s.elapsed_times, n)
        resize!(s.bytes_allocated, n)
        resize!(s.gc_times, n)
        resize!(s.num_allocations, n)
        n
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
    # * A function that implements the Benchmarkable protocol
    # * A plan that determines the execution of the Benchmarkable function
    # * A samples array to store the results of benchmarking the function
    immutable Benchmark
        name::UTF8String
        f::Function
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
    # Benchmarkable protocol.
    macro benchmarkable(
        name,
        setup,
        body,
        teardown,
    )
        quote
            function $(esc(name))(p::Plan, s::Samples)
                $(esc(setup))
                out = $(esc(body))
                for sample in 1:p.n_samples
                    local stats = Base.gc_num()
                    local elapsedtime = time_ns()
                    for c in 1:p.n_calls
                        out = $(esc(body))
                    end
                    local diff = Base.GC_Diff(Base.gc_num(), stats)
                    local bytes = diff.total_allocd + diff.allocd
                    local allocs = diff.malloc + diff.realloc + diff.poolalloc
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

    # Construct a benchmark execution plan by determining a number of calls
    # the expression that should be executed per sample in order to ensure
    # that the mean time over all calls is a good estimator of the per-call
    # execution time -- even when this time is below the clock resolution of
    # the system clock.
    function build_plan(f!::Function)
        # We determine the best case timing estimate we could ever hope for.
        resolution = estimate_clock_resolution()

        # Start by measuring time using a 1, 1 sampling plan
        p = Plan(1, 1)
        s = Samples(p)

        # Run once to force compilation of the benchmarkable function,
        # then run again to gather a real measurement
        f!(p, s)
        f!(p, s)

        # Estimate the elapsed time during a single call
        naive_time = s.elapsed_times[1]

        # If the elapsed time is more than 10,000 times longer than the clock
        # resolution, we can safely use a 1, 1 plan for benchmarking
        if naive_time > 10_000 * resolution
            return Plan(1, 1)
        end

        # Otherwise, begin searching for a better execution plan

        # We'll regress the total sample time against the number of calls
        # per sample. When the linear model is almost a perfect fit, we're
        # confident that we're getting good timings.
        x = Float64[]
        y = Float64[]

        # We'll stop when the correlation between calls and times is above
        # 0.9999
        τ = 0.99

        # When the linear model is still a bad fit, we'll double the number
        # of calls per sample.
        α = 2.0

        # Start with two calls per sample
        n_calls = 2
        finished = false
        while !finished
            # Try out the next execution plan
            p = Benchmarks.Plan(n_calls, 100)
            s = Benchmarks.Samples(p)
            f!(p, s)

            # Add the new timing observations
            append!(x, s.elapsed_times)
            for i in 1:length(s.elapsed_times)
                push!(y, n_calls)
            end

            # If the correlation between the number of calls
            if cor(x, y) > τ
                finished = true
            end

            # Increase the number of calls we need
            n_calls = ceil(Integer, α * n_calls)
        end

        return n_calls
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

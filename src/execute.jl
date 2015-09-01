# Execute a "benchmarkable" function to estimate the time required to perform
# a single evaluation of the benchmark's core expression. To do this reliably,
# we employ a series of estimates that allow us to decide on a sampling
# strategy and an estimation strategy for performing our benchmark.
#
# Arguments:
#
#     f!::Function: A "benchmarkable" function to be evaluated.
#
#     samples::Integer: The number of samples the user requests. Defaults to
#         100 samples.
#
#     budget::Integer: The time in seconds the user is willing to spend on
#         benchmarking. Defaults to 10 seconds.
#
#     τ::Float64: The minimum R² of the OLS model before the geometric search
#         procedure is considered to have converged. Defaults to 0.95.
#
#     α::Float64: The growth rate for the geometric search. Defaults to 1.1.
#
#     ols_samples::Integer: The number of samples per unique value of `n_evals`
#         when the geometric search procedure is employed. Defaults to 100.
#
#     verbose::Bool: Should the system print our verbose progress information?
#         Defaults to false.
#
# Returns:
#
#      r::Results: A Results object containing information about the
#         benchmark's full execution history.

function execute(
        f!::Function,
        samples::Integer = 100,
        budget::Integer = 10,
        τ::Float64 = 0.95,
        α::Float64 = 1.1,
        ols_samples::Integer = 100,
        verbose::Bool = false,
    )
    # We track the total time spent executing our benchmark.
    start_time = time()

    # Run the "benchmarkable" function once. This can require a compilation
    # step, which might bias the resulting estimates.
    s = Samples()
    f!(s, 1, 1)

    # Determine the elapsed time for the very first call to f!.
    biased_time_ns = s.elapsed_times[1]

    # We stop benchmarking f! if we've already exhausted our time budget.
    time_used = time() - start_time
    if time_used > budget
        return Results(false, false, false, s, time_used)
    end

    # We determine the maximum number of samples we could record given
    # our remaining time budget. We convert to nanoseconds before comparing
    # this number with our estimate of the per-evaluation time cost.
    remaining_time_ns = 10^9 * (budget - time_used)
    max_samples = floor(Integer, remaining_time_ns / biased_time_ns)

    # We stop benchmarking if running f! one more time would put us over
    # our time budget.
    if max_samples < 1
        return Results(false, false, false, s, time_used)
    end

    # Having reached this point, we can afford to record at least one more
    # sample without using up our time budget. The core question now is:
    #
    #     Is the expression being measured so fast that a single sample needs
    #     to evaluate the core expression multiple times before a single sample
    #     can provide an unbiased estimate of the expression's execution time?
    #
    # To determine this, we execute f! one more time. This provides
    # our first potentially unbiased estimate of the execution time, because
    # all compilations costs should now have been paid.

    # Before we execute f!, we empty our biased Samples object to discard
    # the values associated with our first execution of f!.
    empty!(s)

    # We evaluate f! to generate our first potentially unbiased sample.
    f!(s, 1, 1)

    # We can now improve our estimate of the expression's per-evaluation time.
    debiased_time_ns = s.elapsed_times[1]

    # If we've used up our time budget, we stop. We also stop if the user
    # only requested a single sample.
    time_used = time() - start_time
    if time_used > budget || samples == 1
        return Results(true, false, false, s, time_used)
    end

    # Now we determine if the function is so fast that we need to execute the
    # core expression multiple times per sample. We do this by determining if
    # the single-evaluation time is at least 1,000 times larger than the system
    # clock's resolution. If the function is at least that costly to execute,
    # then we determine how many single-evaluation samples we should employ.
    if debiased_time_ns > 1_000 * estimate_clock_resolution()
        remaining_time_ns = 10^9 * (budget - time_used)
        max_samples = floor(Integer, remaining_time_ns / debiased_time_ns)
        n_samples = min(max_samples, samples - 1)
        f!(s, n_samples, 1)
        return Results(true, true, false, s, time() - start_time)
    end

    # If we've reached this far, we are benchmarking a function that is so fast
    # that we need to be careful with our execution strategy. In particular,
    # we need to evaluate the core expression multiple times to generate a
    # single sample. To determine the correct number of times we should
    # evaluate the core expression per sample, we perform a geometric search
    # that starts at 2 evaluations per sample and increases by a factor of 1.1
    # evaluations on each iteration. Having generated data in this form, we
    # use an OLS regression to estimate the per-evaluation timing of our core
    # expression. We stop our geometric search when the OLS linear model is
    # almost perfect fit to our empirical data.

    # We start by executing two evaluations per sample.
    n_evals = 2.0

    # print header about the search progress
    verbose && @printf "%s\t%20s\t%8s\t%s\n" "time_used" "n_evals" "b" "r²"

    # Now we perform a geometric search.
    finished = false
    a, b = NaN, NaN
    while !finished
        # Gather many samples, each of which includes multiple evaluations.
        f!(s, ols_samples, ceil(Integer, n_evals))

        # Perform an OLS regression to estimate the per-evaluation time.
        a, b, r² = ols(s.n_evals, s.elapsed_times)

        # Stop our search when either:
        #  (1) The OLS fit is good enough; or
        #  (2) We've exhausted our time budget.
        time_used = time() - start_time
        if r² > τ || time_used > budget
            finished = true
        end

        # We optionally print out information about our search's progress.
        if verbose
            @printf(
                "%.1f\t%24.1f\t%12.2f\t%1.3f\n",
                time_used,
                n_evals,
                b,
                r²
            )
        end

        # We increase the number of evaluations per sample for the next round
        # of our search.
        n_evals *= α
    end

    return Results(true, true, true, s, time() - start_time)
end

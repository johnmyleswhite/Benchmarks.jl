# A Results object stores information about the results of benchmarking an
# expression.
#
# Fields:
#
#     precompiled::Bool: During benchmarking, did we ensure that the
#         "benchmarkable" function was precompiled? We do this for all
#         functions that can be executed at least twice without exceeding
#         the budget specified by the user.
#
#     multiple_samples::Bool: During benchmarking, did we gather more than one
#         sample? If so, we will attempt to report results that acknowledge
#         the variability in our sampled observations? If not, we will only
#         a single point estimate of the expression's performance.
#
#     search_performed::Bool: During benchmarking, did we perform a geometric
#         search to determine the minimum number of times we must evaluate the
#         expression being benchmarked before an individual sample can be
#         considered an unbiased estimate of the expression's performance?
#
#     samples::Samples: A log of all samples that were recorded during
#         benchmarking.
#
#     time_used::Float64: The time (in nanoseconds) that was consumed by the
#         benchmarking process.

immutable Results
    precompiled::Bool
    multiple_samples::Bool
    search_performed::Bool
    samples::Samples
    time_used::Float64
end

function prettyprint_nanoseconds(value::Real)
    if value < 10^3
        if value % 1 == 0
            string(value, " ns")
        else
            @sprintf("%.3f ns", value)
        end
    elseif value < 10^6
        @sprintf("%.3f μs", value/10^3)
    elseif value < 10^9
        @sprintf("%.3f ms", value/10^6)
    elseif value < 10^12
        @sprintf("%.3f s", value/10^9)
    else
        @sprintf("%d s", value/10^9)
    end
end

# Pretty-print information about the results of benchmarking an expression.
#
# Arguments:
#
#     io::IO: An IO object to be written to.
#
#     r::Results: The Results object that we want to print to `io`.
#
# NOTE: Because our measurements are not proper IID samples, we use 6-sigma
# CI's instead of using the (-1.96, +1.96) values associated with taking
# quantiles of the t-Distribution.

function Base.show(io::IO, r::Results)
    @printf(io, "================ Benchmark Results ========================\n")

    s = r.samples

    if !r.search_performed
        if !r.multiple_samples
            m = s.elapsed_times[1] / s.n_evals[1]
            min = m
            n = 1
            lower, upper = NaN, NaN
            r² = NaN
        else
            m = mean(s.elapsed_times)
            min = minimum(s.elapsed_times)
            n = length(s.elapsed_times)
            sem = std(s.elapsed_times) / sqrt(n)
            lower, upper = m - 6.0 * sem, m + 6.0 * sem
            r² = NaN
        end
    else
        a, b, r² = ols(s.n_evals, s.elapsed_times)
        m = b
        min = minimum(s.elapsed_times ./ s.n_evals)
        n = length(s.elapsed_times)
        sem = sem_ols(s.n_evals, s.elapsed_times)
        lower, upper = b - 6.0 * sem, b + 6.0 * sem
    end

    gc_pct = mean(100 * (s.gc_times ./ s.elapsed_times))
    i = indmin(s.bytes_allocated ./ s.n_evals)
    bytes = fld(s.bytes_allocated[i], convert(Int, s.n_evals[i]))
    allocs = fld(s.num_allocations[i], convert(Int, s.n_evals[i]))

    @printf(io, "%24s %s\n", "Average elapsed time:", prettyprint_nanoseconds(m))
    @printf(io, "%24s [%s, %s]\n", "95% CI for average:", prettyprint_nanoseconds(lower), prettyprint_nanoseconds(upper))
    @printf(io, "%24s %s\n", "Minimum elapsed time:", prettyprint_nanoseconds(min))
    @printf(io, "%24s %.2f%%\n", "GC time:", gc_pct)
    @printf(io, "%24s %d bytes\n", "Memory allocated:", bytes)
    @printf(io, "%24s %d allocations\n", "Number of allocations:", allocs)
    @printf(io, "%24s %d\n", "Number of samples:", n)
    @printf(io, "%24s %.3f\n", "R² of OLS model:", r²)
    @printf(io, "%24s %.2f s\n", "Time used for benchmark:", r.time_used)
    @printf(io, "%24s %s\n", "Precompiled:", r.precompiled)
    @printf(io, "%24s %s\n", "Multiple samples:", r.multiple_samples)
    @printf(io, "%24s %s", "Search performed:", r.search_performed)
end

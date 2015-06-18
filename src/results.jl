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

    @printf(io, "%s %.2f ns\n", lpad("Average elapsed time:", 24), m)
    @printf(io, "%s [%.2f ns, %.2f ns]\n", lpad("95% CI for average:", 24), lower, upper)
    @printf(io, "%s %.2f ns\n", lpad("Minimum elapsed time:", 24), min)
    @printf(io, "%s %.2f%%\n", lpad("GC time:", 24), gc_pct)
    @printf(io, "%s %d bytes\n", lpad("Memory allocated:", 24), bytes)
    @printf(io, "%s %d allocations\n", lpad("Number of allocations:", 24), allocs)
    @printf(io, "%s %d\n", lpad("Number of samples:", 24), n)
    @printf(io, "%s %.3f\n", lpad("R² of OLS model:", 24), r²)
    @printf(io, "%s %.2fs\n", lpad("Time used for benchmark:", 24), r.time_used)
    @printf(io, "%s %s\n", lpad("Precompiled:", 24), string(r.precompiled))
    @printf(io, "%s %s\n", lpad("Multiple samples:", 24), string(r.multiple_samples))
    @printf(io, "%s %s", lpad("Search performed:", 24), string(r.search_performed))
end

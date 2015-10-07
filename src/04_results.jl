# A `Results` object stores information about the results of benchmarking an
# expression.
#
# Fields:
#
#     precompiled::Bool: During benchmarking, did we ensure that the
#         benchmarkable function was precompiled? We do this for all
#         functions that can be executed at least twice without exceeding
#         the time budget specified by the user. Otherwise, we only measure
#         the expression's execution once and store this flag to indicate that
#         our single measurement potentially includes compilation time.
#
#     multiple_samples::Bool: During benchmarking, did we gather more than one
#         sample? If so, we will attempt to report results that acknowledge
#         the variability in our sampled observations. If not, we will only
#         report a single point estimate of the expression's performance
#         without any measure of our uncertainty in that point estimate.
#
#     search_performed::Bool: During benchmarking, did we perform a geometric
#         search to determine the minimum number of times we must evaluate the
#         expression being benchmarked before an individual sample can be
#         considered an unbiased estimate of the expression's performance? If
#         so, downstream analyses should use the slope of the linear regression
#         model, `elapsed_time ~ 1 + evaluations`, as their estimate of the
#         time it takes to evaluate the expression once. If not, we know that
#         `evaluation[i] == 1` for all `i`.
#
#     samples::Samples: A record of all samples that were recorded during
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

# A `SummaryStatistics` object stores the results of a statistic analysis of
# a `Results` object. The precise analysis strategy employed depends on the
# structure of the `Results` object:
#
#     (1) If only a single sample of a single evaluation was recorded, the
#     analysis reports only point estimates.
#
#     (2) If multiple samples of a single evaluation were recorded, the
#     analysis reports point estimates and CI's determined by straight
#     summary statistic calculations.
#
#     (3) If a geometric search was performed to generate samples that
#     represent multiple evaluations, an OLS regression is fit that
#     estimates the model `elapsed_time ~ 1 + evaluations`. The slope
#     of the `evaluations` term is treated as the best estimate of the
#     elapsed time of a single evaluation.
#
# For both strategies (2) and (3), we try to make up for a lack of IID
# samples by using 6-sigma CI's instead of the traditional 2-sigma CI'
# reported in most applied statistical work.
#
# In order to estimate GC time, we assume that the relationship betweeen GC
# time and total time is constant with respect to the number of evaluations.
# As such, we avoid using an OLS fit for estimating GC time.
#
# We also assume that the ratio, `bytes_allocated / evaluations` is a
# constant that only exhibits upward-biased noise. As such, we take the
# minimum value of this ratio to determine the memory allocation behavior of
# an expression.

immutable SummaryStatistics
    n::Int
    n_evaluations::Int
    elapsed_time_lower::Nullable{Float64}
    elapsed_time_center::Float64
    elapsed_time_upper::Nullable{Float64}
    gc_proportion_lower::Nullable{Float64}
    gc_proportion_center::Float64
    gc_proportion_upper::Nullable{Float64}
    bytes_allocated::Int
    allocations::Int
    r²::Nullable{Float64}

    function SummaryStatistics(r::Results)
        s = r.samples
        n = length(s.evaluations)
        n_evaluations = convert(Int, sum(s.evaluations))
        if !r.search_performed
            if !r.multiple_samples
                @assert n == 1
                @assert all(s.evaluations .== 1.0)
                m = s.elapsed_times[1]
                gc_proportion = s.gc_times[1] / s.elapsed_times[1]
                elapsed_time_center = m
                elapsed_time_lower = Nullable{Float64}()
                elapsed_time_upper = Nullable{Float64}()
                r² = Nullable{Float64}()
                gc_proportion_center = 100.0 * gc_proportion
                gc_proportion_lower = Nullable{Float64}()
                gc_proportion_upper = Nullable{Float64}()
            else
                @assert all(s.evaluations .== 1.0)
                m = mean(s.elapsed_times)
                sem = std(s.elapsed_times) / sqrt(n)
                gc_proportion = mean(s.gc_times ./ s.elapsed_times)
                gc_proportion_sem = std(s.gc_times ./ s.elapsed_times) / sqrt(n)
                r² = Nullable{Float64}()
                elapsed_time_center = m
                elapsed_time_lower = max(0.0, m - 6.0 * sem)
                elapsed_time_upper = m + 6.0 * sem
                gc_proportion_center = 100.0 * gc_proportion
                gc_proportion_lower = Nullable{Float64}(
                    max(
                        0.0,
                        gc_proportion_center - 6.0 * 100 * gc_proportion_sem
                    )
                )
                gc_proportion_upper = Nullable{Float64}(
                    min(
                        100.0,
                        gc_proportion_center + 6.0 * 100 * gc_proportion_sem
                    )
                )
            end
        else
            a, b, ols_r² = ols(s.evaluations, s.elapsed_times)
            sem = sem_ols(s.evaluations, s.elapsed_times)
            gc_proportion = mean(s.gc_times ./ s.elapsed_times)
            gc_proportion_sem = std(s.gc_times ./ s.elapsed_times) / sqrt(n)
            r² = Nullable{Float64}(ols_r²)
            elapsed_time_center = b
            elapsed_time_lower = max(0.0, b - 6.0 * sem)
            elapsed_time_upper = b + 6.0 * sem
            gc_proportion_center = 100.0 * gc_proportion
            gc_proportion_lower = Nullable{Float64}(
                max(
                    0.0,
                    gc_proportion_center - 6.0 * 100 * gc_proportion_sem
                )
            )
            gc_proportion_upper = Nullable{Float64}(
                min(
                    100.0,
                    gc_proportion_center + 6.0 * 100 * gc_proportion_sem
                )
            )
        end

        i = indmin(s.bytes_allocated ./ s.evaluations)

        bytes_allocated = fld(
            s.bytes_allocated[i],
            convert(UInt, s.evaluations[i])
        )
        allocations = fld(
            s.allocations[i],
            convert(UInt, s.evaluations[i])
        )

        new(
            n,
            n_evaluations,
            elapsed_time_lower,
            elapsed_time_center,
            elapsed_time_upper,
            gc_proportion_lower,
            gc_proportion_center,
            gc_proportion_upper,
            bytes_allocated,
            allocations,
            r²,
        )
    end
end

function pretty_time_string(t)
    if t < 1_000.0
        @sprintf("%.2f ns", t)
    elseif t < 1_000_000.0
        @sprintf("%.2f μs", t / 1_000.0)
    elseif t < 1_000_000_000.0
        @sprintf("%.2f ms", t / 1_000_000.0)
    else # if t < 1_000_000_000_000.0
        @sprintf("%.2f s", t / 1_000_000_000.0)
    end
end

function pretty_memory_string(b)
    if b < 1_024.0
        @sprintf("%.2f bytes", b)
    elseif b < 1_024.0^2
        @sprintf("%.2f kb", b / 1_024.0)
    elseif b < 1_024.0^3
        @sprintf("%.2f mb", b / 1_024.0^2)
    else # if b < 1_024.0^4
        @sprintf("%.2f gb", b / 1_024.0^3)
    end
end

# Pretty-print information about the results of benchmarking an expression.
#
# Arguments:
#
#     io::IO: An `IO` object to be written to.
#
#     r::Results: The `Results` object that we want to print to `io`.
#

function Base.show(io::IO, r::Results)
    stats = SummaryStatistics(r)

    max_length = 24
    @printf(io, "================ Benchmark Results ========================\n")

    if !r.precompiled
        @printf(io, "Warning: function may not have been precompiled\n")
    end
    if isnull(stats.elapsed_time_lower) || isnull(stats.elapsed_time_upper)
        @printf(
            io,
            "%s: %s\n",
            lpad("Time per evaluation", max_length),
            pretty_time_string(stats.elapsed_time_center),
        )
    else
        @printf(
            io,
            "%s: %s [%s, %s]\n",
            lpad("Time per evaluation", max_length),
            pretty_time_string(stats.elapsed_time_center),
            pretty_time_string(get(stats.elapsed_time_lower)),
            pretty_time_string(get(stats.elapsed_time_upper)),
        )
    end
    if isnull(stats.elapsed_time_lower) || isnull(stats.elapsed_time_upper)
        @printf(
            io,
            "%s: %.2f%%\n",
            lpad("Proportion of time in GC", max_length),
            stats.gc_proportion_center
        )
    else
        @printf(
            io,
            "%s: %.2f%% [%.2f%%, %.2f%%]\n",
            lpad("Proportion of time in GC", max_length),
            stats.gc_proportion_center,
            get(stats.gc_proportion_lower),
            get(stats.gc_proportion_upper),
        )
    end
    @printf(
        io,
        "%s: %s\n",
        lpad("Memory allocated", max_length),
        pretty_memory_string(stats.bytes_allocated),
    )
    @printf(
        io,
        "%s: %d allocations\n",
        lpad("Number of allocations", max_length),
        stats.allocations,
    )
    @printf(
        io,
        "%s: %d\n",
        lpad("Number of samples", max_length),
        stats.n
    )
    @printf(
        io,
        "%s: %d\n",
        lpad("Number of evaluations", max_length),
        stats.n_evaluations
    )
    if r.search_performed
        @printf(
            io,
            "%s: %.3f\n",
            lpad("R² of OLS model", max_length),
            get(stats.r², NaN),
        )
    end
    @printf(
        io,
        "%s: %.2f s\n",
        lpad("Time spent benchmarking", max_length),
        r.time_used,
    )
    # @printf(
    #     io,
    #     "%s: %s\n",
    #     lpad("Precompiled", max_length),
    #     string(r.precompiled)
    # )
    # @printf(
    #     io,
    #     "%s: %s\n",
    #     lpad("Multiple samples", max_length),
    #     string(r.multiple_samples),
    # )
    # @printf(
    #     io,
    #     "%s: %s",
    #     lpad("Search performed", max_length),
    #     string(r.search_performed),
    # )
end

# A `BenchmarkResults` object stores both the `RawResults` from benchmark
# execution and the `SummaryStatistics` computed from these `RawResults`. The
# purpose of the `BenchmarkResults` type is to serve as a vessel for the API.
#
# Fields:
#
#     raw::RawResults: The raw data gained via benchmark execution
#
#     stats::SummaryStatistics: The results of performing statistical analysis
#         on the `raw` field

immutable BenchmarkResults
    raw::RawResults
    stats::SummaryStatistics
    BenchmarkResults(raw::RawResults) = new(raw, SummaryStatistics(raw))
end

# Returns the total time (ns) spent executing the benchmark
totaltime(r::BenchmarkResults) = r.raw.time_used

# Returns estimates of the time (ns) per evaluation for the benchmarked function
timepereval(r::BenchmarkResults) = r.stats.elapsed_time_center
timepereval_lower(r::BenchmarkResults) = r.stats.elapsed_time_lower
timepereval_upper(r::BenchmarkResults) = r.stats.elapsed_time_upper

# Returns estimates of the % of time spent in GC during benchmark execution
gcpercent(r::BenchmarkResults) = r.stats.gc_proportion_center
gcpercent_lower(r::BenchmarkResults) = r.stats.gc_proportion_lower
gcpercent_upper(r::BenchmarkResults) = r.stats.gc_proportion_upper

# Returns the # of bytes allocated during benchmark execution
nbytes(r::BenchmarkResults) = r.stats.bytes_allocated

# Returns the # of allocations made during benchmark execution
nallocs(r::BenchmarkResults) = r.stats.allocations

# Returns the # of evaluations performed during benchmark execution
nevals(r::BenchmarkResults) = r.stats.n_evaluations

# Returns the # of samples taken during benchmark execution
nsamples(r::BenchmarkResults) = r.stats.n

# Returns the r² value of the OLS regression performed on the benchark results
rsquared(r::BenchmarkResults) = r.stats.r²

# BenchmarkResults pretty-printing functions
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

function Base.show(io::IO, r::BenchmarkResults)
    max_length = 24
    @printf(io, "================ Benchmark Results ========================\n")

    if !r.raw.precompiled
        @printf(io, "Warning: function may not have been precompiled\n")
    end
    if isnull(timepereval_lower(r)) || isnull(timepereval_upper(r))
        @printf(
            io,
            "%s: %s\n",
            lpad("Time per evaluation", max_length),
            pretty_time_string(timepereval(r)),
        )
    else
        @printf(
            io,
            "%s: %s [%s, %s]\n",
            lpad("Time per evaluation", max_length),
            pretty_time_string(timepereval(r)),
            pretty_time_string(get(timepereval_lower(r))),
            pretty_time_string(get(timepereval_upper(r))),
        )
    end
    if isnull(gcpercent_lower(r)) || isnull(gcpercent_upper(r))
        @printf(
            io,
            "%s: %.2f%%\n",
            lpad("Proportion of time in GC", max_length),
            gcpercent(r)
        )
    else
        @printf(
            io,
            "%s: %.2f%% [%.2f%%, %.2f%%]\n",
            lpad("Proportion of time in GC", max_length),
            gcpercent(r),
            get(gcpercent_lower(r)),
            get(gcpercent_upper(r)),
        )
    end
    @printf(
        io,
        "%s: %s\n",
        lpad("Memory allocated", max_length),
        pretty_memory_string(nbytes(r)),
    )
    @printf(
        io,
        "%s: %d allocations\n",
        lpad("Number of allocations", max_length),
        nallocs(r),
    )
    @printf(
        io,
        "%s: %d\n",
        lpad("Number of samples", max_length),
        nsamples(r)
    )
    @printf(
        io,
        "%s: %d\n",
        lpad("Number of evaluations", max_length),
        nevals(r)
    )
    if r.raw.search_performed
        @printf(
            io,
            "%s: %.3f\n",
            lpad("R² of OLS model", max_length),
            get(rsquared(r), NaN),
        )
    end
    @printf(
        io,
        "%s: %.2f s\n",
        lpad("Time spent benchmarking", max_length),
        totaltime(r),
    )
    # @printf(
    #     io,
    #     "%s: %s\n",
    #     lpad("Precompiled", max_length),
    #     string(r.raw.precompiled)
    # )
    # @printf(
    #     io,
    #     "%s: %s\n",
    #     lpad("Multiple samples", max_length),
    #     string(r.raw.multiple_samples),
    # )
    # @printf(
    #     io,
    #     "%s: %s",
    #     lpad("Search performed", max_length),
    #     string(r.raw.search_performed),
    # )
end

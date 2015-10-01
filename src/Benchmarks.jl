module Benchmarks
    export @benchmark,
           BenchmarkResults,
           totaltime,
           timepereval,
           timepereval_lower,
           timepereval_upper,
           gcpercent,
           gcpercent_lower,
           gcpercent_upper,
           nbytes,
           nallocs,
           nevals,
           nsamples,
           rsquared

    include("01_clock_resolution.jl")
    include("02_environment.jl")
    include("03_samples.jl")
    include("04_results.jl")
    include("05_api.jl")
    include("benchmarkable.jl")
    include("ols.jl")
    include("execute.jl")
    include("benchmark.jl")
    include("wrapper_types.jl")
end

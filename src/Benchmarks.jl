module Benchmarks
    import UUID
    export @benchmark

    include("01_clock_resolution.jl")
    include("02_environment.jl")
    include("03_samples.jl")
    include("04_results.jl")
    include("benchmarkable.jl")
    include("ols.jl")
    include("execute.jl")
    include("benchmark.jl")
    include("wrapper_types.jl")
end

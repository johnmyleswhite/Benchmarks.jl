module Benchmarks
    import UUID
    export @benchmark

    include("clock_resolution.jl")
    include("environment.jl")
    include("samples.jl")
    include("results.jl")
    include("benchmarkable.jl")
    include("ols.jl")
    include("execute.jl")
    include("benchmark.jl")
    include("wrapper_types.jl")
end

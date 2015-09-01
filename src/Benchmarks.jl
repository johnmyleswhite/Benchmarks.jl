VERSION >= v"0.4.0-dev+6521" && __precompile__(true)
module Benchmarks
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

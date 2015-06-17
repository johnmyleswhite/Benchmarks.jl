module Benchmarks
    import UUID

    include("clock_resolution.jl")
    include("environment.jl")
    include("samples.jl")
    include("results.jl")
    include("benchmarkable.jl")
    include("ols.jl")
    include("execute.jl")

    macro benchmark(core)
        name = esc(gensym())
        quote
            begin
                Benchmarks.@benchmarkable(
                    $name,
                    nothing,
                    $(esc(core)),
                    nothing
                )
                Benchmarks.execute($name)
            end
        end
    end
end

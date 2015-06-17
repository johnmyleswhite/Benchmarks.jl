# A Samples object contains five vectors of equal lengths that contain:
#
#     The number of times the expression was evaluated for every sample.
#
#     The execution time in nanoseconds for every sample.
#
#     The total number of bytes allocated for every sample.
#
#     The GC time in nanoseconds for every sample.
#
#     The total number of allocation operations for every sample.
#

immutable Samples
    n_evals::Vector{Float64}
    elapsed_times::Vector{Float64}
    bytes_allocated::Vector{Int}
    gc_times::Vector{Float64}
    num_allocations::Vector{Int}

    function Samples()
        new(
            Array(Float64, 0),
            Array(Float64, 0),
            Array(Int, 0),
            Array(Float64, 0),
            Array(Int, 0),
        )
    end
end

function Base.empty!(s::Samples)
    empty!(s.n_evals)
    empty!(s.elapsed_times)
    empty!(s.bytes_allocated)
    empty!(s.gc_times)
    empty!(s.num_allocations)
    return
end

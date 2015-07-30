# A Samples object represents all of the logged information about the execution
# of a benchmark. Each object contains five vectors of equal length.
#
# Fields:
#
#     n_evals::Vector{Float64}: The number of times the expression was
#         evaluated for every sample.
#
#     elapsed_times::Vector{Float64}: The execution time in nanoseconds for
#         every sample.
#
#     bytes_allocated::Vector{Int}: The total number of bytes allocated for
#         every sample.
#
#     gc_times::Vector{Float64}: The GC time in nanoseconds for every sample.
#
#     num_allocations::Vector{Int}: The total number of allocation operations
#         for every sample.

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

# Empty all of the five vectors from a Samples object.
#
# Arguments:
#
#     s::Samples: The Samples object whose contents should be emptied.

function Base.empty!(s::Samples)
    empty!(s.n_evals)
    empty!(s.elapsed_times)
    empty!(s.bytes_allocated)
    empty!(s.gc_times)
    empty!(s.num_allocations)
    return
end


# Pretty-print information about the Samples object.
#
# Arguments:
#
#     io::IO: An IO object to be written to.
#
#     s::Samples: The Samples object that we want to print to `io`.

function Base.show(io::IO, s::Samples)
    n = length(s.elapsed_times)
    @printf(io, "================== Benchmark Samples ==================\n")
    @printf(io, " %s %s\n", lpad("Number of samples:", 17), n)
    @printf(io, " %s %s", lpad("Number of metrics:", 17), 5)
end


# Log information about a set of samples to a delimited file.
#
# Arguments:
#
#     filename::String: The name of a file to which we'll write information
#         the Samples object, `s`.
#
#     s::Samples: The set of samples that we want to log to disk.
#
#     delim::String: The delimeter to use to separate elements. Default is `\t`
#
#     append::Bool: Should we write a new file or append to an existing one?
#         Defaults to false.

function Base.writedlm(filename::String, s::Samples, delim::String = "\t",
                       append::Bool = false)
    if append
        io = open(filename, "a")
    else
        io = open(filename, "w")
    end
    println(
        io,
        join(
            [
                "n_evals",
                "elapsed_times",
                "bytes_allocated",
                "gc_times",
                "num_allocations",
            ],
            delim
        )
    )
    for i in 1:length(s.n_evals)
        println(
            io,
            join(
                [
                    string(s.n_evals[i])
                    string(s.elapsed_times[i])
                    string(s.bytes_allocated[i])
                    string(s.gc_times[i])
                    string(s.num_allocations[i])
                ],
                delim
            )
        )
    end
    close(io)
end

# Log information about a set of samples to a csv file.
#
# Arguments:
#
#     filename::String: The name of a file to which we'll write information
#         the environment object, `e`.
#
#     e::Environment: The environment that we want to log to disk.
#
#     append::Bool: Should we write a new file or append to an existing one?
#         Defaults to false.
#
# Notes:
#
#     This is equivalent to calling `writedlm` with the delim set to `","`
Base.writecsv(filename::String, s::Samples, append::Bool = false) =
    writedlm(filename, s, ",", append)

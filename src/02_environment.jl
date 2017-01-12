# An `Environment` object stores information about the environment in which a
# suite of benchmarks were executed.
#
# Fields:
#
#     uuid::String: A random UUID that uniquely identifies each run.
#
#     timestamp::String: The time when we began executing benchmarks.
#
#     julia_sha1::String: The SHA1 for the Julia Git revision we're working
#         from.
#
#     package_sha1::Nullable{String}: The SHA1 for the current repo's Git
#         revision (if any). This field is null when the code was not executed
#         inside of a Git repo.
#
#     os::String: The OS we're running on.
#
#     cpu_cores::Int: The number of CPU cores available.
#
#     arch::String: The architecture we're running on.
#
#     machine::String: The machine type we're running on.
#
#     use_blas64::Bool: Was BLAS configured to use 64-bits?
#
#     word_size::Int: The word size of the host machine.

immutable Environment
    uuid::Compat.String
    timestamp::Compat.String
    julia_sha1::Compat.String
    package_sha1::Nullable{Compat.String}
    os::Compat.String
    cpu_cores::Int
    arch::Compat.String
    machine::Compat.String
    use_blas64::Bool
    word_size::Int

    function Environment()
        uuid = string(Base.Random.uuid4())
        timestamp = Libc.strftime("%Y-%m-%d %H:%M:%S", round(Int, time()))
        julia_sha1 = Base.GIT_VERSION_INFO.commit
        package_sha1 = Nullable{Compat.String}()
        try
            sha1 = readchomp(pipeline(`git rev-parse HEAD`, stderr=Base.DevNull))
            package_sha1 = Nullable{Compat.String}(Compat.String(sha1))
        end
        os = string(Compat.KERNEL === :NT ? :Windows : Compat.KERNEL)
        cpu_cores = Sys.CPU_CORES
        arch = string(Sys.ARCH)
        machine = Base.MACHINE
        use_blas64 = Base.USE_BLAS64
        word_size = Sys.WORD_SIZE

        new(
            uuid,
            timestamp,
            julia_sha1,
            package_sha1,
            os,
            cpu_cores,
            arch,
            machine,
            use_blas64,
            word_size,
        )
    end
end

# Pretty-print information about the environment in which benchmarks are being
# executed
#
# Arguments:
#
#     io::IO: An `IO` object to be written to.
#
#     e::Environment: The `Environment` object that we want to print to `io`.

function Base.show(io::IO, e::Environment)
    names = Compat.String[
        "UUID",
        "Time",
        "Julia SHA1",
        "Package SHA1",
        "Machine kind",
        "CPU architecture",
        "CPU cores",
        "OS",
        "Word size",
        "64-bit BLAS",
    ]
    values = Any[
        e.uuid,
        e.timestamp,
        e.julia_sha1,
        get(e.package_sha1, "NULL"),
        e.machine,
        e.arch,
        e.cpu_cores,
        e.os,
        e.word_size,
        e.use_blas64,
    ]

    @printf(io, "================== Benchmark Environment ==================\n")
    max_length = maximum([length(n) for n in names]) +  1
    for (n, v) in zip(names, values)
        @printf(io, "%s: %s\n", lpad(n, max_length), v)
    end
end

# Log information about the environment in which benchmarks are being executed
# to a CSV file.
#
# Arguments:
#
#     filename::AbstractString: The name of a file to which we'll write information
#         about the `Environment` object, `e`.
#
#     e::Environment: The `Environment` that we want to write to disk.
#
#     append::Bool: Should we append to an existing file or create a new one?
#         Defaults to false.

function Base.writecsv(filename::AbstractString, e::Environment, append::Bool = false)
    names = Compat.String[
        "uuid",
        "timestamp",
        "julia_sha1",
        "package_sha1",
        "os",
        "cpu_cores",
        "arch",
        "machine",
        "use_blas64",
        "word_size",
    ]
    values = Any[
        e.uuid,
        e.timestamp,
        e.julia_sha1,
        get(e.package_sha1, "NULL"),
        e.os,
        string(e.cpu_cores),
        e.arch,
        e.machine,
        string(e.use_blas64),
        string(e.word_size),
    ]

    if append
        io = open(filename, "a")
    else
        io = open(filename, "w")
    end
    println(io, join(names, ','))
    println(io, join(values, ','))
    close(io)
end

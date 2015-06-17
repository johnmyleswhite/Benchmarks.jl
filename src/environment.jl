# An Environment object stores information about the environment in which
# a suite of benchmarks were executed. We log information about:
#
#     A random UUID that uniquely identifies each run.
#
#     The time when we began executing benchmarks.
#
#     The SHA1 for the Julia Git revision we're working from.
#
#     The SHA1 for the current repo's Git revision (if any).
#
#     The OS we're running on.
#
#     The number of CPU cores available.
#
#     The architecture we're running on.
#
#     The machine type we're running on.
#
#     Was BLAS configured to use 64-bits?
#
#     The word size of the host machine.

immutable Environment
    uuid::UTF8String
    timestamp::UTF8String
    julia_sha1::UTF8String
    package_sha1::Nullable{UTF8String}
    os::UTF8String
    cpu_cores::Int
    arch::UTF8String
    machine::UTF8String
    use_blas64::Bool
    word_size::Int

    function Environment()
        uuid = string(UUID.v4())
        timestamp = Libc.strftime("%Y-%m-%d %H:%M:%S", round(Int, time()))
        julia_sha1 = Base.GIT_VERSION_INFO.commit
        package_sha1 = if isdir(".git")
            sha1 = ""
            try
                sha1 = readchomp(`git rev-parse HEAD`)
            end
            if isempty(sha1)
                Nullable{UTF8String}()
            else
                Nullable{UTF8String}(utf8(sha1))
            end
        else
            Nullable{UTF8String}()
        end
        os = string(OS_NAME)
        cpu_cores = CPU_CORES
        arch = string(Base.ARCH)
        machine = Base.MACHINE
        use_blas64 = Base.USE_BLAS64
        word_size = Base.WORD_SIZE

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

function Base.show(io::IO, e::Environment)
    @printf(io, "=== Benchmarking environment ===\n")
    @printf(io, " %s %s\n", lpad("UUID:", 17), e.uuid)
    @printf(io, " %s %s\n", lpad("Time:", 17), e.timestamp)
    @printf(io, " %s %s\n", lpad("Julia SHA1:", 17), e.julia_sha1)
    @printf(
        io,
        " %s %s\n",
        lpad("Package SHA1:", 17),
        get(e.package_sha1, "NULL")
    )
    @printf(io, " %s %s\n", lpad("Machine kind:", 17), e.machine)
    @printf(io, " %s %s\n", lpad("CPU architecture:", 17), e.arch)
    @printf(io, " %s %s\n", lpad("CPU cores:", 17), e.cpu_cores)
    @printf(io, " %s %s\n", lpad("OS:", 17), e.os)
    @printf(io, " %s %s\n", lpad("Word size:", 17), e.word_size)
    @printf(io, " %s %s", lpad("64-bit BLAS:", 17), e.use_blas64)
end

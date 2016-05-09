module TestEnvironment
    import Benchmarks
    using Base.Test
    using Compat

    e = Benchmarks.Environment()

    io = IOBuffer()
    show(io, e)

    path = tempname()
    writecsv(path, e)
    bytes = readstring(path)
    rm(path)
end

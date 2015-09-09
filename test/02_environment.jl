module TestEnvironment
    import Benchmarks
    using Base.Test

    e = Benchmarks.Environment()

    io = IOBuffer()
    show(io, e)

    path = tempname()
    writecsv(path, e)
    bytes = readall(path)
    rm(path)
end

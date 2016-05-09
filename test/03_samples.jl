module TestSamples
    import Benchmarks
    using Base.Test
    using Compat

    s = Benchmarks.Samples()

    push!(s, 1, 1, 1, 1, 1)

    io = IOBuffer()
    show(io, s)

    path = tempname()
    writecsv(path, s)
    bytes = readstring(path)
    rm(path)

    empty!(s)
end

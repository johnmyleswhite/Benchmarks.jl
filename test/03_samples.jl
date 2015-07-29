module TestSamples
    import Benchmarks
    using Base.Test

    s = Benchmarks.Samples()

    push!(s, 1, 1, 1, 1, 1)

    io = IOBuffer()
    show(io, s)

    path = tempname()
    writecsv(path, s)
    bytes = readall(path)
    rm(path)

    empty!(s)
end

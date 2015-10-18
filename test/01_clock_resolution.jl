module TestClockResolution
    import Benchmarks
    using Base.Test
    using Compat

    res = Benchmarks.estimate_clock_resolution(1)

    @test isa(res, UInt)
    @test 1 <= res <= 10_000

    res_2 = Benchmarks.estimate_clock_resolution()

    @test res_2 <= res
end

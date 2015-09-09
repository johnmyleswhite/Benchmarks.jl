module TestClockResolution
    import Benchmarks
    using Base.Test

    res = Benchmarks.estimate_clock_resolution(1)

    @test isa(res, Uint)
    @test 1 <= res <= 10_000

    res_2 = Benchmarks.estimate_clock_resolution()

    @test res_2 <= res
end

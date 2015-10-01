module TestAPI
    using Benchmarks
    using Base.Test

    f(v) = dot(v, rand(length(v)))
    results = @benchmark f(rand(10))

    @test totaltime(results) > 0.0
    @test timepereval(results) > 0.0
    @test timepereval(results) > get(timepereval_lower(results)) > 0.0
    @test get(timepereval_upper(results)) > timepereval(results)
    @test gcpercent(results) > 0.0
    @test gcpercent(results) > get(gcpercent_lower(results)) > 0.0
    @test get(gcpercent_upper(results)) > gcpercent(results)
    @test nbytes(results) > 0
    @test nallocs(results) > 0
    @test nsamples(results) > 0
    @test get(rsquared(results)) > 0.8
end

using DataCurator
using Test

@testset "DataCurator.jl" begin
    # Write your tests here.
    @testset "traversal" begin
        root = mktempdir()
        # root = "/dev/shm/test"
        C = [11, 21, 41]
        for (j,N) in enumerate([5, 10, 20])
            mkpath(joinpath(root, ["$i" for i in 1:N]...))
            for i in 1:N
                touch(joinpath(root, ["$i" for i in 1:i]..., "$i.txt"))
            end
            visitor = x -> ~isnothin(tryparse(Int, basename(x)))
            vts = x -> @debug x
            topdown(root, expand_filesystem, vts, 1)
            bottomup(root, expand_filesystem, vts, 1)
            i = Threads.Atomic{Int}(0);
            visitor = x -> Threads.atomic_add!(i, 1)
            topdown(root, expand_filesystem, visitor, 1)
            @test i[] ==  C[j]
            i = Threads.Atomic{Int}(0);
            bottomup(root, expand_filesystem, visitor, 1)
            @test i[] == C[j]
            rm(root, force=true, recursive=true)
        end
    end

    @testset "exittest" begin
        root = mktempdir()
        # root = "/dev/shm/test"
        C = [41, 100]
        for (j,N) in enumerate([20, 100])
            mkpath(joinpath(root, ["$i" for i in 1:N]...))
            for i in 1:N
                touch(joinpath(root, ["$i" for i in 1:i]..., "$i.txt"))
            end
            i = Threads.Atomic{Int}(0);
            visitor = x -> begin Threads.atomic_add!(i, 1); (rand() > 0.5) ? (return :quit) : (return :proceed); end
            topdown(root, expand_filesystem, visitor, 1)
            @test i[] <  C[j]
            i = Threads.Atomic{Int}(0);
            bottomup(root, expand_filesystem, visitor, 1)
            @test i[] < C[j]
            rm(root, force=true, recursive=true)
        end
    end


    @testset "fuzz" begin
        warnquit = x -> begin @warn x; return :quit; end
        N = 100
        import Random
        Random.seed!(42)
        for i in 1:N
            root = mktempdir()
            # for (j,N) in enumerate([N])
            M = rand(10:20)
            mkpath(joinpath(root, ["$i" for i in 1:M]...))
            for i in 1:M
                touch(joinpath(root, ["$i" for i in 1:i]..., "$i.txt"))
            end
            # i = Threads.Atomic{Int}(0);
            q=verify_template(root, [(x->false, quit_on_fail)])
            @test q == :quit
            q=verify_template(root, [(x->false, warn_on_fail)])
            @test q == :proceed
            rm(root, force=true, recursive=true)
        end
        # end
    end
end

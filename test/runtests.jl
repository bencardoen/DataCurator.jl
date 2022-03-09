using DataCurator
using Test
using Logging
using Random
using Images

@testset "DataCurator.jl" begin
    @testset "validate_pattern" begin
        root = mktempdir()
        pt = joinpath(root, "1", "Type 2", "Serie 14")
        mkpath(pt)
        a = zeros(3, 3, 3)
        f1 = joinpath(pt, "channel_1.tif")
        Images.save(f1, a)
        f2 = joinpath(pt, "channel_2.tif")
        Images.save(f2, a)
        isint = x -> ~isnothing(tryparse(Int, basename(x)))
        condition = x->false
        action = x-> @info x
        is3d = x-> length(size(Images.load(x)))==3
        is2d = x-> length(size(Images.load(x)))==3
        valid_channel = x -> occursin(r".*[1,2]\.tif", x)
        valid_cellnr = x->occursin(r"Serie\ [0-9]+", x)
        @test valid_cellnr("Serie 040")
        template = Dict()
        isint = x -> ~isnothing(tryparse(Int, splitpath(x)[end]))
        template[-1] = [(always, x-> quit_on_fail)]
        template[1] = [(x-> isdir(x), warn_on_fail)]
        template[2] = [(x->all_of(x, [isdir, isint]), warn_on_fail)]
        template[3] = [(x-> isdir(x), warn_on_fail)]
        template[4] = [(x->all_of(x, [isdir, valid_cellnr]), warn_on_fail)]
        template[5] = [(x->all_of(x, [isfile, valid_channel, is3d]), warn_on_fail)]
        @test verify_template(root, template)==:proceed
        rm(root, force=true, recursive=true)
    end

    @testset "transformer" begin
        root = mktempdir()
        N = 1
        mkpath(joinpath(root, ["$i" for i in 1:N]...))
        for i in 1:N
                touch(joinpath(root, ["$i" for i in 1:i]..., " $i .txt"))
        end
        condition = x -> ~contains(x, ' ')
        no_space = x -> replace(x, ' ' => '_')
        action = x -> transform_inplace(x, no_space)
        has_whitespace = condition
        space_to_ = action
        @test transform_template(root, [(has_whitespace, space_to_)]) == :proceed
        verify_template(root, [(has_whitespace, space_to_)]) == :proceed
        rm(root, recursive=true, force=true)
    end

    @testset "transform" begin
        c = global_logger()
        global_logger(NullLogger())
        root = mktempdir()
        mkpath(joinpath(root, "a"))
        pt = joinpath(root, "a")
        @test isdir(pt)
        file = joinpath(root, "a", "a.txt")
        touch(file)
        @test isfile(file)
        nf = transform_copy(file, x->x)
        @test isfile(nf)
        up = x -> uppercase(x)
        nf = transform_inplace(file, up)
        @test ~isfile(file)
        @test isfile(nf)
        nd = transform_copy(pt, up)
        @test isdir(nd)
        @test isdir(pt)
        rm(root, recursive=true, force=true)
        root = mktempdir()
        PT = joinpath(root, "a")
        mkpath(PT)
        nf = transform_inplace(PT, up)
        @test isdir(nf)
        @test ~isdir(PT)
        rm(root, recursive=true, force=true)
        global_logger(c)
    end

    @testset "traversal" begin
        c = global_logger()
        global_logger(NullLogger())
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
            topdown(root, expand_filesystem, vts)
            bottomup(root, expand_filesystem, vts)
            i = Threads.Atomic{Int}(0);
            visitor = x -> Threads.atomic_add!(i, 1)
            topdown(root, expand_filesystem, visitor)
            @test i[] ==  C[j]
            i = Threads.Atomic{Int}(0);
            bottomup(root, expand_filesystem, visitor)
            @test i[] == C[j]
            rm(root, force=true, recursive=true)
        end
        global_logger(c)

    end

    @testset "exittest" begin
        c = global_logger()
        global_logger(NullLogger())
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
            topdown(root, expand_filesystem, visitor)
            @test i[] <  C[j]
            i = Threads.Atomic{Int}(0);
            bottomup(root, expand_filesystem, visitor)
            @test i[] < C[j]
            rm(root, force=true, recursive=true)
        end
        global_logger(c)

    end


    @testset "fuzz" begin
        # warnquit = x -> begin @warn x; return :quit; end
        N = 100
        c = global_logger()
        global_logger(NullLogger())
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
        global_logger(c)

        # end
    end

    @testset "hierarchical" begin
        N = 500
        c = global_logger()
        global_logger(NullLogger())
        Random.seed!(42)
        for i in 1:N
            root = mktempdir()
            # for (j,N) in enumerate([N])
            M = rand(10:10)
            mkpath(joinpath(root, ["$i" for i in 1:M]...))
            for i in 1:M
                touch(joinpath(root, ["$i" for i in 1:i]..., "$i.txt"))
            end
            # i = Threads.Atomic{Int}(0);
            q=verify_template(root, [(x->false, quit_on_fail)])
            @test q == :quit
            q=verify_template(root, [(x->false, warn_on_fail)])
            @test q == :proceed
            template = [(x->false, warn_on_fail)]
            templater = Dict([(-1, template), (1, template)])
            z=verify_template(root, templater; traversalpolicy=topdown)
            @test z == :proceed
            z=verify_template(root, template; traversalpolicy=topdown)
            @test z == :proceed
            templater = Dict([(1, template)])
            z=verify_template(root, templater; traversalpolicy=topdown)
            @test z == :proceed
            templater = Dict([(i, template) for i in 1:M])
            z=verify_template(root, templater; traversalpolicy=topdown)
            @test z == :proceed
            z=verify_template(root, templater; traversalpolicy=topdown, parallel_policy="parallel")
            @test z == :proceed
            rm(root, force=true, recursive=true)
        end
        global_logger(c)
    end


end

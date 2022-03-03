using DataCurator
using Test

@testset "DataCurator.jl" begin
    # Write your tests here.
    @testset "traversal" begin
        root = mktempdir()
        # root = "/dev/shm/test"
        mkpath(joinpath(root, ["$i" for i in 1:5]...))
        for i in 1:5
            touch(joinpath(root, ["$i" for i in 1:i]..., "$i.txt"))
        end
        topdown(root, expand_filesystem, visit_filesystem, 1)
        bottomup(root, expand_filesystem, visit_filesystem, 1)
    end
end

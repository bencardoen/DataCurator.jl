using Images
using Random
Random.seed!(52)
# root = joinpath(tempdir(), randstring(20))
root="/tmp/testdataset"
mkpath(root)
series = 5
conditions = 2
channels = 3
replicates = 3
imsize = (200, 200, 40)
Random.seed!(42)
for r in 1:replicates
    for co in 1:conditions
        for s in 1:series
            p = joinpath(root, "$r", "Condition $co", "Series $s")
            mkpath(p)
            for c in 1:channels
                @info "Creating file for R $r  Co $co  Sr $s Ch $c"
                A = rand(imsize...) .- 0.5
                A[A.<0].=0
                Images.save(joinpath(p, "$c.tif"), A)
            end
        end
    end
end

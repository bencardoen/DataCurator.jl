using Images
using Random
Random.seed!(52)
root = joinpath(tempdir(), randstring(20))
root="/dev/shm/tmpdata"
mkpath(root)
series = 2
conditions = 2
channels = 2
replicates = 1
imsize = (200, 200, 200)
for r in 1:replicates
    for co in 1:conditions
        for s in 1:series
            p = joinpath(root, "$r", "Condition $co", "Series $s")
            mkpath(p)
            for c in 1:channels
                @info "Creating file for R $r  Co $co  Sr $s Ch $c"
                Images.save(joinpath(p, "$c.tif"), rand(imsize...))
            end
        end
    end
end

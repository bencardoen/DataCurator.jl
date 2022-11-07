using Images
using Random
using DataFrames
using CSV
Random.seed!(52)
# root = joinpath(tempdir(), randstring(20))
root="/tmp/testdataset"
mkpath(root)
series = 2
conditions = 3
channels = 2
replicates = 3
imsize = (200, 200, 40)
Random.seed!(42)
for r in 1:replicates
    for co in 1:conditions
        for s in 1:series
            p = joinpath(root, "Replicate_$r", "Condition_$co", "Series_$s")
            mkpath(p)
            for c in 1:channels
                @info "Creating file for R $r  Co $co  Sr $s Ch $c"
                A = rand(imsize...) .- 0.5
                A[A.<0].=0
                Images.save(joinpath(p, "$c.tif"), A)
            end
            CSV.write(joinpath(p, "$(r)_$(co)_$(s).csv"), DataFrame(zeros(20,20),:auto))
        end
    end
end

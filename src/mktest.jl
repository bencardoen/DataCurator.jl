using Images
using Logging
using Random
using CSV, DataFrames
using Pkg
Pkg.activate(".")
using DataCurator

IN="testdir"
delete_folder(IN)
delete_folder("outputdir")
mkpath(IN)
mkpath("outputdir")
Images.save(joinpath(IN, "test.tif"), rand(2,3))
Images.save(joinpath(IN, "test3.tif"), rand(2,3))
deep = joinpath(IN, "1", "2", "3", "4")
mkpath(deep)
for i in 1:100
    Images.save(joinpath(IN, "1", "test_$i.tif"), rand(20,20))
    Images.save(joinpath(IN, "1", "2", "test_$i.tif"), rand(20,20))
    Images.save(joinpath(IN, "1", "2", "3", "tEst_$i.tif"), rand(20,20))
    Images.save(joinpath(IN, "1", "2", "3", "4", "tTst_$i.tif"), rand(20,20))
    CSV.write(joinpath(IN, "1", "2", "3", "X$i.csv"), DataFrame(zeros(40, 40), :auto))
    CSV.write(joinpath(IN, "1", "2", "X$i.csv"), DataFrame(zeros(40, 40), :auto))
end
# CSV.write(joinpath(IN, "1", "2", "3", "X.csv"), DataFrame(zeros(40, 40), :auto))

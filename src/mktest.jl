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
Images.save(joinpath(IN, "test.tif"), rand(X,Y,4))
Images.save(joinpath(IN, "test3.tif"), rand(X,Y,4))
deep = joinpath(IN, "1", "2", "3", "4")
mkpath(deep)
X, Y = 100, 100
Z = 20
for i in 1:100
    Images.save(joinpath(IN, "1", "test_$i.tif"), rand(X, Y))
    Images.save(joinpath(IN, "1", "2", "test_$i.tif"), rand(X, Y))
    Images.save(joinpath(IN, "1", "2", "3", "tEst_$i.tif"), rand(X, Y))
    Images.save(joinpath(IN, "1", "2", "3", "4", "tTst_$i.tif"), rand(X, Y))
    CSV.write(joinpath(IN, "1", "2", "3", "X$i.csv"), DataFrame(zeros(40, 40), :auto))
    CSV.write(joinpath(IN, "1", "2", "X$i.csv"), DataFrame(zeros(40, 40), :auto))
end
# CSV.write(joinpath(IN, "1", "2", "3", "X.csv"), DataFrame(zeros(40, 40), :auto))

using Images
using Logging
using Random
using CSV, DataFrames
using Pkg
Pkg.activate(".")
using DataCurator

IN="testdir"
# delete_folder("outdir")
delete_folder(IN)
mkdir(IN)
# mkpath(joinpath(IN, "a", "b"))
A  = zeros(30,30,30)
A[20:25,20:25,20:25] .= rand(6,6,6)
Images.save(joinpath(IN, "A1.tif"), A)
Images.save(joinpath(IN, "A2.tif"), A)
p1 = joinpath(IN, "1")
mkpath(p1)
Images.save(joinpath(p1, "A1.tif"), A)
Images.save(joinpath(p1, "A2.tif"), A)
CSV.write(joinpath(p1, "A1.csv"), DataFrame(zeros(20,20),:auto))
p2 = joinpath(IN, "1", "2")
mkpath(p2)
Images.save(joinpath(p2, "A1.tif"), A)
Images.save(joinpath(p2, "A2.tif"), A)
CSV.write(joinpath(p2, "A1.csv"), DataFrame(zeros(20,20),:auto))
# IN="testdir"
# delete_folder(IN)
# delete_folder("outputdir")
# mkpath(IN)
# mkpath("outputdir")
# X, Y = 100, 100
# Z = 20
# Images.save(joinpath(IN, "test.tif"), rand(X,Y,4))
# Images.save(joinpath(IN, "test3.tif"), rand(X,Y,4))
# deep = joinpath(IN, "1", "2", "3", "4")
# mkpath(deep)
# for i in 1:100
#     Images.save(joinpath(IN, "1", "test_$i.tif"), rand(X, Y))
#     Images.save(joinpath(IN, "1", "2", "test_$i.tif"), rand(X, Y))
#     Images.save(joinpath(IN, "1", "2", "3", "tEst_$i.tif"), rand(X, Y))
#     Images.save(joinpath(IN, "1", "2", "3", "4", "tTst_$i.tif"), rand(X, Y))
#     CSV.write(joinpath(IN, "1", "2", "3", "X$i.csv"), DataFrame(zeros(40, 40), :auto))
#     CSV.write(joinpath(IN, "1", "2", "X$i.csv"), DataFrame(zeros(40, 40), :auto))
# end
# # CSV.write(joinpath(IN, "1", "2", "3", "X.csv"), DataFrame(zeros(40, 40), :auto))

using Images
using Logging

IN="testdir"
mkpath(IN)
Images.save(joinpath(IN, "test.tif"), zeros(2,3))
Images.save(joinpath(IN, "test3.tif"), zeros(2,3))

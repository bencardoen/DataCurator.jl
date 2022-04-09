# Copyright 2022, Ben Cardoen
using ArgParse
using DataCurator, Images, TOML
using Match
using CSV, DataFrames
using Logging, LoggingExtras, Dates
include(joinpath(pkgdir(DataCurator), "test", "runtests.jl"))
#
# tf = "example_recipes/aggregate_new_api_images.toml"
#
# remove("testdir")
# mkdir("testdir")
# Images.save(joinpath("testdir", "1.tif"), zeros(3,3))
# Images.save(joinpath("testdir", "2.tif"), zeros(3,3))
# R = DataCurator.create_template_from_toml(tf)
# if ~isnothing(R)
#     c, t = R
#     cts, cls, rv = delegate(c, t)
# end

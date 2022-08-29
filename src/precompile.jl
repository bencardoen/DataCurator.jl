# Copyright 2022, Ben Cardoen
using ArgParse
using DataCurator, Images, TOML
using Match
using CSV, DataFrames
using Logging, LoggingExtras, Dates
include(joinpath(pkgdir(DataCurator), "test", "runtests.jl"))

using DataCurator
using Pkg
Pkg.activate(".")
create_sysimage([:Images, :ERGO, :SPECHT, :DataCurator], sysimage_path="sys_img.so", precompile_execution_file="precompile.jl")


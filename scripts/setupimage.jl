using DataCurator
using Pkg
using PackageCompiler
Pkg.activate(".")
@info pwd()
create_sysimage(sysimage_path="sys_img.so", cpu_target="generic", include_transitive_dependencies=false, precompile_statements_file="dc_precompile.jl")

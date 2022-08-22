using Pkg;
using Logging;
@info "Initiating build"
## We want the Conda local Python env, anything else is out of control
ENV["PYTHON"] = ""
# ENV["LD_PRELOAD"] = joinpath(ENV["HOME"], ".julia/conda/3/lib/libstdc++.so.6.0.30")
# Conda and PyCall are dependencies, but we need to make sure they get prebuilt first.
# We're in our own env, so explicitly adding them now does not harm.
Pkg.add("Conda")
Pkg.add("PyCall")
## --> Initiates an PyConda env local to us
Pkg.build("PyCall")
Pkg.build("Conda")
# Precompile
using PyCall
using Conda
## Add the two packages we need
Conda.add("gcc=12.1.0"; channel="conda-forge")
# Conda.add("kneed"; channel="conda-forge")
Conda.add("scikit-image")
# Pin this version, to avoid clashes with libgcc.34
Conda.add("scipy=1.8.0")

## Make sure they're available (and at the same time, precompile the calls, this can save ~ 5 sec on first call, we have that time at build)
PyCall.pyimport("kneed");
PyCall.pyimport("skimage");
@info "Success!"

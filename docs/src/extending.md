# Using R and Python code
Using existing Python or R code arguably could not be simpler:
```toml
actions=["python.meshio.read", "R.base.sum"]
```
For Julia packages that are not available (included with DataCurator):
```toml
actions=["julia.CSV.write"]
```
The syntax is
```
"<language>.<module>.<function>"
```
For Julia, DataCurator will try to import the module, it **should** be at least present in your current installation.
Iow if this works
```julia
import Module.function
```
then this will work too
```toml
actions=["julia.Module.function"]
```
You can test using Julia
```julia
using DataCurator
decode_j("julia.Module.function")
```
Functions included in DataCurator and any in current scope do **not** need to be included this way, for those you can just use "functionname".

### Using Python packages/code
Let's say you have an existing python module which you want to use in the template.
In this example, we'll use `meshio`.
We want to use the function `meshio.read(filename)`
```julia
using DataCurator, PyCall, Conda
Conda.add("meshio", channel="conda-forge")
```
Now you can do in a template
```toml
actions=["python.meshio.read"]
```
You can check if code is picked up
```julia
p=lookup("python.meshio.read")
isnothing(p) ## Should be false
```
This works thanks to [PyCall.jl and Conda.jl](https://github.com/JuliaPy/PyCall.jl)

#### Note on installing
When DataCurator builds, it will try to use your existing Python installation.
If the environment variable PYTHON is defined, then DataCurator will asume you have installed all dependencies:
```bash
apt install python3 -y
apt install python3-pip -y
pip3 install smlmvis
pip3 install meshio
export PYTHON=`which python3`
julia -e 'using Pkg, Pkg.build("DataCurator")'
```
If you want DataCurator to install Python in a self-contained env, then do
```bash
unset PYTHON
# or export PYTHON=""
julia -e ...
```
See also [deps/build.jl] for how this is configured, if you want finer grained control.

### Using R in templates
You can use R functions
```julia
using DataCurator
p=lookup("R.base.sum")
isnothing(p) == false #
```
Now you can do in a template
```toml
actions=["R.base.sum"]
```
This assumes R is installed, if not DC will try to install it.
Installing your own R packages is beyond scope of this documentation, if it is available in your R install, the above will work.
See [RCall.jl](https://github.com/JuliaInterop/RCall.jl).


### Extending DataCurator
If you want to add support for your own datatypes or functions, the only thing you need is to make them available to DataCurator. More formally, they need to be in scope.
```julia
using DataCurator
function load_newtype(filename)
        ## Your code here
end
# or
using MyPackage

load_newtype = MyPackage.load_mydata
```
Then
```toml
actions=["load_newtype"]
```
Parameter passing will work, but if you need to change the signature or predefine parameters, you can do so to:
```julia
using DataCurator
function sum_threshold(xs, threshold)
        sum(xs[xs .>= threshold])
end
sum_short = x -> sum_threshold(x, 1)
```
then this is equivalent
```toml
actions=[["sum_threshold", 1]]
```
to
```toml
actions=["sum_short"]
```

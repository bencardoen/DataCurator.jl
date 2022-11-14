# DataCurator.jl Documentation
A multithreaded package to validate, curate, and transform large heterogeneous datasets using reproducible recipes, which can be created both in TOML human readable format, or in Julia.

![Concept](assets/datacurator-logos.png)

```@contents
Depth = 5
```

![Concept](assets/venn.png)

DataCurator is a Swiss army knife that ensures:
- pipelines can focus on the algorithm/problem solving
- human readable `recipes` for future reproducibility
- validation huge datasets at high speed
- out-of-the-box operation without the need for code or dependencies

![Concept](assets/whatami.png)

## Quickstart
We'll show 2 simple examples on how to get started, for a more complete manual please see individual sections in the left pane.
### Validate
Check that a directory only contains CSV files, list them in a file, and list any file that's incorrect.

```toml
[global]
inputdirectory = "testdir"
[any]
conditions=["is_csv_file"]
actions = [["log_to_file", "non_csvs.txt"]]
counter_actions=[["log_to_file", "csvs.txt"]]
```

Execute:

```bash
./DataCurator.sif -r myrecipe.toml
```

### Curate
Flatten all **.txt** files, `flatten` refers to extracting all files from a nested hierarchy (a directory with many subdirectories, each with their own subdirectories and so forth) into 1 single set of files in 1 directory, for ease of processing.

Create a `recipe.toml` file with:

```toml
[global]
inputdirectory = "testdir"
regex=true
[any]
all=true
conditions = ["isfile", ["endswith", ".*.txt"]]
actions = [["flatten_to", "outdir"]]
```

```bash
./DataCurator.sif -r myrecipe.toml
```


### A more complex example
In [full_api.toml](https://github.com/bencardoen/DataCurator.jl/blob/main/example_recipes/full_api.toml) you can see an example of how you can specify an entire image processing pipeline with a simple `recipe`.
```toml
...
actions=[
        {name_transform=["tolowercase"],
        content_transform=[
                        ["slice_image", [1,2],[[20,50],[20,50]]],
                        ["gaussian", 3],
                        "laplacian",
                        ["threshold_image", "abs <", 0.01],
                        ["apply_to_image", ["abs"]],
                        ["apply_to_image", ["log"]]
                        "otsu_threshold_image",
                        "erode_image"
                        ],
                        mode="copy"}
        ]
...
```

### Test data
See [script](https://github.com/bencardoen/DataCurator.jl/blob/main/scripts/testdataset.jl) to generate a test dataset, and a test [recipe](https://github.com/bencardoen/DataCurator.jl/blob/main/td.toml) to process it.
```julia
julia --project=. scripts/testdataset.jl
julia --project=. scripts/curator.jl -r td.toml
```
Change the test directory if needed.


### Using Python packages/code
Let's say you have an existing python module which you want to use in the template.
In this example, we'll use `meshio`.
We want to use the function `meshio.read(filename)`
```julia
using DataCurator
## Install the package
using PyCall
using Conda
Conda.add("meshio", channel="conda-forge")
## Test if DataCurator see it
p=lookup("python.meshio.read")
isnothing(p) == false #
```
Now you can do in a template
```toml
actions=["python.meshio.read"]
```
If the package is not installed, do so first
```julia
using Pkg
Pkg.activate(".")
using PyCall
using Conda
Conda.add("meshio", channel="conda-forge")
```
This works thanks to [PyCall.jl and Conda.jl](https://github.com/JuliaPy/PyCall.jl)

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
If you want to add support for your own datatypes or functions
```julia
using DataCurator
function load_newtype(filename)
        ## Your code here
end
```
Then
```toml
actions=["load_newtype"]
```

### Troubleshooting
If you experience any problems, please create an issue with the DC version, template, and sample data to reproduce it, including the Julia version and OS.

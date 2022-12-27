# DataCurator

![Concept](datacurator-logos.png)

A multithreaded package to validate, curate, and transform large heterogeneous datasets using reproducible recipes, which can be created both in TOML human readable format, or in Julia.

A key aim of this package is that recipes can read/written by any STEM researcher without the need for being able to write code, making data sharing/validation faster, more accurate, and reproducible.

![Concept](venn.png)

DataCurator is a Swiss army knife that ensures:
- pipelines can focus on the algorithm/problem solving
- human readable `recipes` for future reproducibility
- validation huge datasets at high speed
- out-of-the-box operation without the need for code or dependencies

![Concept](whatami.png)

## Status

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/bencardoen/DataCurator.jl/tree/main.svg?style=svg&circle-token=fd1f85a0afddb5f49ddc7a7252aad2a1ddaf80f9)](https://dl.circleci.com/status-badge/redirect/gh/bencardoen/DataCurator.jl/tree/main)

[![codecov](https://codecov.io/gh/bencardoen/DataCurator.jl/branch/main/graph/badge.svg?token=GI7MQH1VNA)](https://codecov.io/gh/bencardoen/DataCurator.jl)

## Singularity Image
You can find the container image at [bit.ly/datacurator_jl](bit.ly/datacurator_jl)
![Singularity](qr.png)

## Documentation
### Markdown
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/index.md) (clickable link)
The documentation in markdown makes it easier to reuse code snippets.
See [documentation source folder](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src) and the [examples](https://github.com/bencardoen/DataCurator.jl/blob/main/example_recipes)

### HTML
After [cloning](#cloned) the project, please open [docs/build/index.html](docs/build/index.html) with a browser.
This will be replaced by github pages + actions.

If you have Julia, you can build the docs yourself
```bash
cd docs
julia --project=.. make.jl
```
Then open docs/build/index.html with a browser of your choice.

### PDF
Alternatively, if you have texlive and the [Documenter.jl](https://juliadocs.github.io/Documenter.jl/stable/man/other-formats/) dependencies, you can generate a pdf
```bash
cd docs && julia --project=.. makepdf.jl
```

## What to find where
```bash
repository
├── example_recipes              ## Start here for easy to copy example recipes
├── docs
│   ├── builds
│   │   ├── index.html           ## Documentation
│   ├── src                      ## Markdown sources for docs
│   │   ├── make.jl              ## `cd docs && julia --project=.. make.jl` to rebuild docs
├── singularity                  ## Singularity image instructions
├── src                          ## source code of the package itself
├── scripts                      ## Utility scripts to run DC, generate test data, ...
├── test                         ## test suite and related files
└── runjulia.sh                  ## Required for Singularity image
└── buildimage.sh                ## Rebuilds singularity image for you (Needs root !!)
```


## Table of Contents
1. Quickstart
2. [Installation](#installation)
   1. [Installing]
      1. Julia package
      2. [Cloned repository](#cloned)
      3. [Singularity image](#singularity)

## Quickstart
Assuming you have the [Singularity image](bit.ly/datacurator_jl):
```bash
# Download
wget bit.ly/datacurator_jl -O datacurator.sif
# Set executable
chmod u+x ./datacurator.sif
# Copy an example recipe
cp example_recipes/count.toml .
# Create test data
mkdir testdir
touch testdir/text.txt
# Execute
datacurator.sif -r count.toml
```
That should show output similar to
![Results](outcome.png)

If you haven't cloned the repository, `count.toml` should look like this
```toml
[global]
act_on_success=true
counters = ["filecount", ["filesize", "size_of_file"]]
inputdirectory = "testdir"
[any]
all=true
conditions = ["isfile"]
actions=[["count", "filecount"], ["count", "filesize"]]
```

<a name="installation"></a>
### Installation
You can install DataCurator in 1 of 3 ways, as a Julia package in your global Julia environment, as a local package (no change to global), or completely isolated as a container or executable image.

#### As a Julia package
You need:
- Julia

```julia
using Pkg
Pkg.activate(".") # Optional if you want to install in a self contained environment
Pkg.add(url="https://github.com/bencardoen/SlurmMonitor.jl.git")
Pkg.add(url="https://github.com/bencardoen/DataCurator.jl.git")
Pkg.build("DataCurator")
Pkg.test("DataCurator")
```

Note: when this repo is private this will prompt for username and github token (not psswd)

<a name="cloned"></a>
#### As a local repository
You need:
- Julia
- git

```bash
git clone git@github.com:bencardoen/DataCurator.jl.git ## Assumes ssh
# git clone https://github.com/bencardoen/DataCurator.jl.git ## For non SSH
cd DataCurator.jl
julia
julia>using Pkg; Pkg.activate("."); Pkg.build(); Pkg.instantiate(); Pkg.test();
```




<a name="singularity"></a>
#### As a Singularity container / executable image
You need:
- A command line environment (WSL on windows, any shell on Linux or MAC)
- [Singularity](https://singularity-docs.readthedocs.io/en/latest/)
```bash
wget bit.ly/datacurator_jl -O datacurator.sif
chmod u+x datacurator.sif
```

This downloads a container image providing:
- Fedora 35 base environment
- Julia 1.7.1 base installation
- DataCurator installed in its own environment at /opt/DataCurator.jl
- All dependencies
- Python
- R


##### Execute recipes with the container
```bash
./datacurator.sif -r myrecipe.toml
```
See [curator.jl](https://github.com/bencardoen/DataCurator.jl/blob/main/scripts/curator.jl) for the arguments and usage. See [example_recipes](https://github.com/bencardoen/DataCurator.jl/blob/main/example_recipes) for example recipes to test.

Note that this is equivalent to
```bash
singularity run datacurator.sif /opt/DataCurator.jl/runjulia.sh -r myrecipe.toml
```

##### Get an interactive julia shell inside the container
```bash
singularity shell datacurator.sif
Singularity>julia --project=/opt/DataCurator.jl
julia>
```

##### Execute Julia commands with the container
```bash
singularity exec image.sif julia --project=/opt/DataCurator.jl -e 'using DataCurator";'
```

## Cite

## See also
DataCurator relies heavily on existing Julia packages for specialized functionality:
- [Images.jl](https://github.com/JuliaImages/Images.jl)
- [DataFrames.jl](https://dataframes.juliadata.org/stable/)
- [CSV.jl](https://csv.juliadata.org/stable/)
- [RCall.jl](https://github.com/JuliaInterop/RCall.jl)
- [PyCall.jl](https://github.com/JuliaPy/PyCall.jl)

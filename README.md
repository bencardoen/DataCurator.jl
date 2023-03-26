# DataCurator

<img src="overview.png" alt="Concept" width="600"/>

A multithreaded package to validate, curate, and transform large heterogeneous datasets using reproducible recipes, which can be created both in TOML human readable format, or in Julia.

A key aim of this package is that recipes can read/written by any STEM researcher without the need for being able to write code, making data sharing/validation faster, more accurate, and reproducible.

## Preprint
You can find our preprint [here](https://www.researchgate.net/publication/368557426_DataCuratorjl_Efficient_portable_and_reproducible_validation_curation_and_transformation_of_large_heterogeneous_datasets_using_human-readable_recipes_compiled_into_machine_verifiable_templates)

<!-- ![Concept](overview.png) -->

DataCurator is a Swiss army knife that ensures:
- pipelines can focus on the algorithm/problem solving
- human readable `recipes` for future reproducibility
- validation huge datasets at high speed
- out-of-the-box operation without the need for code or dependencies

<!-- ![Concept](whatami.png) -->

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.7527517.svg)](https://doi.org/10.5281/zenodo.7527517)

## Status

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/bencardoen/DataCurator.jl/tree/main.svg?style=svg&circle-token=fd1f85a0afddb5f49ddc7a7252aad2a1ddaf80f9)](https://dl.circleci.com/status-badge/redirect/gh/bencardoen/DataCurator.jl/tree/main)

[![codecov](https://codecov.io/gh/bencardoen/DataCurator.jl/branch/main/graph/badge.svg?token=GI7MQH1VNA)](https://codecov.io/gh/bencardoen/DataCurator.jl)

## Singularity Image

You can find the container image at [Sylabs](https://cloud.sylabs.io/library/bcvcsert/datacurator/datacurator)

## Documentation
### Markdown
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/index.md) (clickable link)
The documentation in markdown makes it easier to reuse code snippets.
See [documentation source folder](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/index.md) and the [examples](https://github.com/bencardoen/DataCurator.jl/blob/main/example_recipes)

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
1. [Quickstart](#quickstart)
2. [Installation](#installation)

<a name="installation"></a>
## Quickstart
* Get [Singularity](https://apptainer.org/user-docs/master/quick_start.html)
* Get the latest [Singularity image]([https://bit.ly/datacurator_jl_v1_1l](https://cloud.sylabs.io/library/bcvcsert/datacurator/datacurator)):
 
```bash
singularity pull --arch amd64 library://bcvcsert/datacurator/datacurator:latest
```
#### Set executable
```bash
chmod u+x ./datacurator.sif
```
#### Copy an example recipe
```bash
 wget https://raw.githubusercontent.com/bencardoen/DataCurator.jl/main/example_recipes/count.toml
```
#### Create test data
```bash
mkdir testdir
touch testdir/text.txt
```
#### Run
```bash
./datacurator.sif -r count.toml
```

That should show output similar to
![Results](outcome.png)

The recipe used can be found [here](https://raw.githubusercontent.com/bencardoen/DataCurator.jl/main/example_recipes/count.toml)

<a name="installation"></a>
### Installation
Please the [documentation](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/installation.md).


## See also

### Dependencies
DataCurator relies heavily on existing Julia packages for specialized functionality:
- [Images.jl](https://github.com/JuliaImages/Images.jl)
- [DataFrames.jl](https://dataframes.juliadata.org/stable/)
- [CSV.jl](https://csv.juliadata.org/stable/)
- [RCall.jl](https://github.com/JuliaInterop/RCall.jl)
- [PyCall.jl](https://github.com/JuliaPy/PyCall.jl)

### Related software
- [Open Microscopy OMERO](https://www.openmicroscopy.org/omero/)

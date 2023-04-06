# DataCurator

<img src="overview.png" alt="Concept" width="600"/>

A multithreaded package to validate, curate, and transform large heterogeneous datasets using reproducible recipes, which can be created both in TOML human readable format, or in Julia.

A key aim of this package is that recipes can be read/written by any researcher without the need for being able to write code, making data sharing/validation faster, more accurate, and reproducible.

DataCurator is a Swiss army knife that ensures:
- pipelines can focus on the algorithm/problem solving
- human readable `recipes` for future reproducibility
- validation huge datasets at high speed
- out-of-the-box operation without the need for code or dependencies

DataCurator is currently supported only in Unix-based systems with a command line environment. (ex. Linux, MacOs, WSL).

## Table of Contents
1. [Preprint](#preprint)
2. [Status](#status)
3. [Singularity Image](#image)
4. [Documentation (including installation)](#docs)
5. [What to Find Where](#map)
7. [Quickstart via Singularity](#quickstart)
8. [Troubleshooting](#faq)

<a name="preprint"></a>
## Preprint
You can find our preprint [here](https://www.researchgate.net/publication/368557426_DataCuratorjl_Efficient_portable_and_reproducible_validation_curation_and_transformation_of_large_heterogeneous_datasets_using_human-readable_recipes_compiled_into_machine_verifiable_templates)

<!-- ![Concept](overview.png) -->

<!-- ![Concept](whatami.png) -->

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.7527517.svg)](https://doi.org/10.5281/zenodo.7527517)

<a name="status"></a>
## Status
The outcome of automated tests (including building on Mac OS & Debian docker image) : [![CircleCI](https://dl.circleci.com/status-badge/img/gh/bencardoen/DataCurator.jl/tree/main.svg?style=shield&circle-token=70e51924b8df5a89cbc0050d1ce3979f2dd1c82b)](https://dl.circleci.com/status-badge/redirect/gh/bencardoen/DataCurator.jl/tree/main)

Code coverage (which parts of the source code are tested) : [![codecov](https://codecov.io/gh/bencardoen/DataCurator.jl/branch/main/graph/badge.svg?token=GI7MQH1VNA)](https://codecov.io/gh/bencardoen/DataCurator.jl)

<a name="image"></a>
## Singularity Image

You can find the container image at [Sylabs](https://cloud.sylabs.io/library/bcvcsert/datacurator/datacurator)

<a name="docs"></a>
## Documentation
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/index.md) (clickable link)

You can also view the documented [example recipes](https://github.com/bencardoen/DataCurator.jl/blob/main/example_recipes)

The installation page of the documentation can be found [here for quick reference](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/installation.md).

<a name="map"></a>
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

<a name="quickstart"></a>
## Quickstart with Singularity
The recommended and simplest way to use DataCurator is via the Singularity container. Note: DataCurator is only supported in a command line interface of a UNIX-based system. 

#### Install Singularity
##### Linux/WSL
If you don't already have Singularity, install by 
```bash
wget https://github.com/apptainer/singularity/releases/download/v3.8.7/singularity-container_3.8.7_amd64.deb
sudo apt-get install ./singularity-container_3.8.7_amd64.deb
```
##### Windows/MacOS
For Windows and Mac OS-based systems, the user is referred to [installation](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/installation.md).

Test by typing `singularity --version`. This will return `singularity version 3.8.7`

#### Download the DataCurator container
```bash
singularity pull datacurator.sif library://bcvcsert/datacurator/datacurator:latest
```
#### Set executable
```bash
chmod u+x ./datacurator.sif
```

### Testing DataCurator with a minimal example 
#### Copy the example recipe
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

For a complete walkthrough, please see the [documentation](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/index.md).

<a name="faq"></a>
## Troubleshooting
If you have any issue, please search [the issues](https://github.com/bencardoen/DataCurator.jl/issues) to see if your problem has been encountered before. 
If not, please [create a new issue](https://github.com/bencardoen/DataCurator.jl/issues/new/choose), and follow the templates for bugs and / or features you wish to be added.

If you have a workflow that DataCurator right now does not support, or not the way you'd like it to, you can mention this too. In that case, do share a **minimum** example of your data so we can add, upon completion of the feature, a new testcase.

## Dependencies
DataCurator relies heavily on existing Julia packages for specialized functionality:
- [Images.jl](https://github.com/JuliaImages/Images.jl)
- [DataFrames.jl](https://dataframes.juliadata.org/stable/)
- [CSV.jl](https://csv.juliadata.org/stable/)
- [RCall.jl](https://github.com/JuliaInterop/RCall.jl)
- [PyCall.jl](https://github.com/JuliaPy/PyCall.jl)

## Related software
- [Open Microscopy OMERO](https://www.openmicroscopy.org/omero/)

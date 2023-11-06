# DataCurator

![Untitled drawing](https://user-images.githubusercontent.com/22669736/231522505-350b23ba-da4e-4c6b-b56f-0e0075a4233c.png)

A multithreaded package to validate, curate, and transform large heterogeneous datasets using reproducible recipes, which can be created both in TOML human readable format, or in Julia.

A key aim of this package is that recipes can be read/written by any researcher without the need for being able to write code, making data sharing/validation faster, more accurate, and reproducible.

DataCurator is a Swiss army knife that ensures:
- pipelines can focus on the algorithm/problem solving
- human readable "recipes" for future reproducibility
- validation of huge datasets at high speed
- out-of-the-box operation without the need for code or dependencies

DataCurator requires a command-line interface and is supported on Linux, Windows Subsystem for Linux (WSL2), and MacOS. See [Quickstart](https://github.com/bencardoen/DataCurator.jl/blob/main/README.md#quickstart-with-singularity) and [Installation](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/installation.md) for detail.

## Table of Contents

1. [Quickstart via Singularity](#quickstart)
2. [Status](#status)
3. [Documentation (including installation)](#docs)
4. [What to Find Where](#map)
5. [Publication/Cite](#publication)
6. [Troubleshooting](#faq)


<a name="quickstart"></a>

## Quickstart via Singularity
The recommended way to use DataCurator is via the Singularity container. Note this is only supported in Linux, Windows Subsystem for Linux (WSL2), and MacOS (x86). For ARM-based Macs (e.g. from early 2021 onward), use the Docker container or source codes - see [installation](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/installation.md) for detail.

<a name="singularity"></a>

### 1. Install Singularity
#### Linux or Windows + WSL
```bash
wget https://github.com/apptainer/singularity/releases/download/v3.8.7/singularity-container_3.8.7_amd64.deb
sudo apt-get install ./singularity-container_3.8.7_amd64.deb
```
#### MacOS (x86)
Please refer to the [Singularity docs](https://docs.sylabs.io/guides/3.0/user-guide/installation.html#install-on-windows-or-mac).

#### 1.1 Test Singularity works
After installation, test by typing in a terminal `singularity --version`. This will return `singularity version 3.8.7`


### 2. Download the DataCurator container
```bash
singularity pull datacurator.sif library://bcvcsert/datacurator/datacurator:latest
```
The container image can be also found at [Sylabs](https://cloud.sylabs.io/library/bcvcsert/datacurator/datacurator).

### 3. Set executable
```bash
chmod u+x ./datacurator.sif
```
Depending on the directory you're in, you may need to grant Singularity read/write access.
By default Singularity has read/write access to $HOME, no other directory.
```
export SINGULARITY_BINDPATH=${PWD}
```
### 4. Test DataCurator with a minimal example 
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


The recipe used can be found [here](https://raw.githubusercontent.com/bencardoen/DataCurator.jl/main/example_recipes/count.toml).

**What next?** Check out [two simple examples of use cases and TOML recipes](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/index.md#two-simple-examples), and follow that with the [large collection of well commented example recipes](https://github.com/bencardoen/DataCurator.jl/tree/main/example_recipes) or the [complete walkthrough of DataCurator](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/recipe.md). Please see the [documentation](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/index.md).

<!-- ![Concept](overview.png) -->

<!-- ![Concept](whatami.png) -->

<a name="status"></a>

## Status
The outcome of automated tests (including building on Mac OS & Debian docker image) : [![CircleCI](https://dl.circleci.com/status-badge/img/gh/bencardoen/DataCurator.jl/tree/main.svg?style=shield&circle-token=70e51924b8df5a89cbc0050d1ce3979f2dd1c82b)](https://dl.circleci.com/status-badge/redirect/gh/bencardoen/DataCurator.jl/tree/main)

Code coverage (which parts of the source code are tested) : [![codecov](https://codecov.io/gh/bencardoen/DataCurator.jl/branch/main/graph/badge.svg?token=GI7MQH1VNA)](https://codecov.io/gh/bencardoen/DataCurator.jl)

<a name="docs"></a>

## Documentation
For full documentation, click here >> [![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/index.md). This includes more detailed [installation docs](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/installation.md), [two simple examples of use cases and TOML recipes](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/index.md#two-simple-examples), [well-commented example recipes](https://github.com/bencardoen/DataCurator.jl/tree/main/example_recipes), [complete walkthrough of DataCurator](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/recipe.md), and more. 

<a name="map"></a>

## What to find where
```bash
repository
├── example_recipes              ## Start here for easy to copy example recipes
├── docs
│   ├── src                      ## Documentation in markdown format (viewable online as well)
│   │   ├── make.jl              ## `cd docs && julia --project=.. make.jl` to rebuild docs
├── singularity                  ## Singularity image instructions
├── src                          ## source code of the package itself
├── scripts                      ## Utility scripts to run DC, generate test data, ...
├── test                         ## test suite and related files
└── runjulia.sh                  ## Required for Singularity image
└── buildimage.sh                ## Rebuilds singularity image for you (Needs root !!)
```



<a name="publication"></a>
[![DOI](https://doi.org/10.1093/bioadv/vbad068)

## Publication
```bibtex
@article{10.1093/bioadv/vbad068,
    author = {Cardoen, Ben and Ben Yedder, Hanene and Lee, Sieun and Nabi, Ivan Robert and Hamarneh, Ghassan},
    title = "{DataCurator.jl: efficient, portable and reproducible validation, curation and transformation of large heterogeneous datasets using human-readable recipes compiled into machine-verifiable templates}",
    journal = {Bioinformatics Advances},
    volume = {3},
    number = {1},
    pages = {vbad068},
    year = {2023},
    month = {06},
    abstract = "{Large-scale processing of heterogeneous datasets in interdisciplinary research often requires time-consuming manual data curation. Ambiguity in the data layout and preprocessing conventions can easily compromise reproducibility and scientific discovery, and even when detected, it requires time and effort to be corrected by domain experts. Poor data curation can also interrupt processing jobs on large computing clusters, causing frustration and delays. We introduce DataCurator, a portable software package that verifies arbitrarily complex datasets of mixed formats, working equally well on clusters as on local systems. Human-readable TOML recipes are converted into executable, machine-verifiable templates, enabling users to easily verify datasets using custom rules without writing code. Recipes can be used to transform and validate data, for pre- or post-processing, selection of data subsets, sampling and aggregation, such as summary statistics. Processing pipelines no longer need to be burdened by laborious data validation, with data curation and validation replaced by human and machine-verifiable recipes specifying rules and actions. Multithreaded execution ensures scalability on clusters, and existing Julia, R and Python libraries can be reused. DataCurator enables efficient remote workflows, offering integration with Slack and the ability to transfer curated data to clusters using OwnCloud and SCP. Code available at: https://github.com/bencardoen/DataCurator.jl.}",
    issn = {2635-0041},
    doi = {10.1093/bioadv/vbad068},
    url = {https://doi.org/10.1093/bioadv/vbad068},
    eprint = {https://academic.oup.com/bioinformaticsadvances/article-pdf/3/1/vbad068/50693195/vbad068.pdf},
}
```

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

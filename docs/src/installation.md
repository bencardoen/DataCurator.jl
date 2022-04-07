## Installation
Installation depends on what you plan to do, and what is available to you.

You can install DataCurator in 4 ways:
- as a Julia package in your global Julia environment
  - assumes you have Julia
- as a local package / cloned repository (no change to global)
  - assumes you have Julia and git
- download a container / executable image **recommended**
  - assumes you have a command line interface (WSL on Windows, any Linux or Mac)
- As a Singularity image
  - assumes you have Singularity installed
  - assumes you have a command line interface (WSL on Windows, any Linux or Mac)


!!! note "If you do not intend to write code, pick the container/image option"
    The container comes with Julia, so you don't need to install anything, and it has an optimized precompiled image of DataCurator inside so the startup time reduces to < 1s.


!!! warning "Code snippets"
    When we include a snippet like:
    ```bash
    julia
    julia>
    ```
    The 2nd `julia>` indicates how the user prompt has changed. It should not be copy-pasted.
    We do this only where it can help you to see what you should expect to see.

#### As a Julia package
You need:
- Julia

```julia
using Pkg;
Pkg.add(url="https://github.com/bencardoen/DataCurator.jl")
Pkg.test("DataCurator")
using DataCurator
```
or interactively
```julia
julia> ] # typing right bracket opens package manager
pkg 1.x> add https://github.com/bencardoen/DataCurator.jl
pkg 1.x> test DataCurator
```
!!! tip "Julia's package manager"
    Julia's package manager can be invoked with Julia commands, but also responds to interactive use in the REPL (Julia command line).
    ```julia
    ]
    <cmd> <argument>
    # is the same as
    using Pkg; Pkg.cmd(argument)
    ```
    Where cmd is usually one of `test`, `add`, `activate`, ...

Note: when this repo is private this will prompt for username and github token (not psswd)

#### As a local repository
You need:
- Julia
- git

```bash
git clone git@github.com:bencardoen/DataCurator.jl.git ## Assumes ssh
# git clone https://github.com/bencardoen/DataCurator.jl.git ## For non SSH
cd DataCurator.jl
julia
julia>using Pkg; Pkg.activate("."); Pkg.instantiate(); Pkg.test();
```
!!! note "Github's switch to tokens"
    Recently Github has been noted to favor token based logins, that won't matter if this repository is public, but while it's not, and you do not use SSH keys, ensure you switch from password to token.

#### As an executable image
You need:
- A command line environment (WSL on windows, any shell on Linux or MAC)

You'll download an `image`, which is a stand alone environment we prepare for you, with all dependencies. You don't need Julia, nor Singularity, but you do need some way of interacting with it on the command line.

See [Sylabs](https://cloud.sylabs.io/library/bcvcsert/datacurator/datacurator_f35_j1.6) for up to date images.

#### As a Singularity container
You need:
- A command line environment (WSL on windows, any shell on Linux or MAC)
- [Singularity](https://singularity-docs.readthedocs.io/en/latest/)
```bash
singularity pull --arch amd64 library://bcvcsert/datacurator/datacurator_f35_j1.6:0.0.1
```

The container provides:
- Fedora 35 base environment
- Julia 1.6.2 base installation
- DataCurator installed in its own environment at /opt/DataCurator.jl

### Test
If you want to verify everything works as it should:
```julia
using Pkg;
Pkg.test("DataCurator")
```
or if you cloned the repository
```julia
using Pkg;
Pkg.activate('.')
Pkg.test('.')
```

#### Advanced users

##### Changing the image
See [buildimage.sh](buildimage.sh) and [singularity1p6.def](singularity1p6.def) on how the images are built if you want to modify them.

##### Speeding up start-up time
On first run Julia needs to compile functions and load packages. If you process large datasets, this cost (up to 20s) is meaningless. However, for smaller use case its starts to get annoying.

We avoid this cost by using [PackageCompiler.jl] by
- run a typical example of DataCurator so Julia sees which functions are common
- precompile all major dependencies into a system image
- tell Julia to use that image instead.

This is automated in the Singularity image, but for completeness:
```bash
julia --project=. src/mktest.jl
julia --project=. --trace-compile=dc_precompile.jl src/curator.jl -r example_recipes/aggregate_new_api.toml
julia --project=. src/setupimage.jl
```
Now when you want to run DataCurator, do:
```bash
julia --project=/opt/DataCurator.jl --sysimage /opt/DataCurator.jl/sys_img.so /opt/DataCurator.jl/src/curator.jl --recipe <YOURRECIPE.TOML>
```

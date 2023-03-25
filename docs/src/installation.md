## Installation
Installation depends on what you plan to do, and what is available to you.


You can install DataCurator in 3 ways:
- as a Julia package in your global Julia environment
  - assumes you have Julia
- as a local package / cloned repository (no change to global)
  - assumes you have Julia and git
- download a singularity container / executable image **recommended**
  - assumes you have [Singularity](https://singularity-docs.readthedocs.io/en/latest/) installed
  - assumes you have a command line interface ([WSL](https://learn.microsoft.com/en-us/windows/wsl/install) on Windows, any Linux or Mac)

!!! note "If you wish to use the remote capabilities (Owncloud, Slack, SCP), you need [curl](https://curl.se/download.html), [scp, and ssh](https://www.openssh.com/) installed and configured"

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

### As an executable image/Singularity container
You need:
- A command line environment (WSL on windows, any shell on Linux or MAC)
- [Singularity](https://singularity-docs.readthedocs.io/en/latest/)
You'll download an `image`, which is a stand alone environment we prepare for you, with all dependencies. You don't need Julia, nor Singularity, but you do need some way of interacting with it on the command line.

```bash
wget bit.ly/datacurator_jl -O datacurator.sif
```
This provides you with a file `datacurator.sif`, which contains Julia, R, Python, and the DataCurator code.

The container provides:
- Fedora 35 base environment
- Julia 1.7.1 base installation
- DataCurator installed in its own environment at /opt/DataCurator.jl


### Local installations
**Note** If you have an existing Python and R installation and wish to use it, set
```bash
export PYTHON="/path/to/python" # or `which python3`
export R_HOME=`R RHOME`
```
If not, and you want DataCurator to install it, set
```bash
export PYTHON=""
export R_HOME="*"
```
When in doubt, for Fedora/Red Hat based systems you can take a look at the [Singularity recipe](https://github.com/bencardoen/DataCurator.jl/blob/main/singularity/recipe.def) for working instructions, or for Ubuntu/Debian based see the [CircleCI test script](https://github.com/bencardoen/DataCurator.jl/blob/main/.circleci/config.yml)
#### As a Julia package
You need:
- [Julia](https://julialang.org/downloads/)

You can either install in a new or existing environment (directory), or install in your global Julia installation (not recommended).
Let's assume you want to install in a new environment:
```bash
mkdir -p myenv && cd myenv
julia
```
Then in Julia
```julia
using Pkg
Pkg.activate(".")
Pkg.add(url="https://github.com/bencardoen/Colocalization.jl.git")
Pkg.add(url="https://github.com/bencardoen/SlurmMonitor.jl.git")
Pkg.add(url="https://github.com/bencardoen/SMLMTools.jl.git")
Pkg.add(url="https://github.com/bencardoen/DataCurator.jl.git")
Pkg.build("DataCurator")
Pkg.test("DataCurator")
```

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
!!! note "Github's switch to tokens"
    Recently [Github](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) has been noted to favor token based logins, that won't matter if this repository is public, but while it's not, and you do not use SSH keys, ensure you switch from password to token.

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
Note, the container will not allow you to do this, as it is a read-only image, and tests involve creating temporary files.
However, the container can only be built if all tests succeeded, therefore there's no reason to execute the tests in the container.

#### Advanced usage/troubleshooting

##### Modify the container
Let's say you want to add 4GB of writeable changes.
```bash
singularity overlay create --size 4096 datacurator.sif
sudo singularity shell --writable datacurator.sif
Singularity>
```

##### Changing the image
See [buildimage.sh](https://github.com/bencardoen/DataCurator.jl/tree/main/buildimage.sh) and [recipe.def](https://github.com/bencardoen/DataCurator.jl/tree/main/singularity/recipe.def) on how the images are built if you want to modify them.

```bash
./buildimage.sh # needs root
```
#### Note on file permission errors
If you get read/write errors, but the files exist:
If you run into issues with files or directories not found, this is because the Singularity container by default has **no access except to your $HOME directory**. Use
```bash
singularity run -B /scratch image.sif ...
```
where /scratch is a directory you want read/write access to.
If you use this often, use a environment variable:
```bash
 export SINGULARITY_BIND="/opt,/data:/mnt"
```

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



### Linking with Slack
In a Slack workspace, go to Preferences / Manage Apps / Build
Create a new App, then configure a webhook (and a channel).
That should give you an URL of the form
```bash
/services/<code>/<code>/<code>
```
Save this is a file
```bash
echo "/services/<code>/<code>/<code>" > endpoint.txt
```
Then at execution, pass it to DataCurator
```bash
julia --project=. scripts/monitor.jl -r recipe.toml -e endpoint.txt
```
That's all.
On finishing execution, it will print a summarized message to your slack channel of choice.

In the template, you then define
```toml
endpoint="endpoint.txt"
```

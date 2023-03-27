## Installation
### Recommended way
The recommended way to install and use DataCurator is to use the [Singularity](https://singularity.hpcng.org/) container. This is a self-contained environment that you can run on any Linux or Mac system, and on Windows using [WSL](https://docs.microsoft.com/en-us/windows/wsl/install-win10).
The reference solution for reproducible high performance computing code, Singularity is a container technology that allows you to package up your code and all its dependencies into a single file that can be easily shared and executed on any Linux system, including HPC systems, without having to worry about installing dependencies or conflicting versions.
Singularity images, unlike Docker images, can be run without root privileges, and are read-only, so the code stays 100% reproducible even at runtime.
If you follow this workflow, the installation is as simple as downloading the container image.

#### Prerequisites
* Get [Singularity](https://apptainer.org/user-docs/master/quick_start.html)
* Get the latest [Singularity image](https://cloud.sylabs.io/library/bcvcsert/datacurator/datacurator):
 
 #### Get DataCurator
 Using the singularity CLI
```bash
singularity pull --arch amd64 library://bcvcsert/datacurator/datacurator:latest
```
or visit [Sylabs](https://cloud.sylabs.io/library/bcvcsert/datacurator/datacurator)
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
![Results](https://raw.githubusercontent.com/bencardoen/DataCurator.jl/main/outcome.png)

The recipe used can be found [here](https://raw.githubusercontent.com/bencardoen/DataCurator.jl/main/example_recipes/count.toml)

See [TroubleShooting](#trouble) for common errors and their resolution.

### Advanced
In order to guarantee that changes in code do not break existing functionality, we continually test DataCurator in Ubuntu and Fedora environments. 
Those recipes are therefore the reference way to use DataCurator outside of the container image, as those are always guaranteed to work.
- [Singularity recipe](https://github.com/bencardoen/DataCurator.jl/blob/main/singularity/recipe.def)
- [Ubuntu][CircleCI test script](https://github.com/bencardoen/DataCurator.jl/blob/main/.circleci/config.yml)
We do not have the build minutes/resources to test more OSes, but if you want to use DataCurator on another OS, you can use the following instructions.
The Singularity image works on Windows, MacOS, and Linux as-is. 

#### Local installations
**Note** [Recommended] If you have an existing Python and R installation and wish to use it, set
```bash
export PYTHON="/path/to/python" # or `which python3`
export R_HOME=`R RHOME`
```
If not, and you want DataCurator to try to install both, set
```bash
export PYTHON=""
export R_HOME="*"
```
**Note** this may not always work, because it involves creating a Conda environment from scratch with R and Python, this can fail with timeouts, for example.


The below assumes you know how to use git, and have Julia installed.
#### Cloning repository
```bash
git clone git@github.com:bencardoen/DataCurator.jl.git ## Assumes ssh
# git clone https://github.com/bencardoen/DataCurator.jl.git ## For non SSH
cd DataCurator.jl
julia
```
In Julia
```julia
using Pkg
Pkg.activate('.')
Pkg.test(".")
```
#### Advanced usage/troubleshooting

##### I want to modify the container
Let's say you want to add 4GB of writeable changes.
```bash
singularity overlay create --size 4096 datacurator.sif
sudo singularity shell --writable datacurator.sif
Singularity>
```

##### I want to change the image
See [buildimage.sh](https://github.com/bencardoen/DataCurator.jl/tree/main/buildimage.sh) and [recipe.def](https://github.com/bencardoen/DataCurator.jl/tree/main/singularity/recipe.def) on how the images are built if you want to modify them.

```bash
./buildimage.sh # needs root
```
##### I get file permission errors with the image, but the files are right here!
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

##### It's so slow on first run !!
If you use DataCurator as a Julia package or cloned repository, on first run Julia needs to compile functions and load packages. If you process large datasets, this cost (up to 20s) is meaningless. However, for smaller use case its starts to get annoying.

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
Please do not copy these instructions, rather check the [buildimage.sh](https://github.com/bencardoen/DataCurator.jl/tree/main/buildimage.sh) script to see how it's done on the fly.
Second, Precompile.jl means you will need a development environment, including but not limited to C++ compilers.
That is all taken care of for you in the singularity image.


#### Optional
If you wish to use the remote capabilities (Owncloud, Slack, SCP), you need [curl](https://curl.se/download.html), [scp, and ssh](https://www.openssh.com/) installed and configured

### Help !
If any of the above is not clear, or not working, please report an issue online

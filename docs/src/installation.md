## Installation

## Table of Contents
1. [Recommended way](#recommended)
   - [Singularity for Linux or WSL](#LinuxorWSL)
   - [Singularity for Windows or Mac](#WindowsorMac)
2. [Docker](#docker)
3. [Install from source](#source)
4. [Advanced usage](#advanced)
5. [Troubleshooting](#trouble)



<a name="recommended"></a>

### Singularity --Recommended way

The recommended way to install and use DataCurator is to use the [Singularity](https://singularity.hpcng.org/) container. This is a self-contained environment that you can run on any Linux or Mac x86 system, and on Windows using [WSL](https://docs.microsoft.com/en-us/windows/wsl/install-win10).
The reference solution for reproducible high performance computing code, Singularity is a container technology that allows you to package up your code and all its dependencies into a single file that can be easily shared and executed on any Linux system, including HPC systems, without having to worry about installing dependencies or conflicting versions.
Singularity images, unlike Docker images, can be run without root privileges, and are read-only, so the code stays 100% reproducible even at runtime.
If you follow this workflow, the installation is as simple as downloading and running the container image.

**Note** If for any reason Singularity does not work on your machine, you can also [install from source](#advanced) or use the [Docker images](#docker). We provide installation scripts that do this for you, those run automatically on each code change to ensure such changes do not break user installations. 
However, the installation from source is more involved, and so if possible, we recommend the Singularity workflow.
The Docker workflow is 1-1 with Singularity.

#### Prerequisites
You need to install Singularity, first.

##### Linux or WSL
<a name="LinuxorWSL"></a>

The following works on Debian based Linux or Windows Subsystem for Linux (WSL) 2.
```bash
wget https://github.com/apptainer/singularity/releases/download/v3.8.7/singularity-container_3.8.7_amd64.deb
sudo apt-get install ./singularity-container_3.8.7_amd64.deb
```
Test if it works
```bash
singularity --version
```
This will show
```bash
singularity version 3.8.7
```
<a name="WindowsorMac"></a>

##### Windows or Mac

Please follow the Singularity instructions:
* Get [Singularity](https://docs.sylabs.io/guides/3.0/user-guide/installation.html#install-on-windows-or-mac)
 
**Note** Mac + M1/M2 chips may not work reliably with Virtualbox/Vagrant, it is then recommended to [install from source](#advanced) or use [Docker](#docker). 
 
 #### Get DataCurator
 Using the singularity CLI
```bash
singularity pull datacurator.sif library://bcvcsert/datacurator/datacurator:latest
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

<a name="docker"></a>
### Docker
Docker is a technology that allows you to run packaged software and libraries, in this case DataCurator, on any of the major operating systems. 
It is better supported on Mac+M1/M2 chips compared to Singularity.
We provide both a [prebuilt docker instance](https://vault.sfu.ca/index.php/s/vzcz15uV3yZR9T5), and a [docker container recipe](https://github.com/bencardoen/DataCurator.jl/blob/main/docker/dockerfile) based on the singularity recipe.
#### Download and install [Docker](https://docs.docker.com/get-docker/)

#### Download DataCurator
See [here](https://vault.sfu.ca/index.php/s/vzcz15uV3yZR9T5)
You can download in your browser, or via command line
```
wget https://vault.sfu.ca/index.php/s/vzcz15uV3yZR9T5/download -O datacurator.tgz
```

#### Load the image into Docker
```bash
docker load -i datacurator.tgz
```

#### Run
##### Create example data
```bash
mkdir testdir
touch testdir/example.txt
```
##### Download a recipe
```bash
 wget https://raw.githubusercontent.com/bencardoen/DataCurator.jl/main/example_recipes/count.toml -O count.toml
```
##### Run
```bash
docker run -it -v `pwd`:/workdir -w /workdir datacurator:latest bash /opt/DataCurator.jl/runjulia.sh --recipe count.toml
```
The output will look somewhat like this
```bash
[ Info: 2023-04-25 16:46:02 curator.jl:97: Reading template recipe count.toml
[ Info: 2023-04-25 16:46:02 DataCurator.jl:3055: Inputdirectory is set to testdir
[ Info: 2023-04-25 16:46:02 DataCurator.jl:3068: 🤨 Input directory is not an absolute path, resolving to absolute path .testdir -> /workdir/testdir
[ Info: 2023-04-25 16:46:02 DataCurator.jl:2663: Flat recipe detected
[ Info: 2023-04-25 16:46:02 DataCurator.jl:2674: ✓ Succesfully decoded your template ✓
[ Info: 2023-04-25 16:46:02 curator.jl:103: ✓ Reading complete ✓
[ Info: 2023-04-25 16:46:02 curator.jl:105: Running recipe on /workdir/testdir
[ Info: 2023-04-25 16:46:02 DataCurator.jl:2270: Finished processing dataset located at /workdir/testdir 🏁🏁🏁
[ Info: 2023-04-25 16:46:02 curator.jl:119: Counter 1 --> ("filesize", 0)
[ Info: 2023-04-25 16:46:02 curator.jl:119: Counter 2 --> ("filecount", 2)
[ Info: 2023-04-25 16:46:02 curator.jl:133: Writing counters to counters.csv
[ Info: 2023-04-25 16:46:02 curator.jl:146: 🏁✓ Complete with exit status proceed ✓🏁
```



**Note** You could get a warning from Docker Desktop that you're sharing your home dir with the container, this is intended behavior, otherwise DataCurator can only access data inside the container, where there is none.

**Note** You may get a warning about architectures:
```bash
WARNING: The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8) and no specific platform was requested
```
This can be safely ignored on Mac with M1/M2 chips. The docker image is built for x86 architecture, but Mac M1/2 comes with a translation layer.

A quick explanation of the command arguments, should you run into issues.

```bash
-v `pwd`:/workdir
```
Give docker read/write access to the current directory, where your recipe is located, and the data is hosted. Modify as needed
```bash
-w /workdir
```
Run the container in this path (which we just made available with -v)

##### Advanced
If you want to modify the container, you can do so by modifying the [recipe](https://github.com/bencardoen/DataCurator.jl/blob/main/docker/dockerfile) and rebuild.
```bash
wget https://github.com/bencardoen/DataCurator.jl/blob/main/docker/dockerfile -O dockerfile
docker build --tag datacurator:myversion .
```

<a name="source"></a>

### From source
In order to guarantee that changes in code do not break existing functionality, we continually test DataCurator in Debian and Mac environments. 
Those recipes are therefore the reference way to use DataCurator outside of the container image, as those are always guaranteed to work.
- [Debian docker image](https://raw.githubusercontent.com/bencardoen/DataCurator.jl/main/scripts/install_debian.sh)
- [Mac](https://raw.githubusercontent.com/bencardoen/DataCurator.jl/main/scripts/install_mac.sh)

**Note** We do not reproduce the above scripts here, because documentation may not be 1-1 with actual code. The instructions in the above scripts are run automatically in our CI/CD pipeline, and are guaranteed to work, if they do not, it will show publicly on the github repository as a failed build.
In this way users will always know if a certain version or even commit works, or not.

**Note** The installation scripts are designed to run in systems where the **user has root privileges**. 
You can adapt them to work without root privileges, but the number of different environment (brew, conda, pip, etc) is too large to support all of them reliably. By default singularity and docker containers are built with admin privileges, so this is not an issue, this ensures paths, libraries and so forth are correctly set system wide.

**Note** To avoid conflicts if you run the script, please ensure that:
-  You have `wget` installed
-  Create a new folder (`mkdir DC`)
-  There is no active conda python environment (`conda deactivate`) 
-  Update your path after running the script as suggested

**Note** Always download the `raw` scripts:

#### Example installation on Ubuntu/Debian based Linux
This script assumes you have sudo rights, and will install all dependencies in the system.
```bash
wget https://raw.githubusercontent.com/bencardoen/DataCurator.jl/main/scripts/install_debian.sh -O script.sh && chmod +x script.sh
./script.sh
```
This installs DataCurator in the global julia installation, from here you can run the Julia API.

First, ensure Julia is in the PATH so it can be found:
Then, start julia
```bash
 PATH="/opt/julia-1.8.5/bin:$PATH"
 cd
 cd test
 ```
Let's download a recipe and create an example data
```bash
wget https://raw.githubusercontent.com/bencardoen/DataCurator.jl/main/example_recipes/count.toml -O recipe.toml
```
and create an example data folder
```bash
mkdir testdir # If you name this differently, make sure to update the recipe
touch testdir/text.txt # Create an example file
```
Start Julia
```bash
julia --project=.
```
Inside Julia's REPL:
```julia
using DataCurator
# Load the recipe
config, template = create_template_from_toml("recipe.toml");  # Replace with your recipe, this function decodes your recipe
# Execute it
c, l, r = delegate(config, template) # Returns counters, file lists, and return value (early exit)
```
You can also look at the [CLI script](https://github.com/bencardoen/DataCurator.jl/blob/main/scripts/curator.jl) for more advanced usage. 

**These instructions are run automatically, when in doubt check [the test scripts](https://github.com/bencardoen/DataCurator.jl/blob/7a7936ac1e97a1e842a2eeec0a7487f47167d46c/.circleci/config.yml#L24)** 

#### Example installation on Mac (M1/M2/x86)

This script assumes you have sudo rights, and will install all dependencies in the system.
```bash
wget https://raw.githubusercontent.com/bencardoen/DataCurator.jl/main/scripts/install_mac.sh -O script.sh && chmod u+x script.sh
./script.sh
```

This installs DataCurator in a local julia installation, from here you can run the Julia API (check the output of the script to find out where the Julia environment was installed).

```bash
PATH="$PATH:`pwd`/julia-1.8.5/bin"   # Ensure Julia can be found
pwd
cd 
cd test
```
Let's download a recipe and create an example data
```bash
wget https://raw.githubusercontent.com/bencardoen/DataCurator.jl/main/example_recipes/count.toml -O recipe.toml
```
and create an example data folder
```bash
mkdir testdir # If you name this differently, make sure to update the recipe
touch testdir/text.txt # Create an example file
```
Now start Julia
```
julia --project=.          
```
then
```julia
using DataCurator
# Read the recipe
config, template = create_template_from_toml("recipe.toml");
# Execute it
c, l, r = delegate(config, template)                          # Returns counters, file lists, and return value (early exit)
```
That's it

You can also look at the [CLI script](https://github.com/bencardoen/DataCurator.jl/blob/main/scripts/curator.jl) for more advanced usage.
 
<a name="advanced"></a>
### Advanced usage
If you want to use DataCurator to include your own code, or change DataCurator's code, you have 2 options:
- Update the build scripts above and rebuild.
- Update the Singularity image.

##### I want to modify the singularity container
Singularity images are by default for reproducibility **read-only**, but you can still alter them by adding an overlay if you need to, and sometimes you just do.

Let's say you want to add 4GB of changes, for example to include or update your own Python, Julia, or R packages. Or perhaps you want to update the packages (e.g. compiler) inside the container.

```bash
singularity overlay create --size 4096 datacurator.sif # Adds 4G of writeable space that is overlaid on top of the source image
sudo singularity shell --writable datacurator.sif      # Any changes are written in the overlay
Singularity>                                           # Enter shell commands that change state, as long as you don't change more than 4GB, you can do anything
```
Note that changes are compressed, so 4GB gets you a lot of space. 

Once you're confident your changes work as expected, you can add your changes to the build scripts and rebuild the image.
Sharing your updated build instructions then can let anyone build your version of the container, custom with your own extensions.

##### Rebuilding the container
See [buildimage.sh](https://github.com/bencardoen/DataCurator.jl/tree/main/buildimage.sh) and [recipe.def](https://github.com/bencardoen/DataCurator.jl/tree/main/singularity/recipe.def) on how the images are built if you want to modify them.

This script needs singularity installed, as well as git, zip, and wget.
```bash
./buildimage.sh # needs root
```

<a name="trouble"></a>
### Troubleshooting
#### I get file permission errors with the image, but the files are right here!

If you get read/write errors, but the files exist,  this is because the Singularity container by default has **no access except to your $HOME directory**. This is by design, to give it the least amount of privileges it needs to run (and alter data).
You can easily give it specific tailored access to data outside of your home directory, by using the -B flag. 
Use
```bash
singularity run -B /scratch image.sif ...
```
where /scratch is a directory you want read/write access to.
If you use this often, use a environment variable:
```bash
 export SINGULARITY_BIND="/opt,/data:/mnt"
```

#### It's so slow on first run !! (without the image)
If you use DataCurator as a Julia package or cloned repository, on first run Julia needs to compile functions and load packages. If you process large datasets, this cost (up to 20s) is meaningless. However, for smaller use cases it can be annoying.

You can avoid this cost, by precompiling. We already scripted this for you in the Singularity image, if you want to replicate this you can check the [recipe.def](https://github.com/bencardoen/DataCurator.jl/tree/main/singularity/recipe.def) file. 
Note that this does require extra installation steps, included in that script.

Precompiling can take up to 10-15 minutes, but is a one-time cost, and does not limit portability. 
A clear advantage is that you will run compiled code, not interpreted code, so the performance boost can be quite significant for code that is called only a few times but does heavy processing.

With the precompiled image stored in the container, you can both run at high speed without losing portability.

##### How do I control the number of threads ?
Use the environment variable `JULIA_NUM_THREADS=k` like so:
```bash
export JULIA_NUM_THREADS=5
```
If you want to disable multithreading, just set parallel=false in your recipe.

###### Optional
If you wish to use the remote capabilities (Owncloud, Slack, SCP), you need [curl](https://curl.se/download.html), [scp, and ssh](https://www.openssh.com/) installed and configured

##### Help ! None of my problems are covered here!
If any of the above is not clear, or not working, [please report an issue online](https://github.com/bencardoen/DataCurator.jl/issues/new/choose).

# DataCurator

A multithreaded package to validate, curate, and transform large heterogenous datasets using reproducible recipes, that can be created both in TOML human readable format, or in Julia.

![Concept](venn.png)

DataCurator is a Swiss army knife that ensures:
- pipelines can focus on the algorithm/problem solving
- you have a human readable recipe for future reproducibility
- you can validate huge datasets at speed
- you need no code or dependencies to do it

![Concept](whatami.png)

## Quickstart
### Installation
You can install DataCurator in 1 of 3 ways, as a Julia package in your global Julia environment, as a local package (no change to global), or completely isolated as a container or executable image.

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
julia>using Pkg; Pkg.activate("."); Pkg.instantiate(); Pkg.Test();
```


#### As executable image or container
You need:
- A command line environment (WSL on windows, any shell on Linux or MAC)

```bash
wget <URL TO DO>
```

#### Singularity

The container provides:
- Fedora 35 base environment
- Julia 1.6.2 base installation
- DataCurator installed in its own environment at /opt/DataCurator.jl

TODO download from sylabs + build

##### Get an interactive julia shell inside the container
```bash
singularity shell image.sif
Singularity>julia --project=/opt/DataCurator.jl
julia>
#OR to access the base Julia installation
Singularity>julia
julia>
```

##### Execute command line scripts with the container
```bash
singularity exec image.sif julia --project=/opt/DataCurator.jl -e 'using Logging; @info "Are you looking for 42?";'
```

###### Notes
- You get read/write errors, but the files exist:
    If you run into issues with files or directories not found, this is because the Singularity container by default has **no access except to your $HOME directory**. Use
    ```
    singularity run -B /scratch image.sif ...
    ```
    where /scratch is a directory you want read/write access to.

    A symbolic link from $HOME to a directory may work, ymmv.

- To see what the executable image actually does, see [singularity1p6.def](singularity1p6.def) in the `run` section

- You can't install package or update in the container:
    This is by design, the container image is **read-only**. It can access your $HOME directory, but nothing else. There are ways to modify the image, but:
    - It's not what you want
    - If it really is what you want, you probably already know how to do it (see Singularity docs)
    - If you really really want to modify the image, please do it the *right way*
      - change [singularity1p6.def](singularity1p6.def),
      - then (needs root)
        ```bash
        ./buildimage.sh
        ```

## Running
### Using TOML recipes
Our package does not require you to write code, so as long as you understand what you want to happen to your data, and you can read and write a text file, that's all it takes.

For example, extract all .txt files from a deep filesystem into a single flat directory
```toml
[global]
act_on_success = true
inputdirectory = "your/very/deep/directory/structure"
[any]
all=true
conditions = ["isfile", ["endswith", ".txt"]]
actions = [["flatten_to", "your/flattened_path"]]
```
Assuming inputdirectory and "your/flattened_path" exist, you can just do

```bash
./datacurator.sif --recipe your.toml --verbose
```
or
```bash
julia --project=. src/curator.jl --recipe your.toml --verbose
```

Verbose really is, well, verbose, it will activate all logging statements. Use this when you really want to see what is going on under the hood or if you think something is wrong. 99% of the time, you want to ``omit --verbose``.

Check example_recipes/documented_example.toml for all possible options in a single example.

## Manual
A more extensive manual is available at [manual.md](manual.md)

## Troubleshooting

#### Conditions not working as expected
- Check if you used regex syntax without setting regex=true
- Check the log to see if your conditions are being recognized
#### I'm getting weird non-deterministic results
- If you use parallel=true, and global variables, and no locks, then that is expected, use the lists to aggregate anything in a threadsafe way
#### Things are slower with parallel=true
- If you have small data on a fast filesystem, the gain of using threads is minimal, and so overhead begins to dominate. Use parallel=true if you have a lot of files, need to read/check large files, a slow filesystem, and/or deep hierarchies. By default, the nr of threads = ``$JULIA_NUM_THREADS`` = nr of cores. So on a cluster, think if that makes sense for you. For small to medium datasets I'd be surprised if you gain from more than 16 threads. On the other hand, for large (>1TB, 1e6 files) datasets, 24+ has worked for me.
#### I told your code to quit, but it kept going for some time.
- With ``parallel=true``, it can take time before all other threads get the message that they too should quit, not just the thread that's doing work. Without a locked global that is continuously checked, in which case performance drops extremely, there's no way to avoid this. If you need a brusque "drop everything" exit, then use a function like

    ```julia
    end_times = x -> exit(-1)
    ```
    Don't expect counters, filelists etc to be in a usable state if you do this.

A more detailed explanation:

Assume your data is structured like this, and you specify `traversal=topdown`.
You set `conditions=["contains", "A"]` and `actions=["quit"]` with `act_on_success=true` and `counter_actions=["log_to_file", "notA.txt"]`

- Top directory
  - A [quit here]
    - a
    - b
  - B
    - a
    - b
With `parallel=false`, notA.txt will be empty or read
```
B
```
depending on the order in which your filesystem returns listings.
We do not sort by default, that is _extremely_ expensive to do on HPC filesystems.

With `parallel=true`, notA.txt can be
```
B
a
b
```
or
```
B
```
but **never**
```
A
a
b
B
a
b
```

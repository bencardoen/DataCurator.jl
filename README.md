# DataCurator

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

## Documentation [![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://bencardoen.github.io/DataCurator.jl/stable)
After cloning / downloading, please open [docs/build/index.html](docs/build/index.html) with a browser.
This will be replaced by github pages + actions.
Or build yourself
```bash
cd docs
julia --project=.. make.jl
```
Then open docs/build/index.html

## What to find where
```bash
repository
├── example_recipes              ## Start here for easy to copy example recipes
├── docs
│   ├── builds
│   │   ├── index.html           ## Documentation
│   ├── src                      ## Markdown sources for docs
│   │   ├── make.jl              ## `cd docs && julia --project=.. make.jl` to rebuild docs
├── src                          ## source code of the package itself
├── test                         ## test suit and related files
└── runjulia.sh                  ## Required for Singularity image
└── buildimage.sh                ## Rebuilds singularity image for you (Needs root !!)
└── singularity1p6.def           ## Singularity definition file, also useful if you need to reproduce this work somewhere else without a container or Julia as system installation
```

**Anything below this line is no longer updated and will be removed**

## Table of Contents
1. Quickstart
2. [Installation](#install)
   1. [Installing]
      1. Julia package
      2. Cloned repository
      3. Singularity image
      4. Executable image
   2. [Updating](#updating)
   3. [Tests](#tests)
3. [Running](#running)
   1. Dataset Validation
   2. Dataset Curation
   3. [Ready to use TOML Examples](#examples)
4. [List of Actions and Conditions you can use in recipes](#list)
5. [Aggregation (aka filter-map-reduce)](#mapreduce)
6. [Julia API](#julia)
7. [Troubleshooting](#troubleshooting)

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
julia>using Pkg; Pkg.activate("."); Pkg.instantiate(); Pkg.test();
```


#### As an executable image
You need:
- A command line environment (WSL on windows, any shell on Linux or MAC)

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
      - if you don't have root (you always have root in a VM btw), use Sylabs's remote builder with our definition file.

### Updating
Globally installed package

```julia
julia> using Pkg; Pkg.update("DataCurator")
```

Repository
```bash
cd DataCurator.jl
git pull origin main
julia
julia>using Pkg; Pkg.activate(".");
```

Singularity image
- Redownload/rebuild

### Tests
```julia
julia>using Pkg; Pkg.test("DataCurator")
#or
julia>using Pkg; Pkg.activate("."); Pkg.test();
```

## Running
Our package does not require you to write code, so as long as you understand what you want to happen to your data, and you can read and write a text file, that's all it takes.
### Dataset Validation: minimal example. <a name="validation"></a>
The simplest example is the following `recipe`, which checks that your dataset only contain 3D images, and warns for anything that is not a 3D image.

```toml
[global]
inputdirectory="your_data_directory"
[any]
conditions=["is_3d_img"]
actions=["show_warning"]
```
Because this is the simplest example, it does not showcase the full power, so please see folder [example_recipes](example_recipes) for the large set of examples, each illustrating a different feature to help you validate datasets.
### Dataset Curation: minimal example. <a name="curation"></a>
Instead of validating, now we want to do a maximum projection of all 3d images over the Z axis. We also want to save all 2D images in lowercase, and as copies, so as to leave the original data intact.
```toml
[global]
act_on_succes=true
inputdirectory="your_data_directory"
[any]
conditions=["is_3d_img"]
actions=[{name_transform=["tolowercase"], content_transform=[["reduce_image", ["maximum", 2]]], mode="copy"}]
```

##### Run your minimal TOML recipe
Now it's time to execute your template, save the above snippet in a file called `template.toml`, and execute
```bash
./datacurator.sif --recipe template.toml --verbose
```
or
```bash
julia --project=. src/curator.jl --recipe template.toml --verbose
```

Verbose really is, well, verbose, it will activate all logging statements. Use this when you really want to see what is going on under the hood or if you think something is wrong. 99% of the time, you want to ``omit --verbose``.

Check [example_recipes/documented_example.toml]([example_recipes/documented_example.toml]) for all possible options in a single example.


##### Alternative ways of running DataCurator
Assuming you have the singularity image (does not require Julia, nor installation of dependencies)
```bash
image.sif -r <your_toml_recipe> [--verbose]
```

If you have Singularity, you can do more advanced things
```bash
singularity exec image.sif julia --project=/opt/DataCurator.jl opt/DataCurator.jl/src/curator.jl --recipe "my_recipe.toml"
```

If you have the package cloned in this directory
```julia
julia --project=. src/curator.jl --recipe "my_recipe.toml"
```


### Ready to use TOML Examples <a name="examples"></a>

Check the directory example_recipes for examples on how to achieve a whole range of tasks, a select few are illustrated below:

##### Find all csvs with 10 columns and fuse them into 1 large table, called table.csv
  ```toml
  [global]
  act_on_success=true
  inputdirectory = "/dev/shm/inputtables"
  file_lists = ["table"]
  [any]
  all=true
  conditions = ["is_csv_file", ["has_n_columns", 10]]
  actions=[["add_to_file_list", "table"]]
  ```
##### Rename only deconvolved (16bit) tif (image) files, replacing spaces with _ and uppercase to lowercase
  ```toml
  [global]
  act_on_success=true
  inputdirectory = "/dev/shm/input_spaces_upper"
  [any]
  all=true
  conditions = ["has_whitespace", "is_tif_file", "is_16bit_img"]
  actions=[["transform_inplace", ["whitespace_to", '_'], "tolowercase"]]
  ```
##### Create lists of files to process, and an equivalent list where to save the corresponding output, to be sent to batch processing
This is common for cluster/HPC schedulers, where you'd give the scheduler an input and output lists of 100s if not 1000s of input/output pairs. While we're at it, compute the size in bytes of all target files.
  ```toml
  [global]
  act_on_success=true
  counters = [["c1", "size_of_file"]]
  file_lists = ["infiles", ["outfiles", "/my/outpath"]]
  inputdirectory = "/data/directory"
  [any]
  all=true
  conditions = ["is_3d_img"]
  actions=[["count", "c1"], ["add_to_file_list", "infiles"], ["add_to_file_list", "outfiles"]]
  ```
  This will generate an **infiles.txt** and **outfiles.txt** containing e.g. "/a/b/c/e.tif" and "/my/outpath/e.tif". The advantage over doing this with your own for loops/scripts, is that you only need the recipe, it'll run in parallel without you having to worry about synchronization/data races, and it'll just work, so you get to do something more interesting.

##### Verify a complex, deep dataset layout.
This is the same as the Julia API equivalent below, but then in toml recipe
  ```toml
  [global]
  act_on_success=false
  hierarchical=true
  inputdirectory = "inputdirectory"
  ## Suppose we expect 2 3D channels (tif) for each cell, and we have a dataset like
  ## Root
  ###  Replicatenr
  ####  Celltype
  #####  Series cellnr
  ######  ...[1,2].tif

  # For now we just want a warning when the data does not like it should be

  ## If we see anything else than the structure below, complain
  [any]
  conditions=["never"]
  actions = ["show_warning"]
  ## Top directory, only sub directories
  [level_1]
  conditions=["isdir"]
  actions = ["show_warning"]
  ## Replicate directory, should be an integer
  [level_2]
  all=true
  conditions=["isdir", "integer_name"]
  actions = ["show_warning"]
  ## We don't care what cell types are named, as long as there's not unexpected data
  [level_3]
  conditions=["isdir"]
  actions = ["show_warning"]
  ## Final level, directory with 2 files, and should end with cell nr
  [level_4]
  all=true
  conditions=["isdir", ["has_n_files", 2], ["ends_with_integer"]]
  actions = ["show_warning"]
  ## The actual files, we complain if there's any subdirectories, or if the files are not 3D
  [level_5]
  all=true
  conditions=["is_3d_img", ["endswith", "[1,2].tif"]]
  actions = ["show_warning"]
  ```
##### Early exit:
sometimes you want the validation or processing to stop immediately based on a condition, e.g. finding corrupt data, or because you're just looking for 1 specific type of conditions. This can be achieved fairly easily, illustrated with a trivial example that stops after finding something other than .txt files.
  ```toml
  [global]
  act_on_success = false
  inputdirectory = "testdir"
  [any]
  all = true
  conditions = ["isfile", ["endswith", ".txt"]]
  actions = ["halt"]
  ```
##### Regular expressions:
For more advanced users, when you write "startswith" "*.txt", it will not match anything, because by default regular expressions are disabled. Enabling them is easy though
  ```toml
  [global]
  regex=true
  ...
  condition = ["startswith", "[0-9]+"]
  ```
  This will now match files with 1 or more integers at the beginning of the file name. **Note** If you try to pass a regex such as *.txt, you'll get an error complaining about PCRE not being able to compile your Regex. The reason for this is the lookahead/lookback functionality in the Regex engine not allowing such wildcards at the beginning of a regex. When you write *.txt, what you probably meant was 'anything with extension txt', but not the name ".txt", which " *.txt " will also match. Instead, use "\.\*.txt". When in doubt, don't use a regex if you can avoid it. Similar to Kruger-Dunning, those who believe they can wield a regex with confidence, probably shouldn't.

##### Negating conditions:
By default your conditions are 'OR'ed, and by setting all=yes, you have 'AND'. By flipping action_on_succes you can negate all conditions. So in essence you don't need more than that for all combinations, but if you need to specifically flip 1 condition, this will get messy. Instead, you can negate any condition by giving it a prefix argumet of "not".
  ```toml
  [global]
  act_on_success = true
  inputdirectory = "testdir"
  regex=true
  [any]
  all=true
  conditions = ["isfile", ["not", "endswith", ".*.txt"]]
  actions = [["flatten_to", "outdir"], "show_warning"]
  ```

##### Counteractions:
When you're validating you'll want to warn/log invalid files/folders. But at the same time, you may want to do the actual preprocessing as well. This is where counteractions come in, they allow you to specify
  - Do x when condition = true
  - Do y when condition = false
  A simple example, filtering by file type:
  ```toml
  [global]
  act_on_success=true
  inputdirectory = "testdir"
  [any]
  conditions=["is_csv_file"]
  actions=[["log_to_file", "csvs.txt"]]
  counter_actions = [["log_to_file", "non_csvs.txt"]]
  ```
  or another use case is deleting a file that's incorrect, while transforming correct files in preparation for a pipeline, in 1 step.

##### Export to HDF5/MAT
  ```toml
  [global]
  act_on_success=true
  inputdirectory = "testdir"
  [any]
  conditions = ["is_tif_file", "is_csv_file"]
  actions=[["add_to_hdf5", "img.hdf5"], ["add_to_mat", "csv.mat"]]
  ```

## Modifying files and content
When you want precise control over what function runs on the content, versus the name of files, you can do so.
This example finds all 3D tif files, does a median projection along Z, then masks (binarizes) the image as a copy with original filename in lowercase.
```toml
[global]
act_on_success=true
inputdirectory = "testdir"
[any]
conditions=["is_3d_img"]
actions=[{name_transform=["tolowercase"], content_transform=[["reduce_image", ["maximum", 2]], "mask"], mode="copy"}]

```
The examples so far use `syntactic sugar`, they're shorter ways of writing the below, but in certain case where you need to get a lot done, this full syntax is more descriptive, and less error prone.
It also gives DataCurator the opportunity to save otherwise excessive intermediate copies.

The full syntax for actions of this kind:
```toml
actions=[{name_transform=[entry+], content_transform=[entry+], mode="copy" | "move" | "inplace"}+]
```
Where `entry` is any set of functions with arguments. The + sign indicates "one or more".
The | symbol indicates 'OR', e.g. either copy, move, or inplace.

## Aggregation <a name="mapreduce"></a>
When you need group data before processing it, such as collecting files to count their size, write input-output pairs, or stack images, and so forth, you're performing a pattern of the form
```julia
output = reduce(aggregator, map(transform, filter(test, data)))
```
Sounds complex, but it's intuitive, you
- collect data based on some condition (filter)
- transform it in some way (e.g. mask images, copy, ...)
- group the output and reduce it (all filenames to 1 file, ...)

Examples of this use case:
- Collect all CSV files, concat to 1 table
- Collect columns "x2" and "x3" of CSV files whose name contains "infected_C19", and concat to 1 table
- Collect all 2D images, and save to 1 3D stack
- Collect all 3D images, and save maximum/minimum/mean/median projection

The 2nd example is simply:
```toml
[global]
...
file_lists=[{name="group", transformer=["extract_columns", ["x2", "x3"]], aggregator="concat_to_table"}]
...
[any]
all=true
conditions=["is_csv_file", ["contains", "infected_C19"]]
actions=[["add_to_file_list", "group"]]
```

#### The maximum projection of 2D images

```toml
[global]
...
file_lists=[{name="group", aggregator=["reduce_images", "maximum"]}]
...
[any]
conditions=["is_2d_img"]
actions=[["add_to_file_list", "group"]]
```

#### The complete grammar:


```toml
file_lists=[{name=name, transformer=identity, aggregator=shared_list_to_file}+]
```
(X+) indicates at least one of X

The following aliases save you typing:
```toml
file_lists=["name"]
# is the same as
file_lists=[{name=name, transformer=identity, aggregator=shared_list_to_file}]
```
```toml
file_lists=[["name", "some_directory"]]
# is the same as
file_lists=[{name=name, transformer=change_path, aggregator=shared_list_to_file}]
```

You're free to specify as many aggregators as you like.

## Under the hood
When you define a template, a 'visitor' will walk over each 'node' in the filesystem graph, testing any conditions when appropriate, and executing actions or counteractions.
![Concept](concept.png)

In the background there's a lot more going on
- Managing threadsafe data structures
- Resolving counters and file lists
- Looking up functions
- Composing functions and conditions
- ...


## Using the Julia API <a name="julia"></a>

### Typesafe templates
We heavily use Julia's multiple type dispatch system, so when you make a template
```julia
template = [mt(is_tif_file, show_warning)]
```
it is internally transformed to a named tuple
```julia
template[1].condition == is_tif_file # true
template[1].action == show_warning
```
As a user this may not be relevant to you, but it does help in simplifying the code and optimizing the execution quite dramatically. The Julia compiler for example knows the difference at compile time between
```
fs = [is_tif_file, show_warning, quit]
A = mt(fs...) # condition, action, counteraction
fs = [is_tif_file, show_warning]
B = mt(fs...) # condition, action
```
A and B are resolved at compile time, not at runtime, improving execution speed while ensuring type safety.

To put it differently, your template is usually precompiled, not interpreted, as it would be in bash/Python scripts.

### Examples

#### Replace whitespace and uppercase
Rename all files/directories with ' ' in them to '_' and switch any uppercase to lowercase.
```julia
condition = x -> is_upper(x) | has_whitespace(x)
fix = x -> whitespace_to(lowercase(x), '_')
action = x -> transform_inplace(x, fix)
transform_template(rootdirectory, [mt(condition, action)]; act_on_success=true)
```
Next, we verify our dataset has no uppercase/whitespace in names.
```julia
count, counter = generate_counter()
verify_template(rootdirectory, [mt(condition, counter)]; act_on_success=true)
@info count
```


#### Flatten a file hierarchy
```julia
action = x->flatten_to(root, x, newdirectory)
verify_template(root, [mt(isfile, action)]; act_on_success=true)
```

#### Extract all 3D tif files to a single directory
Note, this will halt if the images it extracts exist on the target directory.
```julia
trigger = x-> is_3d_img(x)
action = x->flatten_to(root, x, image_directory)
verify_template(root, [mt(trigger, action)]; act_on_success=true)
```
#### Sort 2D image and csv files into separate directories
```julia
img_action = x->flatten_to(root, x, image_directory)
csv_action = x->flatten_to(root, x, csv_directory)
verify_template(root, [(mtis_2d_img, img_action), (is_csv_file, csv_action)]; act_on_success=true)
```

#### Compute size in bytes of a large hierarchy in parallel
```julia
count, counter = generate_size_counter()
verify_template("rootdirectory", [mt(isfile, counter)]; act_on_success=true)
@info "Size of matched files = $(count) bytes"
```

#### Compute size of 2 vs 3D images separately
```julia
count2, counter2 = generate_size_counter()
count3, counter3 = generate_size_counter()
verify_template("rootdirectory", [mt(is_2d_img, counter2),(is_3d_img, counter3)]; act_on_success=true)
@info "$(count2) bytes of 2D images, $(count3) of 3D images"
```

#### Hierarchical recipes
Suppose your data is supposed to have this layout
- root
  - replicate nr
    - celltype
      - cell nr : of the form "Series XYZ"
        - 2 tif files, 3D, ending with 1,2.tif


You can use **hierarchical** templates, that give you very precise control of where a condition fires
##### Create a hierarchical template
```julia
onfail = x->show_warning
template = Dict()
```
##### First, define what to do with unexpected directories/files
```julia
template[-1] = [mt(never, onfail)]
```
*never* is a shortcode symbol for 'will never pass'
#####  At root, we only expect sub directories
```julia
template[1] = [mt(isdir, onfail)]
```
##### Replicate should be integer
```julia
template[2] = [mt(x->all_of(x, [isdir, integer_name]), onfail)]
```
##### Celltype should only be subdirs
```julia
template[3] = [mt(isdir, onfail)]
```
##### Lowest data directory should end with cell nr, and have 2 or more files
```julia
inputdir_check = x->all_of(x, [isdir, x->ends_with_integer(x), x->n_files_or_more(x, 2)])
template[4] = [mt(inputdir_check, onfail)]
```
##### Actual files should be 3D images
```julia
file_check = x -> is_tif_file(x) & is_3d_img(x) & endswith(x, r"[1,2].tif")
template[5] = [mt(file_check, onfail)]
```
##### Execute
```julia
verify_template(root, template; traversalpolicy=topdown, parallel_policy="parallel")
```
###### Advanced
You are free to define even more complex actions, for example, triggers that fire on invalid data AND valid data in 1 template.
For example, let's say we expect csv files, and if we find tif files, then we delete those, otherwise we just warn.
```julia
template[y] = [mt(x->~is_tif_file(x), delete_file), mt(is_csv_file, onfail)]
```

## Fire triggers when they are true, not when they fail
If it's hard to define conditions that should succeed, you can reverse the firing conditions, but more easily readable is just asking the verifier to do so for you
```julia
verify_template(root, template; act_on_succes=true)
```


### Parallel execution
All recipes can be executed in parallel. Counters are protected so they are threadsafe, yet need no locks.
```julia
count, counter = generate_counter(true; incrementer=size_of_file)
verify_template("rootdirectory", [mt(condition, counter)]; parallel_policy="parallel", act_on_success=true)
@info "Size of matched files = $(count) bytes"
```

### Data type support
- Any file manipulation :
  - rename, copy, delete
- CSV / DataFrames : fusing, reading
- Images
- HDF5 (export data to)
- MAT (export data to)

### Actions and conditions you can use in your TOML recipes <a name="list"></a>
For your convenience a whole set of 'shortcodes' are defined, those are symbols referring to often used functions, that you can use as-is in triggers/actions.
#### Conditions
```julia
is_csv_file
is_tif_file
is_png_file
integer_name
is_lower
is_upper
has_whitespace
is_img
is_kd_img
is_2d_img
is_3d_img
is_rgb
is_rgb
read_dir
files
has_n_files
n_files_or_more
less_than_n_files
subdirs
has_n_subdirs
always
never
read_postfix_int
read_prefix_int
read_int
read_postfix_float
read_prefix_float
read_float
is_8bit_img
is_16bit_img
column_names
has_n_columns
less_than_n_subdirs
is_hidden[_dir, _file]
```
#### Actions
```julia
whitespace_to
quit
proceed
filename
show_warning
quit_on_fail
log_to_file
ignore
sample
size_of_file
add_path_to_file_list
remove
delete_file
delete_folder
path_only
show_warning
log_to_file_with_message
remove_from_to
remove_from_to_extension_inclusive
remove_from_to_extension_exclusive
remove_from_to_exclusive
remove_from_to_inclusive
remove_pattern
replace_pattern
reduce_images
concat_table
extract_columns
stack_images
reduce_image + maximum, minimum, median, mean + dim : 1-N
```

If you're not familiar with Julia, the following are builtin

```julia
maximum/minimum/median/mean
size
isfile
isdir
ispath
splitpath
splitdir
splitext
basename
length
sum
isnothing
```

### Extending with your own conditions and actions
As long as your own functions are in scope, they can be used.
For example

```julia
using DataCurator
function myspecialcheck(x)
    @info x
    return true
end

fsym = lookup(myspecialcheck)
@info isnothing(fsym)==false
```

#### Interface
##### Conditions
```julia
function condition(x, ...) -> true,false
```
A condition is always passed as first argument the `node`, e.g. the current file or directory being evaluated. Anything else is up to you to specify.

Conditions should **NEVER** modify any state, especially not global state, and have 0 side-effects (no files, no logging, no changing files, ...)

##### Actions
```julia
function action(x, ...) -> :quit, :proceed
```
There are special cases, e.g. when functions are chained.
E.g. `tolowercase` will never return `:quit` or `:proceed`, but then you'd use it in a chain, as in
```julia
transform_copy(x, lowercase(x))
```

Not all functions can be chained, the template reader will consider chaining when you use `transform_copy` and `transform_inplace`.
See [example_recipes/remove_pattern.toml].

**Note**
If you are defining your own functions, there's a fine line between adding one or two convenience functions, and a whole slew of extras.
In the second case, what you actually want is using the Julia API.

You can still make your Julia template 100% reproducible by building a singularity image with your script, see the [definition file](singularity1p6.def) in this repo as an example.



## Troubleshooting

#### Startup time is so slow
Julia precompiles code, in a constant cost, so normally your workload is orders of magnitude higher than this compile time. For smaller loads, using a precompiled image can help:
```julia
julia --project=. setupimage.jl
```
This should create a file called 'sys_img.so', which contains precompiled versions of the code to build and execute a template. Note that this can take ~ 10 minutes or so.

To use this, all you need to do is tell Julia to use it.
```
julia --project=. --sysimage sys_img.so src/curator.jl ....
```
On a laptop this reduces latency from 16 seconds to 1.5 seconds. For large datasets this won't make a measurable difference (~TB)

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



### Why not use ...?
- Shell scripts / Linux tools
  - They're very powerful, modular, but the syntax/behavior is not always portable, and requires a certain expertise. Shell scripting is non-trivial if you want it to be robust and reproducible
- GLOST / Gnu Parallel
  - Both can execute large amount of jobs in parallel, but creating the jobs would require extra tools
- Python
  - Julia has a definitive advantage in its typing inference for safety and with JIT has a near C-like speed. Python lacks multiple dispatch, or typed dispatch, which is leveraged heavily in this package


### Our approach
- Uses Julia for speed without compromising on high level features
- Ensures portability by packaging everything in a single Singularity image so
  - it runs everywhere
  - it runs the same everywhere
  - no dependencies, not even Julia is needed
- Uses TOML configuration files, designed to be human readable, as **recipes**
- Runs in parallel, with a large set of predefined operations common to dataset processing

## Cite

## See also
DataCurator relies heavily on existing Julia packages for specialized functionality:
- Images.jl
- DataFrames.jl
- CSV.jl

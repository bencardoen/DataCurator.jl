# DataCurator

A multithreaded package to validate, curate, and transform large heterogenous datasets using reproducible recipes, that can be created both in TOML human readable format, or in Julia.

## Aims
- Enable fast expressive recipes to validate datasets
- Enable expressive conditional actions to remedy issues with datasets
- Enable conditional pre-processing
- Do not require expertise on the user, make templates interpretable
- Do not require the user to write or change code, recipes can be TOML files designed to be human readable
- Enable reproducible data processing (pre and post)

## Why not use ...?
- Shell scripts / Linux tools
  - They're very powerful, modular, but the syntax/behavior is not always portable, and requires a certain expertise. Shell scripting is non-trivial if you want it to be robust and reproducible
- GLOST / Gnu Parallel
  - Both can execute large amount of jobs in parallel, but creating the jobs would require extra tools
- Python
  - Julia has a definitive advantage in its typing inference for safety and with JIT has a near C-like speed. Python lacks multiple dispatch, or typed dispatch, which is leveraged heavily in this package



## Quickstart recipes
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
actions = [["flatten_to", "/dev/shm/flattened_path"]]
```


Check the directory example_recipes for examples on how to achieve a whole range of tasks:
- Find all csvs and fuse them into 1 large table, called table.csv
  ```toml
  [global]
  act_on_success=true
  inputdirectory = "/dev/shm/inputtables"
  file_lists = ["table"]
  [any]
  conditions = ["is_csv_file"]
  actions=[["add_to_file_list", "table"]]
  ```
- Rename only tif (image) files, replacing spaces with _ and uppercase to lowercase
  ```toml
  [global]
  act_on_success=true
  inputdirectory = "/dev/shm/input_spaces_upper"
  [any]
  all=true
  conditions = ["has_whitespace", "is_tif_file"]
  actions=[["transform_inplace", ["whitespace_to", '_'], "tolowercase"]]
  ```
- Create lists of files to process, and an equivalent list where to save the corresponding output. This is common for cluster/HPC schedulers, where you'd give the scheduler an input and output lists of 100s if not 1000s of input/output pairs. While we're at it, compute the size in bytes of all target files.
  ```toml
  [global]
  act_on_success=true
  counters = [["c1", "size_of_file"]]
  file_lists = ["infiles", ["outfiles", "/my/outpath"]]
  inputdirectory = "/data/directory"
  [any]
  all=false
  conditions = ["is_3d_img"]
  actions=[["count", "c1"]]
  actions=[["add_to_file_list", "outfiles"]]
  ```
  This will generate an **infiles.txt** and **outfiles.txt** containing e.g. "/a/b/c/e.tif" and "/my/outpath/e.tif". The advantage over doing this with your own for loops/scripts, is that you only need the recipe, it'll run in parallel without you having to worry about synchronization/data races, and it'll just work, so you get to do something more interesting.

- Verify a complex, deep dataset layout. This is the same as the Julia API equivalent below, but then in toml recipe
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
  actions = ["warn_on_fail"]
  ## Top directory, only sub directories
  [level_1]
  conditions=["isdir"]
  actions = ["warn_on_fail"]
  ## Replicate directory, should be an integer
  [level_2]
  all=true
  conditions=["isdir", "integer_name"]
  actions = ["warn_on_fail"]
  ## We don't care what cell types are named, as long as there's not unexpected data
  [level_3]
  conditions=["isdir"]
  actions = ["warn_on_fail"]
  ## Final level, directory with 2 files, and should end with cell nr
  [level_4]
  all=true
  conditions=["isdir", ["has_n_files", 2], ["ends_with_integer"]]
  actions = ["warn_on_fail"]
  ## The actual files, we complain if there's any subdirectories, or if the files are not 3D
  [level_5]
  all=true
  conditions=["is_3d_img", ["endswith", "[1,2].tif"]]
  actions = ["warn_on_fail"]
  ```
- Early exit: sometimes you want the validation or processing to stop immediately based on a condition, e.g. finding corrupt data, or because you're just looking for 1 specific type of conditions. This can be achieved fairly easily, illustrated with a trivial example that stops after finding something else than .txt files.
  ```toml
  [global]
  act_on_success = false
  inputdirectory = "testdir"
  [any]
  all = true
  conditions = ["isfile", ["endswith", ".txt"]]
  actions = ["halt"]
  ```
- Regular expression: for more advanced users, when you write "startswith" "*.txt", it will not match anything, because by default regular expressions are disabled. Enabling them is easy though
  ```toml
  [global]
  regex=true
  ...
  condition = ["startswith", "[0-9]+"]
  ```
  This will now match files with 1 or more integers at the beginning of the file name.

#### Usage
Assuming you have the singularity image (does not require Julia, nor installation of dependencies)

```bash
singularity exec image.sif julia --project=/opt/DataCurator.jl opt/DataCurator.jl/src/curator.jl --recipe "my_recipe.toml"
```

If you have the package cloned in this directory
```julia
julia --project=. src/curator.jl --recipe "my_recipe.toml"
```

### Using Julia API
### Replace whitespace and uppercase
Rename all files/directories with ' ' in them to '_' and switch any uppercase to lowercase.
```julia
condition = x -> is_upper(x) | has_whitespace(x)
fix = x -> whitespace_to(lowercase(x), '_')
action = x -> transform_inplace(x, fix)
transform_template(rootdirectory, [(condition, action)]; act_on_success=true)
```
Next, we verify our dataset has no uppercase/whitespace in names.
```julia
count, counter = generate_counter()
verify_template(rootdirectory, [(condition, counter)]; act_on_success=true)
@info count
```


### Flatten a file hierarchy
```julia
action = x->flatten_to(root, x, newdirectory)
verify_template(root, [(isfile, action)]; act_on_success=true)
```

### Extract all 3D tif files to a single directory
Note, this will halt if the images it extracts exist on the target directory.
```julia
trigger = x-> is_3d_img(x)
action = x->flatten_to(root, x, image_directory)
verify_template(root, [(trigger, action)]; act_on_success=true)
```
### Sort 2D image and csv files into separate directories
```julia
img_action = x->flatten_to(root, x, image_directory)
csv_action = x->flatten_to(root, x, csv_directory)
verify_template(root, [(is_2d_img, img_action), (is_csv_file, csv_action)]; act_on_success=true)
```

### Compute size in bytes of a large hierarchy in parallel
```julia
count, counter = generate_size_counter()
verify_template("rootdirectory", [(isfile, counter)]; act_on_success=true)
@info "Size of matched files = $(count) bytes"
```

### Compute size of 2 vs 3D images separately
```julia
count2, counter2 = generate_size_counter()
count3, counter3 = generate_size_counter()
verify_template("rootdirectory", [(is_2d_img, counter2),(is_3d_img, counter3)]; act_on_success=true)
@info "$(count2) bytes of 2D images, $(count3) of 3D images"
```

### Hierarchical recipes
Suppose your data is supposed to have this layout
- root
  - replicate nr
    - celltype
      - cell nr : of the form "Series XYZ"
        - 2 tif files, 3D, ending with 1,2.tif

You can use **hierarchical** templates, that give you very precise control of where a condition fires
##### Create a hierarchical template, and what to do if something is wrong
```julia
onfail = x->warn_on_fail
template = Dict()
```
##### First, define what to do with unexpected directories/files
```julia
template[-1] = [(never, onfail)]
```
*never* is a shortcode symbol for 'will never pass'
#####  At root, we only expect sub directories
```julia
template[1] = [(isdir, onfail)]
```
##### Replicate should be integer
```julia
template[2] = [(x->all_of(x, [isdir, integer_name]), onfail)]
```
##### Celltype should only be subdirs
```julia
template[3] = [(isdir, onfail)]
```
##### Lowest data directory should end with cell nr, and have 2 or more files
```julia
inputdir_check = x->all_of(x, [isdir, x->ends_with_integer(x), x->n_files_or_more(x, 2)])
template[4] = [(inputdir_check, onfail)]
```
##### Actual files should be 3D images
```julia
file_check = x -> is_tif_file(x) & is_3d_img(x) & endswith(x, r"[1,2].tif")
template[5] = [(file_check, onfail)]
```
##### Execute
```julia
verify_template(root, template; traversalpolicy=topdown, parallel_policy="parallel")
```
###### Advanced
You are free to define even more complex actions, for example, triggers that fire on invalid data AND valid data in 1 template.
For example, let's say we expect csv files, and if we find tif files, then we delete those, otherwise we just warn.
```julia
template[y] = [(x->~is_tif_file(x), delete_file), (is_csv_file, onfail)]
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
verify_template("rootdirectory", [(condition, counter)]; parallel_policy="parallel", act_on_success=true)
@info "Size of matched files = $(count) bytes"
```

## Targets

A **target** is your datastore, in the simplest case a folder.

- Implemented
  - [x] Local Filesystems
  - [x] Parallel execution
- Future
  - [-] Archives
    - [-] JLD
    - [-] HDF5
    - [-] MAT

### Shortcodes
For your convenience a whole set of 'shortcodes' are defined, those are symbols referring to often used functions, that you can use as-is in triggers/actions.
```julia

is_csv_file
is_tif_file
is_png_file
whitespace_to
is_lower
is_upper
has_whitespace
quit
proceed
filename
integer_name
warn_on_fail
quit_on_fail
is_img
is_kd_img
is_2d_img
is_3d_img
is_rgb
read_dir
files
has_n_files
n_files_or_more
less_than_n_files
subdirs
has_n_subdirs
log_to_file
ignore
always
never
sample
size_of_file
read_postfix_int
read_prefix_int
read_int
read_postfix_float
read_prefix_float
read_float
```
If you're not familiar with Julia, the following are builtin
```julia
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

## User manual

### Usage
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


### Motivation
A computational pipeline will spend a significant amount of its code and development time in hardening against unexpected data, in pre and post-processing, and in dealing effectively with massive datasets (on clusters).
Often this results in a mix of scripts in different programming languages, created by people who may have moved on, and did not document why data was reorganized or processed in a given way. Reproduction, and adaptation to new datasets, is near impossible, compromising the scientific contributions it underlies.
To complicate matters, in interdisciplinary work, people designing and implementing the algorithms are not always those who curate datasets, nor those who actually acquire the data and have research questions to answer. Yet, as an example, few biologists know how to write a bash script on a cluster, let alone write one that will be robust and correct. Reviewers with access to the code will be hard pressed to reproduce or validate the used approach either.
In short, what is needed is an approach that
- validates large complex datasets
- transforms such datasets
- does it fast
- requires 0 coding expertise
- runs on without brittle dependencies, portably

### Why not use ...?
- Shell scripts / Linux tools
  - They're very powerful, modular, but the syntax/behavior is not always portable, and requires a certain expertise. Shell scripting is non-trivial if you want it to be robust and reproducible
- GLOST / Gnu Parallel
  - Both can execute large amount of jobs in parallel, but creating the jobs would require extra tools
- Python
  - Julia has a definitive advantage in its typing inference for safety and with JIT has a near C-like speed. Python lacks multiple dispatch, or typed dispatch, which is leveraged heavily in this package


## Our approach
- Uses Julia for speed without compromising on high level features
- Ensures portability by packaging everything in a single Singularity image so
  - it runs everywhere
  - it runs the same everywhere
  - no dependencies, not even Julia is needed
- Uses TOML configuration files, designed to be human readable, as **recipes**
- Runs in parallel, with a large set of predefined operations common to dataset processing


### TOML Examples

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
sometimes you want the validation or processing to stop immediately based on a condition, e.g. finding corrupt data, or because you're just looking for 1 specific type of conditions. This can be achieved fairly easily, illustrated with a trivial example that stops after finding something else than .txt files.
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

## Aggregation
When you need group data, such as collecting files to count their size, write input-output pairs, and so forth, you're performing a pattern of the form
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

## Using the Julia API

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

## Data type support
- Any file manipulation :
  - rename, copy, delete
- CSV / DataFrames : fusing, reading
- Images
- HDF5 (export data to)
- MAT (export data to)

### Actions and conditions you can use in your TOML recipes
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

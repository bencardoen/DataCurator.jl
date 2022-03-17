# DataCurator

A multithreaded package to validate, curate, and transform large heterogenous datasets using reproducible recipes, that can be created both in TOML human readable format, or in Julia.

## Aims
- Enable fast expressive recipes to validate datasets
- Enable expressive conditional actions to remedy issues with datasets
- Enable conditional pre-processing
- Do not require expertise on the user, make templates interpretable

## Why not use ...?
- Shell scripts / Linux tools
  - They're very powerful, modular, but the syntax/behavior is not always portable, and requires a certain expertise. Shell scripting is non-trivial if you want it to be robust and reproducible
- GLOST / Gnu Parallel
  - Both can execute large amount of jobs in parallel, but creating the jobs would require extra tools
- Python
  - Julia has a definitive advantage in its typing inference for safety and with JIT has a near C-like speed

## Parallel execution
All recipes can be executed in parallel. Counters are protected so they are threadsafe, yet need no locks.
```julia
count, counter = generate_counter(true; incrementer=size_of_file)
verify_template("rootdirectory", [(condition, counter)]; parallel_policy="parallel", act_on_success=true)
@info "Size of matched files = $(count) bytes"
```


## Quickstart recipes
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

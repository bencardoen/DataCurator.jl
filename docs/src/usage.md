## Usage

```@contents
Pages = ["usage.md"]
Depth = 5
```


## Using recipes only
```bash
./DataCurator.sif -r myrecipe.toml [---verbose]
```
or a bit more advanced:
```bash
singularity exec DataCurator.sif julia --project=/opt/DataCurator.jl --sysimage /opt/DataCurator.jl/sys_img.so /opt/DataCurator.jl/src/curator.jl --recipe myrecipe.toml
```
You can see why we made the executable image with the very short command, right?

However, it can be useful to explore the package more inside the singularity image

```bash
singularity exec DataCurator.sif julia <your script>
```

You can also open a shell inside the image
```bash
singularity shell DataCurator.sif
singularity>julia
julia 1.x>
```

## Recipes + Julia
Either run this in the image, or with the package
```julia
using DataCurator
result = create_template_from_toml("recipe.toml")
if ~isnothing(result) # result will be nothing if something went wrong creating your template
  c, t = res
  counters, lists, returnvalue = delegate(c, t)
end
```
You can next iterate over the counters or lists, if needed.
Note that aggregation operations at that point have completed.
```julia
for counter in counters
    @info counter
end
```
See the API reference for full details.

## Using the Julia API <a name="julia"></a>
When you can write Julia you can do anything the template recipes allow and extend it with your own functions, compile more complex functions, and so forth. In this section we'll walk you through how to do this.

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

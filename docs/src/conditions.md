# Actions and Conditions you can use in recipes

## Actions
### File/folder name:
```julia
whitespace_to  usage: ["whitespace_to", "_"]
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
remove_from_to                    usage: ["remove_from_to", "from_pattern", "to_pattern"], see example_recipes/remove_pattern.toml
remove_from_to_extension_inclusive
remove_from_to_extension_exclusive
remove_from_to_exclusive
remove_from_to_inclusive
remove_pattern
replace_pattern
read_postfix_int
read_prefix_int
read_int
read_postfix_float
read_prefix_float
read_float
```
### Content:
#### Image operations
These operations fall into 3 categories:
- Increase dimension, e.g. 10 2D images to 1 3D
- Decrease/reduce dimension, e.g. 10 2D images to 1 2D, or 1 3D to 1 2D
- Change voxels, but not dimension, e.g. mask, filter, ...
##### N to N+1 dimension:
```
stack_images
```
See the aggregation section for details.
##### N to N-1 dimension:
For aggregation (combine many images in N x 2D to 1 x 2D):
```
reduce_images
#usage
["reduce_images", ["maximum", 3]] for max projection on Z
```
For per image reduction (1 image, 3D -> 2D):
```
reduce_image + maximum, minimum, median, mean + dim : 1-N
# example:
["reduce_image" ,["maximum", 2]]
```
##### N to N
The image dimensions stay the same, but the voxels are modified
```
mask
```
#### Table operations
##### Aggregation
```toml
concat_table
```
##### Select columns
```toml
extract_columns  usage: ["extract_columns", ["x1", "x2"]]
```
##### Select/extract/delete rows based on column values
```toml
[command, [[columnname, operator, arguments],...]]
# or
[command, [columnname, operator, arguments]]
```
where 'command' is one of `extract`, `delete`.

The `operator` is one of:
```toml
less, leq, smaller than, more, greater than, equals, euqal, is, geq, isnan, isnothing, ismissing, iszero, <, >, <=, >=, ==, =, in, between, [not, operator]
```

!!! warning
    Do not use 'col','=','NaN' but `'col', 'isnan'`. Similar for iszero, isnothing, ... . Floating point rules specify that Nan!=Nan, so your condition will always be false.

##### Between
To express 1 < a < 2, where a is a column name, you could write
```julia
["a", ">", 1], ["a","<", 2]
```
You can save yourself typing, and just write:
```toml
["a", "between", [1, 2]]
```

!!! warning
    Make sure you pass a vector of 2 values!!

##### in
To find all values of a column in a defined set:

```toml
["a", "in", [2,3,5]]
```

##### Negating

You can also negate an operator, if that makes sense for your use case:

```toml
["a"], ["not" "in"], [[2,3,5]]
["a"], ["not" "between"], [[1, 2]]
```

## Conditions
Each action can only be applied if a condition fires.
This is a list of all conditions you can use, alone, in action-condition pairs, combined (with all=true), or nested:

### File/directory name conditions
```
integer_name # file or directory name is an integer, e.g. "2", "003", but not "One" or "_1"
is_lower
is_upper
has_whitespace
has_upper
has_lower
is_hidden[_dir, _file]
has_integer_in_name
has_float_in_name
```

### Directories
```toml
isdir/isfile
has_n_files
n_files_or_more
less_than_n_files
has_n_subdirs
less_than_n_subdirs
```

### File type checks
These check by file extension, they do NOT open files. Opening a file, or trying to figure out by not failing, is a slow operation compared to checking file extensions. You'll have to decide which is more appropriate, there are `is_img` and variants that do load an image to check.

```toml
is_csv_file
is_tif_file
is_png_file
has_image_extension
is_type_file # usage : ["is_type_file", ".csv"]
file_extension_one_of # usage : ["file_extension_one_of", [".csv", ".txt", ".xyz"]]
```

#### Image specific
!!! note Content type testing
    Testing if a file is an image means passing it to the image library and letting it try loading the file. For large files this can be expensive.

So instead of:

```toml
is_img
```

it's smarter to do:

```toml
["is_file", "is_tif_file", "is_img"]
```

!!! note RGB v 3D
    Julia uses the convention that RGB != 3D, which saves you from a lot of disambiguation. For example, is 10x10x10 32bit an RGB+alpha 3D image? Or just a 32bit Float 3D image? Julia will load the right type from the file, so it's one less worry.

```toml
is_img    # NOT the same as has_image_extension, this will try to load the file
is_kd_img # usage ["is_kd_img", 3]
is_2d_img
is_3d_img
is_rgb
is_8bit_img
is_16bit_img
```

#### Table specific
Table refers here to tabular data contained in CSV files, loading into Julia DataFrames. In short, if it has columns and rows, in a csv, it's a table.

Useful before you concatenate tables:

```toml
has_n_columns
has_less_than_n_columns
has_more_than_or_n_columns
```

Checking if your table has the right columns:

```toml
has_columns_named  # usage ["has_columns_named", ["Age", "Heart Rate"]]
```

This checks if those 2 columns are in the table, not if those are the only 2 columns.

### General

```toml
always, never
```

Self-explanatory, sometimes handly:
```julia
always = x -> true
never = x -> false
```

If you're testing conditions, you can use these as placeholders, for example.

If you're not familiar with Julia, the following are builtin:

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

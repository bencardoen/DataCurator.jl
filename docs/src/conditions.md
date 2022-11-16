# Actions and Conditions you can use in recipes


!!! tip "Don't repeat yourself"
    Quite often you will want to apply certain conditions or actions several times in a hierarchical template. In that case you can define `common_actions` and `common_condtions` in the `[global]` section, which you can refer to by name. Any of the actions and conditions below can be used to compose more complex actions and conditions.

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
remove
delete_file
delete_folder
path_only
file_smaller_than # Usage ["file_smaller_than" , "test.tif", "10GB"]
filepath
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
is_type_file   # Usage ["is_type_file", "csv"] to check if a file extension is csv
```

### Aggregation
When you use aggregation to combine files into lists, it can be helpful to transform filenames in a group, for example, ensuring only unique files are written to file, or they're sorted, rather than file traversal order.

!!! note "Aggregation 101"
    You specify in the `[global]` section, in the entry `file_list=...` what the name of a list is, and what, if any, needs to be done with the list of files, be it concatenate csvs to a table, reduce images, describe images, sort, ... . Once defined, you refer to them by name in actions.

You can use the following actions
```toml
actions=[["add_to_file_list", "listname"]]
# or
actions=[["add_to_file_list", ["listname", "listname2"]]
```
The second allows you to add a single file to multiple aggregation lists.
The following all do the same, but are defined to be used if they're more readable this way.
```toml
actions=[["aggregate_to", "listname"]]
actions=[["->", "listname"]]
```

Example
```toml
[global]
act_on_success=true
file_lists = [{name="table", aggregator=[["filepath",
                                          "sort",
                                          "unique",
                                          "shared_list_to_file"]]},
              {name="out", aggregator=[[["change_path", "/tmp/output"],
                                         "filepath",
                                         "sort",
                                         "unique",
                                         "shared_list_to_file"]]}
              ]
inputdirectory = "testdir"
[any]
all=true
conditions = ["is_csv_file"]
actions=[["add_to_file_list", "table"], ["add_to_file_list", "out"]]
```
This example collects all csv files, records only the path, not the file name, and creates 2 lists, in input/output pairs.
For example for files:
```toml
/a/b/c/1.csv
/a/b/c/2.csv
```
You will get two files:
```toml
#table.txt
/a/b/c  # The sorted unique path to 1, 2.csv
```
and
```toml
#out.txt
/tmp/output/a/b/c  # The sorted unique path to 1, 2.csv linked to new output directory
```
This can be useful when you're generating input / output lists for batch processing, where you pipeline expects to see a directory with csv files, and wants to write output to an equivalent location starting at a different path. (e.g. SLURM array jobs)

### Content:
#### Image operations
These operations fall into 3 categories:
- Increase dimension, e.g. 10 2D images to 1 3D
- Decrease/reduce dimension, e.g. 10 2D images to 1 2D, or 1 3D to 1 2D
- Keep dimension, but change voxels, but not dimension, e.g. mask, filter, ...
- Keep dimension, but reduce size: image slicing
##### N to N+1 dimension:
```
stack_images
```
A special case:
```
stack_images_by_prefix
```
This assumes you have files with a pattern like `A_1.tif, A_2.tif, ..., B_1.tif`.
If each has K dimensions, you'll end up with 1 file per prefix (here 2), with K+1 dimensions.

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
The image dimensions stays the same, but the voxels are modified

###### Transform image
```toml
mask
laplacian
gaussian, sigma
image_opening
image_closing
erode_image
dilate_image
```

###### Image thresholding
```toml
threshold_image, operator, value
otsu_threshold_image
```
where operator can be any of "<", ">", "=", "abs operator"

For example
```toml
"threshold_image", "abs >", 0.2
```
Sets all voxels where the magnitude (unsigned) > 0.2 to 0.

`otsu_threshold` computes the threshold automatically.

###### Resize/slice
```
slice_image, dimension, slice
slice_image, dimension, slice_from, slice_to
slice_image, [dimensions], [slices]
```
For example
```toml
"slice_image", [1,3], [[200,210],[1,200]]
```
which is equivalent to
```julia
img[200:210,:,1:200]
```

!!! warning Indexing
    Julia indices into array, image, tables, start at **1**, not 0. This is similar to Matlab, but unlike C/Python.
    Dimension=1 refers to the X-axis, and so forth.


#### Image statistics
To get a CSV table of statistics of the image intensity distribution you can do
```toml
describe_image[, axis]
```
Without axis 1 row per image is produced, with axis the distribution is computed along gives axis.
Example:
```bash
   minimum    Q1        mean      median    Q3        maximum  std       kurtosis  axis   source  slice
   Float64    Float64   Float64   Float64   Float64   Float64  Float64   Float64   Int64  String  Int64
│  0.0156863  0.258824  0.485621  0.454902  0.730392      1.0  0.283031    6.6581      0  1.tif       1
```
To describe objects in an image (assuming it's thresholded or can be binarized) (3D only)
```
describe_objects
```
Example
```
size     weighted  minimum    Q1        mean      median    Q3        maximum  std       kurtosis  xyspan   zrange   zmidpoint  filename
Float64  Float64   Float64    Float64   Float64   Float64   Float64   Float64  Float64   Float64   Float64  Float64  Float64    String
216.0   104.894  0.0156863  0.258824  0.485621  0.454902  0.730392      1.0  0.283031    6.6581  8.48528      6.0       23.0    ...
```
You can use this in aggregation, for example, to describe all objects in all channel 1 tifs
```toml
[global]
...
file_lists = [{name="objects", aggregator=[["describe_objects",
                                          "concat_to_table"]]},]
...
[any]
all=true
conditions = ["is_tif_file"]
actions=[[""aggregato_to", "objects"]]
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
filename_ends_with_integer
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
is_gsd
is_dlp
is_rainstorm
has_image_extension
is_type_file # usage : ["is_type_file", ".csv"]
file_extension_one_of # usage : ["file_extension_one_of", [".csv", ".txt", ".xyz"]]
```

#### Mesh support
```toml
is_mesh
load_mesh
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

##### Checking image dimensions
Either to verify correct data layout, or when you're going to slice images, it's handy to be able to check dimensions
```toml
size_image, [[dimension, operator, limit(s)],..]
```
Example:
```toml
"size_image", [[1, ">", 4], [2, ">", 4], [3, "between", [1, 1000]]
```
Operators: >, <, =, >=, <=, between, in

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

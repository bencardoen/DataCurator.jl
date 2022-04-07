## Actions and Conditions you can use in recipes

### Actions
```julia
whitespace_to   usage: ["whitespace_to", "_"]
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
reduce_images    usage: ["reduce_images", ["maximum", 3]] for max projection on Z

stack_images
reduce_image + maximum, minimum, median, mean + dim : 1-N
```
#### Table operations
```
concat_table
extract_columns  usage: ["extract_columns", ["x1", "x2"]]
extract          usage: ["extract", [col1, col2], [op1, op2], [val1, val2]]
delete          usage: ["delete", [col1, col2], [op1, op2], [val1, val2]
table operators : less, leq, geq, more, greater, equal, equals, isnan, isnothing, ismissing, between, in, not <operator>
```

!!! note
    isnan/missing/nothing: you do need to add a value, but it won't be used internally, e.g. NaN == NaN is never true, but we correct this internally to match your intent
    This is invalid:
    ```
    ["a", "b", "c"], ["less", "isnan", "more"], [3, 5]
    ```
    This is valid
    ```
    ["a", "b", "c"], ["less", "isnan", "more"], [3, "NaN", 5]
    ```

#### Between
To express 1 < a < 2, where a is a column name, you could write
```julia
["a", "a"], ["greater", "less"], [1, 2]
```
You can save yourself typing, and just write:
```julia
["a"], ["between"], [[1, 2]]
```
!!! warning
    Make sure you pass a vector of 2 values!!
#### in
To find all values of a column in a defined set:
```
["a"], ["in"], [[2,3,5]]
```
#### Negating
You can also negate an operator, if that makes sense for your use case:
```
["a"], ["not" "in"], [[2,3,5]]
["a"], ["not" "between"], [[1, 2]]
```

### Conditions
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

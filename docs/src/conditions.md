## Actions and Conditions you can use in recipes

### Actions
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

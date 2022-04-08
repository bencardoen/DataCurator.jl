# A recipe using all/most of the possible features
First, a recipe is a plain text file, in TOML format, designed to be as human friendly as possible.

We'll run through all, or most of the features you can use, with example TOML snippets.

Any `recipe` needs 2 parts, the global configuration, and the actual template.

The global configuration specifies **how** the template is applied, the template specifies the conditions/rules to apply, i.o.w. the **what** and **when**.

A *section* in a TOML file is simply:
```toml
[mysectionname]
mycontent="some value"
```

### Global section
```toml
[global]
```
All a minimum global section needs is where to start:
```toml
inputdirectory="your/directory"
```
Next, we can either act on failure (usually in validation), or on success.
This simply means that, if set to false, we check for any data that **fails** the rule you specify, then execute your actions.
In datacuration you'll want the inverse, namely, act on success.


!!! tip "You can have your cake and eat it"
    You can specify `actions` AND `counter_actions`, allowing you to specify what to do if a rule applies, and what if it doesn't. In other words, you have maximal freedom of expression.

```toml
act_on_success=false # default
```
We can also specify how we traverse data, from the deepest to the top (`bottomup`), or `topdown`.
If you intend to modify files/directories in place, `bottomup` is the safer option.

```toml
traversal="bottomup" # or topdown
```
We can validate or curate data in parallel, to maximize throughput. Especially on computing clusters this can speed up completion time. If true, will use as many threads as $JULIA_NUM_THREADS (usually nr of HT cores).

!!! note "Thread safety"
    You do not need to worry about `data races`, where you get non-deterministic or corrupt results, if you stick to our conditions and aggregations, there are no conflicts between threads.

```toml
parallel=true #default false
```

By default your rules are applied without knowing how deep your are in your dataset. However, at times you will need to know this, for example, to verify that certain files only appear in certain locations, or check naming patterns of directories.
For example, a path like `top/celltype/cellnr` will have a rule to check for a cell number (integer) at level 3, not anywhere else.
To enable this:

```toml
# If true, your template is more precise, because you know what to look for at certain levels [level_i]
# If false, define your template in [any]
hierarchical=true
```


For more complex pattern matching you may want to use Regular Expressions (regex), to enable this:

```toml
# If true, functions accepting patterns (endswith, startswith), will have their argument converted to a regular expression (using PRCE syntax)
regex = false
```

#### Aggregation
Aggregation is a complex word for use case like:
- counting certain files
- counting total size of a selection of files
- making lists of input/output pairs for pipelines
- combining 2D images into 1 3D image
- selecting specific columns from each csv you find, and fusing all in 1 table
- ...
You can do any of these all at the same time with `counters` and `file_lists` in the global section:

###### Counters
```toml
counters = ["C1", ["C2", "size_of_file"]]
```
Here we created 2 counters, one that is incremented whenever you refer to it, and one that when you pass it a fily, records it total size in bytes.
When the program finishes, these counters are printed.


###### Files to process
The simplest kind just adds a file each time you refer to it, and writes them out in traversal order (per thread if parallel) at the end to "infiles.txt"
```toml
file_lists = ["infiles"]
```
To make input-output pairs you'd do
```toml
file_lists = ["infiles", ["outfiles", "outputpath"]]
```
Let's say we add a file "a/b/c.txt" to infiles, when we add it to outfiles it will be recorded as: "/outputpath/a/b/c.txt"
This is a common use case in preparing large batch scripts on SLURM clusters.

##### Image aggregation
###### Stacking 2D images
```toml
file_lists = [{name="3dstack.tif", aggregator="stack_images"}]
```
###### Maximum projection of 3D images along the Y axis, then stack them.
```toml
file_lists = [{name="3dstack.tif", transformer=["reduce_images", ["maximum", 2]],aggregator="stack_images"}]
```
And so on ...
##### Table aggregation
```toml
file_lists = [{name="all_ab_columns.csv", transformer=["extract_columns", ["A", "B"]], aggregator="concat_to_table"}]
```

### Template
A template has 2 kind of entries `[any]` and `[level_X]`. You will only see the level_X entries in hierarchical templates, then X specifies at which depth you want to check a rule.

#### Flat templates, the Any section
```toml
[any]
all=false #default, if true, fuses all conditions and actions. If false, you list condition-action pairs.
conditions=["is_tif_file", ["has_n_files", 10]]
actions=["show_warning", ["log_to_file", "decathlon.txt"]]
counter_actions=[["add_to_file_list", "mylist"], ["log_to_file", "not_decathlon.txt"]] ## Optional
```

The `add_to_file_list` will pass any file or directory for which `is_tif_file` = true (see `act_on_success`) to a list you defined earlier called "mylist".
You specified in the global section what needs to be done with those files at the end.
You do not need counter_actions.

!!! tip "Negation and logical and"
    You can also negate and fuse conditions/actions. Actions can not be negated.
    ```toml
    conditions=[["not", "is_tif_file"], ["all", "is_2d_img", "is_rgb"]]]
    ```
    This is useful if you want to check for multiple things, but each can be quite complex. In other words, you want pairs of condition-action, so all=false, yet each pair is a complex rule.

#### Hierarchical templates, with `level_X`
All you now need to add is what to do at level 'X'
```toml
[global]
hierarchical=true
...
[level_3]
conditions=...
actions=...
...
```
This will only be applied if, and only if, files and directories 3 levels (directories) deep are encountered.

Sometimes you do not know how deep your dataset can be, in that case you'll want a 'catch-all', in hierarchical templates this is now the role of `any`
```toml
[global]
act_on_success=true
[any]
conditions=["is_csv_file"]
actions=["show_warning"]
[level_3]
conditions=["is_tif_file", "is_csv_file"]
actions=[["log_to_file", "tiffiles.txt"], "show_warning"]
```
This tiny template will write any tif file to tiffiles.txt.
If it encounters csv files anywhere else, it will warn you.

Please see the directory [example_recipes](../../example_recipes) for more complex examples.


### Advanced usage

##### Verify a complex, deep dataset layout.
This is an example of a real world dataset, with comments.

An example of a 'curated' dataset would look like this
```bash
root
├── 1                           # replicate number, > 0
│   ├── condition_1             # celltype or condition  # <- different types of GANs for generating data
│   │   ├── Series005           # cell number
│   │   │   ├── channel_1.tif   # first channel, 3D Gray scale, 16 bit
│   │   │   ├── channel_2.tif   # second channel, 3D Gray scale, 16 bit
...
├── 2
...
```
Let's create a `recipe` for this dataset that simply warns for anything unexpected.

###### Global section
We're validating data, so we'll specify what should be true, and only if our rules are violated, do we act.
Hence `act_on_success=false`, which is the default.
We have different rules depending on where in the hierarchy we check, so `hierarchical=true`.
And finally, we need a place to start, so `inputdirectory=root`
```toml
[global]
hierarchical=true
inputdirectory = "root"
```
###### The template
We specify what to do if we see anything that does not catch our (5-level) deep `recipe`, in the `[any]` section.
```toml
[any]
conditions=["always_fails"]        #if this rule ever is checked, say at level 10, it fails immediately
actions = ["show_warning"]
```
Next, we define rules for each level.
Levels:
```toml
## Top directory 'root', should only contain sub directories

[level_1]
conditions=["isdir"]
actions = ["show_warning"]   # if we see a file, isdir->false, so show a warning
## Replicate directory, should be an integer

[level_2]
all=true
conditions=["isdir", "integer_name"]  # again, no files, only subdirectories
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
conditions=["is_tif_file", ["endswith", "[1,2].tif"], ["not", "is_rgb"], "is_3d_img",]
actions = ["show_warning"]
```

!!! tip "Short circuit to help to speed up conditions"
    Note that we first check the file extension `is_tif_file`, and only then check the pattern `endswidth ...`, and only then actually look at the image type. Checking if an image is 3D or RGB requires loading it. Loading (potentially huge) files is slow and expensive, so this could mean we'd check 'is_3d_img' for a csv file, which would fail, but in a very expensive way.
    Instead, our conditions `short circuit`. We specified `all=true`, so each of them has to be true, if 1 fails we don't need to check the others. By putting `is_tif_file` first, we avoid having to even load the file to check its contents. This is done **automatically** for you, as long as you keep to the left-right ordering, in general of `cheap`(or least strict) to `expensive` (most strict). In practice for this dataset, this means a runtime gain of 50-90% depending on how much invalid data there is.

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

```
actions=[{name_transform=[entry+], content_transform=[entry+], mode="copy" | "move" | "inplace"}+]
```

Where `entry` is any set of functions with arguments. The + sign indicates "one or more".
The | symbol indicates 'OR', e.g. either copy, move, or inplace.

#### Select rows from CSVs and save them
```toml
[global]
act_on_success=true
inputdirectory = "testdir"
[any]
all=true
conditions=["is_csv_file", "has_upper"]
actions=[{name_transform=["tolowercase"], content_transform=[["extract", ("Count", "less", 10)]], mode="copy"}]
```
Table extraction has the following syntax:
```toml
["extract", (col, op, vals)]
```
or
```toml
["extract", (col, op)]
```
Wich then turns into:
```julia
select rows where op1(col1, vals1) && op2(col2, vals2)
```
For example:
```toml
["extract", ("name","=","Bert"),  ("count", "<", 10)]
```
Gives you a copy of the table with only rows where name='Bert' and count<10.

List of operators:
```julia
less, leq, smaller than, more, greater than, equals, euqal, is, geq, isnan, isnothing, ismissing, iszero, <, >, <=, >=, ==, =, in, between, [not, operator]
```
The operators `in` and `between` expect an array of values:
```julia
('count', 'in', [2,3,5])
```
and
```julia
('count', 'between', [0,100])
```
where the last is equivalent, but shorter (and faster) than:
```julia
('count', '>', 0), ('count', '<', 100)
```
### Aggregation
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

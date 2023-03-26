# DataCurator.jl Documentation
A multithreaded package to validate, curate, and transform large heterogeneous datasets using reproducible recipes, which can be created both in TOML human readable format, or in Julia.

![Concept](assets/datacurator-logos.png)

# Table of contents
- [Installation](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/installation.md)
- [Usage](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/usage.md)
- [Conditions](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/conditions.md)
- [Example Recipe](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/recipe.md)
- [Remote usage](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/remote.md)
- [Using Python or R](https://github.com/bencardoen/DataCurator.jl/blob/main/docs/src/extending.md)

```@contents
Depth = 5
```

![Concept](assets/venn.png)

DataCurator is a Swiss army knife that ensures:
- pipelines can focus on the algorithm/problem solving
- human readable `recipes` for future reproducibility
- validation huge datasets at high speed
- out-of-the-box operation without the need for code or dependencies

![Concept](assets/whatami.png)

## Quickstart
We'll show 2 simple examples on how to get started.

DataCurator works on `recipe`, TOML text files (see [examples](https://github.com/bencardoen/DataCurator.jl/tree/main/example_recipes)), which we will include inline here to illustrate how to use them.

**Note** All the examples are tested automatically, so you can rest assured that test work.

### Validate a dataset
Let's say we have a dataset, and you only expect it to contain CSV files. At this point, you don't care much about the structure or hierarchy of the files, or the naming patterns. 
You want to create a report (text file) with all csv files, and one with files or directories that are not.

```toml
[global]
inputdirectory = "testdir"
[any]
conditions=["is_csv_file"]
actions = [["log_to_file", "non_csvs.txt"]]
counter_actions=[["log_to_file", "csvs.txt"]]
```

Execute:

```bash
./DataCurator.sif -r myrecipe.toml
```
When it completes, you will now have 2 text files in your current working directory, `non_csvs.txt` and `csvs.txt`.

### Curate
So far we've been looking at file names and types, but DataCurator can look inside as well, and transform the contents.
Where validation only verifies datasets, and does not change them, curation can change the data. Often curation is step 2 after validation, it's nice to check if your expectations match data, but if they don't, you still need to intervene.

Let's say you have a dataset with image files in `tif` format. Rather than just building lists of them, or checking that they're there, for the right files we want to do some pre-processing. 
We also want to change the filenames, because they have a mix of upper and lower case, and the actual analysis pipeline we will feed them in later expects lowercase only.

Note that `#` is a comment line

```toml
# Start of the recipe, this configures global options
[global]
act_on_success=true
inputdirectory = "testdir"
# Your rules, `any` means you do not care at what level/depth files are checked
[any]
# When to act, in this case, you want to only work on tif files
conditions=["is_tif_file"]
# What to do
actions=[{name_transform=["tolowercase"], content_transform=[ ["gaussian", 3],
                                                                "laplacian",
                                                                ["threshold_image", "abs >", 0.01],
                                                                ["apply_to_image", ["abs"]],
                                                                "otsu_threshold_image",
                                                                "erode_image"], mode="copy"}]
```
This is already fairly complex, but it shows you that you can stack any number of `actions` on top of any number of `conditions`, giving you a lot of freedom.
And yet, you did not need to write any code.

In [full_api.toml](https://github.com/bencardoen/DataCurator.jl/blob/main/example_recipes/full_api.toml) you can see an example of how you can specify an entire image processing pipeline with a simple `recipe`.


### Troubleshooting
If you experience any problems, please [create an issue](https://github.com/bencardoen/DataCurator.jl/issues/new) with the DC version, template, and sample data to reproduce it, including the Julia version and OS.


### Acknowledgement
DataCurator could not work without packages such as:
- [Slack.jl](https://github.com/JuliaLangSlack/Slack.jl)
- [Images.jl](https://github.com/JuliaLangSlack/Images.jl)
- [PyCall.jl/Conda.jl](https://github.com/JuliaPy/Conda.jl)
- [RCall.jl](https://juliainterop.github.io/RCall.jl/stable/)
- [SlurmMonitor.jl](https://github.com/bencardoen/SlurmMonitor.jl)
and many many more, see [dependencies](https://github.com/bencardoen/DataCurator.jl/blob/main/Project.toml)

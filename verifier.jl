import DataCurator, Images
using DataCurator
using Base.Threads


## Recipe for MERC datasets
# Expects data to be organized as
# replicate (integer) / celltype / Serie[s] nr (integer) / *[1,2].tif (3D, 2x, single channel)

## Remove invalid channels
## Copy all correct channels
## Write a list of input directories
## Write a corresponding list of output directories

root = mktempdir()
for i in [1,2,3]
    for s in [14,25,28]
        pt = joinpath(root, "$i", "Type 2", "Serie $s")
        mkpath(pt)
        a = zeros(3, 3, 3)
        f0 = joinpath(pt, "channel_0.tif")
        Images.save(f0, a)
        f1 = joinpath(pt, "channel_1.tif")
        Images.save(f1, a)
        f2 = joinpath(pt, "channel_2.tif")
        Images.save(f2, a)
    end
end


function formatpath(x)
    parts = splitpath(x)
    parts[end] = "$(read_postfix_int(parts[end]))"
    return joinpath(parts...)
end



## Make counters to keep track of what changed
ec, count_error = generate_counter(true)
cc, count_correct = generate_counter(true)
sc, count_size = generate_counter(true; incrementer=size_of_file)
## SLURM needs lists of paths to process, let's build those
inlist, outlist = [make_shared_list() for _ in 1:2]
## Define where the output will be written
outpath = mktempdir()

## Define conditions and actions we want to take

### Create a log for both failed entries and valid entries
record_fail, record_correct = [x->log_to_file(x, X) for X in ["errors.txt", "correct.txt"]]

### Invalid data : warn, count, log and delete
onfail = x -> apply_all([warn_on_fail, count_error, record_fail, delete_file], x)

### Create 2 lists of input directories and output directories for the pipeline
on_input_dir = x -> apply_all([x->addentry!(inlist, x), x->addentry!(outlist, new_path(root, formatpath(x), outpath))], x)

### On valid entries: Count nr and size, log
onsuccess = x -> apply_all([count_correct, count_size, record_correct], x)


## Template
template = Dict()
## Verify dataset for MERCS

# Default : if not specified, it's an error
template[-1] = [(never, onfail)]

template[1] = [(isdir, onfail)]

template[2] = [(x->all_of(x, [isdir, integer_name]), onfail)]

template[3] = [(isdir, onfail)]

inputdir_check = x->all_of(x, [isdir, x->contains(basename(x), "Serie"), x->ends_with_integer(x), x->n_files_or_more(x, 2)])
template[4] = [(inputdir_check, onfail), (x->~inputdir_check(x), on_input_dir)]

file_check = x -> is_3d_img(x) & endswith(x, r"[1,2].tif")
template[5] = [(x->~file_check(x), onsuccess),(file_check, onfail)]


verify_template(root, template; traversalpolicy=topdown, parallel_policy="parallel")
@info "$(ec) failures with $(cc) correct files at total size of $(sc) bytes found"

## Write the collected input directories
shared_list_to_file(inlist, "test.in")
## And output directories
@info inlist
@info outlist
shared_list_to_file(outlist, "test.out")

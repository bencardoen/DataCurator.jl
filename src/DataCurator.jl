# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# Copyright 2022, Ben Cardoen
module DataCurator
using Base.Threads
import Random
import Images
import Logging
using LoggingExtras
using Match
using CSV
using DataFrames
import TOML
using HDF5
using MAT

export topdown, bottomup, expand_filesystem, visit_filesystem, verifier, transformer, logical_and,
verify_template, always, never, increment_counter, make_counter, read_counter, transform_template, all_of,
transform_inplace, ParallelCounter, transform_copy, warn_on_fail, quit_on_fail, sample, expand_sequential,
expand_threaded, transform_template, quit, proceed, filename, integer_name,
any_of, whitespace_to, has_whitespace, is_lower, is_upper, write_file,
is_img, is_kd_img, is_2d_img, is_3d_img, is_rgb, read_dir, files, subdirs, has_n_files, has_n_subdirs,
apply_all, ignore, generate_counter, log_to_file, size_of_file, make_shared_list,
shared_list_to_file, addentry!, n_files_or_more, less_than_n_files, delete_file, delete_folder, new_path, move_to,
copy_to, ends_with_integer, begins_with_integer, contains_integer, to_level, log_to_file_with_message,
safe_match, read_type, read_int, read_float, read_prefix_float, is_csv_file, is_tif_file, is_type_file, is_png_file,
read_prefix_int, read_postfix_float, read_postfix_int, collapse_functions, flatten_to, generate_size_counter, decode_symbol, lookup, guess_argument,
validate_global, decode_level, decode_function, tolowercase, handlecounters!, handle_chained, apply_to, add_to_file_list, create_template_from_toml, delegate, extract_template, has_lower, has_upper,
halt, keep_going, is_8bit_img, is_16bit_img, column_names, make_tuple, add_to_mat, add_to_hdf5, not_hidden, mt,
dostep, is_hidden_file, is_hidden_dir, is_hidden, remove_from_to_inclusive, remove_from_to_exclusive,
remove_from_to_extension_inclusive, remove_from_to_extension_exclusive,
less_than_n_subdirs, has_n_columns, path_only, add_path_to_file_list, remove, replace_pattern, remove_pattern, remove_from_to_extension, remove_from_to, stack_list_to_image, concat_to_table, make_aggregator

is_8bit_img = x -> eltype(Images.load(x)) <: Gray{N0f8}
is_16bit_img = x -> eltype(Images.load(x)) <: Gray{N0f16}
column_names = x -> names(CSV.read(x, DataFrame))
has_n_columns = (x, k) -> length(CSV.read(x, DataFrame))
path_only = x -> splitdir(x)[1]
remove = x -> delete_if_exists(x)
is_hidden_file = x-> isfile(x) && startswith(basename(x), ".")
is_hidden_dir = x-> isdir(x) && (startswith(basename(x), ".") || contains(basename(x), "__MACOSX"))
is_hidden = x -> is_hidden_file(x) || is_hidden_dir(x)
not_hidden = x -> ~is_hidden(x)
# log_to_file_message = (x, m) -> log_to_file()

function dostep(node::Any, t::NamedTuple{(:condition, :action), Tuple{Any, Any}}, on_success::Bool)
    @debug "Do-step for 2-tuple c/a for $node on_success=$(on_success)"
    if t.condition(node) == on_success
        @debug "Condition fired for $node with on_success == $(on_success)"
        rv = t.action(node)
        if rv == :quit
            @debug "Early exit for $node"
            return :quit
        end
        return :proceed
    else
        # rv = t.action(node)
        # if rv == :quit
        #     @debug "Early exit for $node"
        #     return :quit
        # end
        return :proceed
    end
end


function dostep(node::Any, t::NamedTuple{(:condition, :action, :counteraction), Tuple{Any, Any, Any}}, on_success::Bool)
    if t.condition(node) == on_success
        @debug "Condition fired for $node with on_success == $(on_success)"
        rv = t.action(node)
        if rv == :quit
            @debug "Early exit for $node"
            return :quit
        end
        return :proceed
    else
        @debug "Executing counteraction for $node"
        rv = t.counteraction(node)
        if rv == :quit
            @debug "Early exit for $node"
            return :quit
        end
        return :proceed
    end
end

function delete_if_exists(f)
    @warn "Removing $f"
    if isdir(f)
        rm(f; recursive=true)
    else
        if isfile(f)
            rm(f)
        end
    end
end

"""
    read_counter(counter)

    Sum a parallel or sequential counter where counter.data[threadid()]
"""
function read_counter(ct)
    return sum(ct.data)
end


function handlecounters!(val, key, glob_defaults)
    counter_entries = val
    cts = Dict()
    @info "Processing counters $(counter_entries)"
    for ce in counter_entries
        d = decode_counter(ce)
        if isnothing(d)
            @error "Failed decoding counters"
            throw(ErrorException("invalid counters"))
        else
            name, cpair = d
            cts[name]=cpair
        end
    end
    # @info cts
    glob_defaults["counters"] = cts
    return cts
end

function decode_filelist(fe::AbstractString, glob)
    lst = make_shared_list()
    adder = x->add_to_file_list(x, lst)
    aggregator = shared_list_to_file(lst, fe)
    return (fe, (lst, adder, aggregator))
end

function decode_filelist(fe::AbstractVector, glob)
    if length(fe) != 2
        @error "Failed decoding filelists $fe"
        raise(ErrorException("invalid lists"))
    end
    fn = fe[1]
    alter_root = fe[2]
    fs = lookup(alter_root)
    lst = make_shared_list()
    @warn "change to decode aggregator"
    if isnothing(fs)
        @info "Aggregator not set, assuming short code for shared_list_to_file[change_path, prefix]"
        change_path = x->new_path(glob["inputdirectory"], x, alter_root)
        adder = x->add_to_file_list(change_path(x), lst)
        aggregator = (l, f) -> shared_list_to_file(l, f)
        return (fn, (lst, adder, aggregator))
    else
        @info "Found aggregator $fs"
        adder = x->add_to_file_list(change_path(x), lst)
        aggregator = (l, f) -> fs(l, f)
        return (fn, (lst, adder, aggregator))
    end
end


function handlefilelists!(val, key, glob_defaults)
    file_entries = val
    cts = Dict()
    @debug file_entries
    for ce in file_entries
        d = decode_filelist(ce, glob_defaults)
        if isnothing(d)
            @error "Failed decoding filelists"
            throw(ErrorException("invalid lists"))
        else
            name, ctuple = d
            cts[name]=ctuple
        end
    end
    @debug cts
    glob_defaults["file_lists"] = cts
end


function handle_default!(val, key, glob_defaults)
    if key == "traversal"
        if val ∈ ["topdown", "bottomup"]
            glob_defaults[key] = Symbol(val)
            return
        else
            throw(ArgumentError("Invalid key $key - $val"))
        end
    end
    if typeof(glob_defaults[key]) != typeof(val)
        @error "Value $val for key $key in global section has the incorrect type. Check if you entered e.g. 'true' instead of true."
        throw(ArgumentError("Invalid key $key - $val"))
    end
    glob_defaults[key] = val
end

function decode_counter(c::AbstractString)
    @debug "Single counter"
    # (name, (count, counter))
    return (c, generate_counter(true))
end

function decode_counter(c::AbstractVector)
    @debug "Found complex counter"
    if length(c) != 2
        @error "Failed decoding $c"
        return nothing
    end
    name = c[1]
    sym = c[2]
    symbol = lookup(sym)
    if isnothing(symbol)
        @error "Failed decoding $c"
        return nothing
    else
        @debug "Counting with function $sym"
    end
    # (name, (count, counter))
    return (name, generate_counter(true;incrementer=symbol))
end

function decode_function(f::AbstractString, glob::AbstractDict; condition=false)
    fs = lookup(f)
    @debug "0 argument function lookup for $f"
    if isnothing(fs)
        @error "$f is not a valid function"
        return nothing
    end
    return x -> fs(x)
end


"""

    collapse_functions(fs; left_to_right=false)

    Generalization of (f, g) --> x->(f(g(x))) for any set of functions
    left_to_right : g(f(x)), otherwise f(g(x))
"""
function collapse_functions(fs; left_to_right=false)
    @debug "Collapsing chained functions L->R? $(left_to_right)"
    reduc = (f, g) -> x->f(g(x))
    fs = left_to_right ? reverse(fs) : fs
    return reduce(reduc, fs)
end


function handle_chained(f::AbstractVector, glob::AbstractDict; condition=false)
    fuser = f[1]
    remainder = f[2:end]
    chain = []
    if fuser ∈ ["transform_inplace", "transform_copy"]
        for candidate in remainder
            @debug "Decoding $candidate"
            cfs = decode_function(candidate, glob; condition=condition)
            isnothing(cfs) ? throw(ArgumentError) : nothing
            push!(chain, cfs)
        end
        functor = collapse_functions(chain; left_to_right=true)
        fsym = lookup(fuser)
        return x -> fsym(x, functor)
    else
        throw(ArgumentError("Invalid chain $f"))
    end
end

function remove_from_to(x, from, to; inclusive_first=true, inclusive_second=false)
    path, FN = splitdir(x)
    @debug "$x -> \n $path \n $FN"
    # @info FN
    @debug "Remove [$from - $to] from FN"
    B = findfirst(from, FN)
    if isnothing(B)
        @warn "$from not found in $x"
        return x
    end
    C = findfirst(to, FN[B.stop+1:end])
    if isnothing(C)
        @warn "$to not found in $x"
        return x
    end
    if inclusive_first
        PRE = FN[1:B.start-1]
    else
        PRE = FN[1:B.stop]
    end
    if inclusive_second
        POST = FN[B.stop+1+C.stop:end]
    else
        POST = FN[B.stop+1+C.start-1:end]
    end
    @debug "Prefix $PRE"
    @debug "Prefix $POST"
    JOINED = join([PRE, POST])
    return joinpath(path, JOINED)
end

function remove_from_to_extension(x::AbstractString, from::AbstractString; inclusive_first=true)
    if isdir(x)
        throw(ArgumentError("Not a file, so extensions do not make sense"))
    end
    path, FN = splitdir(x)
    FN, ext = splitext(FN)
    @debug "$x -> $path \n $FN \n $ext"
    # @info FN
    @debug "Remove [$from - $ext] from FN"
    B = findfirst(from, FN)
    if isnothing(B)
        @warn "$from not found in $x"
        return x
    end
    if inclusive_first
        PRE = FN[1:B.start-1]
    else
        PRE = FN[1:B.stop]
    end
    @debug "Remaining prefix $PRE"
    @debug "Remaining postfix $ext"
    JOINED = join([PRE, ext])
    return joinpath(path, JOINED)
end

remove_from_to_inclusive = (x, f, t) -> remove_from_to(x, f, t;inclusive_first=true, inclusive_second=true)
remove_from_to_exclusive = (x, f, t) -> remove_from_to(x, f, t;inclusive_first=false, inclusive_second=false)
remove_from_to_extension_inclusive = (x, f) -> remove_from_to_extension(x, f;inclusive_first=true)
remove_from_to_extension_exclusive = (x, f) -> remove_from_to_extension(x, f;inclusive_first=false)

function replace_pattern(x, ptrn, replacement)
    p, f = splitdir(x)
    fx = replace(f, Regex(ptrn)=>replacement)
    return joinpath(p, fx)
end

function remove_pattern(x::AbstractString, ptrn::AbstractString)
    return replace_pattern(x, ptrn, "")
end

function decode_function(f::AbstractVector, glob::AbstractDict; condition=false)
    # @info f
    negate = false
    if f[1] == "not"
        @info "Negate switched on"
        negate=true
    end
    if typeof(f[1])<:AbstractVector
        @debug "Nested function"
        if f[1][1] == "all"
            rem_f = f[1][2:end]
            subfs = [decode_function(_f, glob; condition=condition) for _f in rem_f]
            if condition
                @info "Nested condition"
                return x->all_of(subfs, x)
            else
                @info "Nested action"
                return x->apply_all(subfs, x)
            end
        else
            @error "$f is not valid nested function"
            throw(ArgumentError("$f"))
        end
    end
    if f[1] == "all"
        @debug "Nested actions"
        rem = f[2:end]
        _fs = [decode_function(_f, glob; condition=condition) for _f in rem]
        @debug fs
        throw(ArgumentError("Work in progress"))
        # return x->apply_all(decode_symbol(f))
        return x->apply_all(_fs, x)
    end
    # minlength = negate ? 3 : 2
    if length(f) < 2
        @error "$f is not a valid function, too few arguments"
        return nothing
    end
    if negate
        f = f[2:end]
        @info "Negate so function is $f"
    end
    fname = f[1]
    if startswith(fname, "transform_")
        @debug "Chained transform detected"
        return handle_chained(f, glob; condition=condition)
    end
    fs = lookup(fname)
    if isnothing(fs)
        @error "$fname is not a valid function"
        return nothing
    end
    completers = ["copy_to", "flatten_to", "move_to"]
    if fname ∈ completers
        @debug "Prefixing root directory for $fname"
        return x -> fs(x, glob["inputdirectory"], f[2:end]...)
    end
    if fname == "count"
        @debug "Resolving counter $f"
        counting_functor = lookup_counter(f, glob)
        return counting_functor
    end
    if fname == "add_to_file_list"
        @debug "Resolving file_writer $f"
        file_adder = lookup_filelists(f, glob)
        return file_adder
    end
    if glob["regex"]
        if fname ∈ ["startswith", "endswith", "contains"]
            @debug "Using Regex conversion"
            functor = x-> fs(basename(x), Regex(f[2]))
            return negate ? flipfunctor(functor) : functor
        end
    end
    functor = x -> fs(x, f[2:end]...)
    if negate
        return flipfunctor(functor)
    else
        return functor
    end
    # return negate ? flipfunctor(functor) : functor
end

function flipfunctor(f)
    return x -> ~f(x)
end

function lookup_filelists(tpl, glob)
    ac, fn = tpl
    @debug "Looking up FL on keyword $ac with name  $fn"
    if haskey(glob, "file_lists")
        @debug "Checking file list table"
        fl_table = glob["file_lists"]
        @debug fl_table
        if haskey(fl_table, fn)
            fl_object = fl_table[fn]
            _, fl_adder = fl_object
            @debug "Success!"
            return fl_adder
        end
    end
    @error "failed decoding filelists"
    return nothing
end

function lookup_counter(tpl, glob)
    ac, fn = tpl
    @debug "Looking up counter on keyword $ac with name  $fn"
    if haskey(glob, "counters")
        @debug "Checking counter table"
        counter_table = glob["counters"]
        @debug counter_table
        if haskey(counter_table, fn)
            counter_object = counter_table[fn]
            count, counter = counter_object
            @debug "Success!"
            return counter
        end
    end
    @error "failed decoding counter"
    return nothing
end

"""
    delegate(config, template)
    Uses the configuration, and template create by `create_template_from_toml', to execute the verifier as specified.
    Returns the counters and file lists, if any are defined.
"""
function delegate(config, template)
    parallel = config["parallel"] ? "parallel" : "sequential"
    rval =  verify_template(config["inputdirectory"], template; traversalpolicy=lookup(String(config["traversal"])), parallel_policy=parallel, act_on_success=config["act_on_success"])
    @debug "Return value == $rval"
    counters, lists = [], []
    for c in config["counters"]
        name, (count, counter) = c
        @debug "Counter named $name has value $count"
        push!(counters, read_counter(count))
    end
    for f in config["file_lists"]
        @info "Dealing with list $f"
        ## entry : name, list, aggregator
        ## aggregator(list, name)
        name= f[1]
        list= f[2][1]
        adder=f[2][2]
        aggregator=f[2][3]
        @info name list adder aggregator
        ## TODO f[1][2] - adder
        ## TODO f[1][3] - aggregator
        if contains(name, "table")
            @info "Found a list of csv's to fuse into 1 table to $(name).csv"
            shared_list_to_table(list, name)
        else
            @info "Saving list to $(name).txt"
            shared_list_to_file(list, "$(name).txt")
        end
        push!(lists, vcat(list...))
    end
    return counters, lists, rval
end


function shared_list_to_table(list, name)
    tables = []
    for sublist in list
        for csv_file in sublist
            @debug "Reading $csv_file"
            try
                tb = CSV.read(csv_file, DataFrame)
                push!(tables, tb)
            catch e
                @error "Reading $csv_file failed because of $e"
                throw(e)
            end
        end
    end
    DF = vcat(tables...)
    CSV.write("$name.csv", DF)
end

function stack_list_to_image(list, name)
    sz = nothing
    ims = []
    for sublist in list
        for img in sublist
            @debug "Reading $img"
            try
                tb = Images.load(img)
                if isnothing(sz)
                    sz = size(tb)
                end
                push!(ims, tb)
            catch e
                @error "Reading $img failed because of $e"
                throw(e)
            end
        end
    end
    N = length(ims)
    if N < 1
        @warn "No images to process for list $name"
        return
    end
    ET = eltype(ims[1])
    if length(sz) > 2
        throw(ArgumentError("Stacking images dim > 2 not supported yet"))
    end
    res = zeros(ET, sz[1], sz[2], N)
    for i in 1:N
        res[:,:,i] .= ims[i]
    end
    @info "Saving aggregated image"
    Images.save(name, res)
end

concat_to_table = shared_list_to_table

function validate_top_config(cfg)
    keys_c = keys(cfg)|>collect
    @info "Top level keys : $(keys_c)"
    if haskey(cfg, "global")
        if haskey(cfg["global"], "hierarchical")
            for k in keys_c
                if k ∈ ["any", "global"]
                    continue
                end
                m = match(r"^level_[0-9]+$", k)
                if isnothing(m)
                    @error "Unexpected key $k in hierarchical template, expecting: [global], [any], [level_x] where x > 0"
                    throw(ArgumentError("Invalid configuration key $k"))
                end
            end
        else
            accepted = ["global", "any"]
            if ~haskey(cfg, "any")
                @error "For a non-hierarchical template, you need 1 entry [any]."
                throw(ArgumentError("Missing [any] section"))
            end
            for k in keys_c
                if k in accepted
                    continue
                else
                    if startswith(k, "level_")
                        @error "Keys of form level_x are only valid when hierarchical=true in [global]"
                    end
                    @error "Invalid key $k in config for flat template"
                    throw(ArgumentError("Invalid key $k in config"))
                end
            end
        end
    else
        @error "No global section, invalid configuration"
        throw(ArgumentError("No [global] section in configuration"))
    end
end


function create_template_from_toml(tomlfile)
    config = TOML.parsefile(tomlfile)
    validate_top_config(config)
    glob = validate_global(config)
    @info "Global configuration"
    for key in keys(glob)
        @info "$key --> $(glob[key])"
    end
    if isnothing(glob)
        @error "Invalid configuration"
        return nothing
    end
    if glob["hierarchical"]
        @info "Hierarchical template"
        template = extract_template(config, glob)
    else
        @info "Flat template"
        if ~haskey(config, "any")
            @error "No section with conditions/actions specified, please add a section [any] with conditions, actions."
            return nothing
        end
        template = decode_level(config["any"], glob)
    end
    if isnothing(template)
        @error "Invalid configuration"
        return nothing
    end
    @info "Succesfully decoded your template."
    @debug "Decoded template to $template"
    return glob, template
end

function extract_template(config, glob)
    template = Dict()
    if haskey(config, "any")
        def = decode_level(config["any"], glob)
        if isnothing(def)
            return nothing
        end
        template[-1] = def
    end
    for k in keys(config)
        m = match(r"^level_[0-9]+$", k)
        if ~isnothing(m)
            lk = m.match
            level_nr = tryparse(Int, split(lk, '_')[2])
            level_temp = decode_level(config[k], glob)
            if isnothing(level_temp)
                return nothing
            end
            template[level_nr] = level_temp
        end
    end
    if length(template) == 0
        @error "Your template is empty !!"
    end
    return template
end


"""
    Helper function to parse all functions
"""
function parse_acsym(a, glob; condition=false)
    @debug "Parsing $a"
    parsed = decode_symbol(a, glob; condition=condition)
    if isnothing(parsed)
        throw(ArgumentError("Not a valid action or condition : $a"))
    end
    return parsed
end

function parse_all(acs, glob; condition=false)
    return [parse_acsym(ac, glob; condition=condition) for ac in acs]
end


function to_level(actions, conditions, counteractions; all=false)
    if all
        a_all = x->apply_all(actions, x)
        ca_all = x->apply_all(counteractions, x)
        co_all = x->all_of(conditions, x)
        return [make_tuple(co_all, a_all, ca_all)]
    else
        return [make_tuple(condition, action, counteraction) for (condition, action, counteraction) in zip(conditions, actions, counteractions)]
    end
end

function to_level(actions, conditions; all=false)
    if all
        a_all = x->apply_all(actions, x)
        co_all = x->all_of(conditions, x)
        return [make_tuple(co_all, a_all)]
    else
        return [make_tuple(condition, action) for (condition, action) in zip(conditions, actions)]
    end
end

function check_level_keys(level)
    accepted = ["all", "actions", "conditions", "counter_actions"]
    for k in keys(level)
        if k in accepted
            @debug "Key $k in level is valid"
        else
            @error "Key $k in level\n $level \n is not valid, should be one of \n $(accepted)"
            throw(ArgumentError("Invalid key $k"))
        end
    end
end


function decode_level(level_config, globalconfig)
    check_level_keys(level_config)
    all_mode = false
    if haskey(level_config, "all")
        if typeof(level_config["all"]) != Bool
            @error "Invalid value for 'all' -> $(level_config["all"]), expecting true or false"
            return nothing
        end
        all_mode=level_config["all"]
    end
    @debug "All mode --> $all_mode"
    actions = level_config["actions"]
    @debug "Actions --> $actions"
    conditions = level_config["conditions"]
    @debug "Conditions --> $conditions"
    coas = []
    if haskey(level_config, "counter_actions")
        counteractions = level_config["counter_actions"]
        @warn "Enabling Counter Action mode"
        if (length(actions) != length(conditions)) || (length(actions) != length(conditions))
            if all_mode ==false
                @error "Action and conditions do not align, this is accepted only when all=true"
                return nothing
            end
        end
        lvl = to_level(parse_all(actions,globalconfig;condition=false) , parse_all(conditions,globalconfig;condition=true) , parse_all(counteractions,globalconfig;condition=false) ;all=all_mode)
        @debug "decode level successful"
        return lvl
    else
        if length(actions) != length(conditions)
            if all_mode == false
                @error "Action and conditions do not align, this is accepted only when all=true"
                return nothing
            end
        end
        lvl = to_level(parse_all(actions, globalconfig) , parse_all(conditions, globalconfig) ;all=all_mode)
        @debug "Decode level success"
        return lvl
    end
    # ### If counteractions
    # ### tolevel(a,b,c)
    # ### else
    # ### tolevel(a,b)
    # level = []
    # @debug "Parsing actions & conditions"
    # # If actions < conditions, is this dropping things if all=true
    # if all_mode == false
    #     parsed_conditions = parse_all(conditions, globalconfig)
    #     parsed_actions = parse_all(actions, globalconfig)
    #     level = [[c,a] for (c,a) in zip(parsed_conditions, parsed_actions)]
    #     return level
    # else
    #     cs = parse_all(conditions, globalconfig)
    #     cas = parse_all(actions, globalconfig)
    #     @info "Fusing actions and conditions"
    #     level = [(x->all_of(cs, x), x->apply_all(cas, x) )]
    #     return level
    # end
end


"""
    Make a count and counting functor that can be incremented by threads
    ```
    c, ct = generate_counter()
    ct(something)
    @info c # "Counter = 1"
    # Threaded version
    pc, pct = generate_counter(true; x->reduce(*, size(x))))
    a = zeros(3,3,3)
    pct(a) # Threadsafe writes
    # Printing the counter is not threadsafe, only read when all threads have finished.
    @info pc # "Counter = 27"
"""
function generate_counter(parallel=true; incrementer=x->1)
    ct = make_counter(parallel)
    # counter = x->increment_counter(ct; inc=x->incrementer(x))
    return ct, x->increment_counter(ct; inc=incrementer(x))
end

function generate_size_counter(parallel=true)
    ct = make_counter(parallel)
    # counter = x->increment_counter(ct; inc=x->incrementer(x))
    return ct, x->increment_counter(ct; inc=size_of_file(x))
end

FR = r"[-+]?([0-9]*[.])?[0-9]+([eE][-+]?\d+)?"

is_type_file = (x, t) -> isfile(x) & endswith(x, t)
is_csv_file = x -> is_type_file(x, ".csv")
is_tif_file = x -> is_type_file(x, ".tif")
is_png_file = x -> is_type_file(x, ".png")
whitespace_to = (x, y) -> replace(x, r"[\s,\t]" => y)
tolowercase = x -> lowercase(x)
has_lower = x -> any(islowercase(_x) for _x in x)
has_upper = x -> any(isuppercase(_x) for _x in x)
is_lower = x -> ~has_upper(x)
is_upper = x -> ~has_lower(x)
has_whitespace = x -> ~isnothing(match(r"[\s,\t]", x))
show_warning = x -> @warn x
warn_on_fail = x -> show_warning(x)
halt = x -> begin @info "Triggered early exit for $x"; return :quit; end
quit = x -> return :quit
keep_going = x-> :proceed
filename = x->basename(x)
integer_name = x->~isnothing(tryparse(Int, filename(x)))
quit_on_fail = x -> begin @warn "$x"; return :quit; end
is_img = x -> isfile(x) & ~isnothing(try Images.load(x) catch e end;)
is_kd_img = (x, k) -> is_img(x) & (length(size(Images.load(x)))==k)
is_2d_img = x -> is_kd_img(x, 2)
is_3d_img = x -> is_kd_img(x, 3)
is_rgb = x -> is_img(x) & (eltype(Images.load(x)) <: RGB)
read_dir = x -> isdir(x) ? (readdir(x, join=true) |>collect) : []
files = x -> [_x for _x in read_dir(x) if isfile(_x)]
has_n_files = (x, k) -> isdir(x) & (length(files(x))==k)
n_files_or_more = (x, k) -> isdir(x) & (length(files(x))>=k)
less_than_n_files = (x, k) -> isdir(x) & (length(files(x))<k)
subdirs = x -> [_x for _x in read_dir(x) if isdir(x)]
has_n_subdirs = (x, k) -> (length(subdirs(x))==k)
less_than_n_subdirs = (x, k) -> (length(subdirs(x))<k)
log_to_file = (x, fname) -> write_file(fname, x)
log_to_file_with_message = (x, fname, reason) -> write_file(fname, "$(x) :: reason $(reason)")
ignore = x -> nothing
always = x->true
always_triggers = always
never = x->false
always_fails = never
sample = x->Random.rand()>0.5
size_of_file = x -> isfile(x) ? filesize(x) : 0

safe_match = (x, regex) -> isnothing(match(regex, x)) ? nothing : match(regex, x).match
read_type = (x, regex, type) -> isnothing(safe_match(x, regex)) ? nothing : tryparse(type, safe_match(x, regex))
read_postfix_int = x -> read_type(x, r"[0-9]+$", Int) #tryparse(Int, safe_match(x, r"[0-9]+$"))
read_prefix_int = x -> read_type(x, r"^[0-9]+", Int)
read_int = x -> read_type(x, r"[0-9]+", Int)
read_postfix_float = x -> read_type(x,  r"[-+]?([0-9]*[.])?[0-9]+([eE][-+]?\d+)?$", Float64) #tryparse(Int, safe_match(x, r"[0-9]+$"))
read_prefix_float = x -> read_type(x,  r"^[-+]?([0-9]*[.])?[0-9]+([eE][-+]?\d+)?", Float64)
read_float = x -> read_type(x, FR, Float64)
# count_error = (ct, _) -> increment_counter(ct)


"""
    apply_to(x, f; base=true)

        Where x is a path, if base=false, return f(x), otherwise works on the last part of the path
"""
function apply_to(x, f; base=true)
    if ~base
        return f(x)
    else
        p = splitpath(x)
        p[end] = f(p[end])
        return joinpath(p...)
    end
end


function validate_global(config)
    glob_defaults = Dict([("parallel", false),  ("counters", Dict()), ("file_lists", Dict()),("regex", false),("act_on_success", false), ("inputdirectory", nothing),("traversal", Symbol("bottomup")), ("hierarchical", false)])
    # glob = config["global"]
    glob_default_types = Dict([("parallel", Bool), ("counters", AbstractDict), ("file_lists", AbstractDict),("act_on_success", Bool), ("inputdirectory", AbstractString), ("traversal", Symbol("bottomup")), ("hierarchical", Bool)])
    ~haskey(config, "global") ? throw(MissingException("Missing entry global")) : nothing
    glob_config = config["global"]
    @debug glob_config
    if ~haskey(glob_config, "inputdirectory")
        @error "No data directory given, please define 'inputdirectory=your/data/dir'"
        return nothing
    else
        indir = glob_config["inputdirectory"]
        isdir(indir) ? nothing : throw(ArgumentError("$indir is not a valid directory"))
        if ~isabspath(indir)
            @warn "Input directory is not an absolute path, resolving..."
            ab = abspath(indir)
            @warn "...$indir -> $ab"
            indir = ab
        end
        glob_defaults["inputdirectory"] = indir
    end
    for key in keys(glob_config)
        @debug "Checking $key"
        val = glob_config[key]
        if haskey(glob_defaults, key)
            @match key begin
                "counters" => handlecounters!(val, key, glob_defaults)
                "file_lists" => handlefilelists!(val, key, glob_defaults)
                "inputdirectory" => nothing
                _ => handle_default!(val, key, glob_defaults)
            end
        else
            @error "Key $key in global not valid."
            return nothing
        end
    end
    return glob_defaults
end


function lookup(sym)
    try
        return getfield(DataCurator, Symbol(sym))
    catch
        @warn "No such symbol $sym"
        @warn "Trying user defined functions in Main"
        try
            return getfield(Main, Symbol(sym))
        catch
            @error "No such symbol $sym"
            return nothing
        end
    end
end

function guess_argument(str)
    if integer_name(str)
        return tryparse(Int, str)
    end
    fl = tryparse(Float64, str)
    if isnothing(fl)
        return str
    else
        return fl
    end
end


function decode_symbol(s, glob; condition=false)
    @debug "Decoding $s"
    return decode_function(s, glob; condition=condition)
end

function make_shared_list()
    return [[] for _ in 1:Base.Threads.nthreads()]
end

function addentry!(sharedlist, entry)
    push!(sharedlist[threadid()], entry)
end

add_to_file_list= (x, list) -> addentry!(list, x)

add_path_to_file_list = (x, list) -> addentry!(list, splitdir(x)[1])

function ends_with_integer(x)
    ~isnothing(match(r"[0-9]+$", basename(x)))
end

function begins_with_integer(x)
    ~isnothing(match(r"^[0-9]+", basename(x)))
end

function contains_integer(x)
    ~isnothing(match(r"[0-9]+", basename(x)))
end

function apply_all(fs, x)
    for f in fs
        @debug "Applying $f to $x"
        _rv = f(x)
        @debug "Short circuit break with rv is $(_rv)"
        if _rv == :quit
            @debug "Returning :quit"
            return :quit
        end
        @debug "Not quit, proceeding"
    end
    @debug "Returning proceed"
    return :proceed
end

function delete_file(x)
    if isfile(x)
        @warn "Deleting $x"
        rm(x; force=true)
    end
end

function delete_folder(x)
    if isdir(x)
        rm(x; force=true, recursive=true)
    end
end

function shared_list_to_file(list, fname)
    open(fname, "w"; lock=true) do f
        for sublist in list
            for entry in sublist
                write(f, pad(entry))
            end
        end
    end
end

function pad(msg)
    if ~endswith(msg, "\n")
        msg = msg * "\n"
    end
    return msg
end


function write_file(fname, msg)
    msg = pad(msg)
    open(fname, "a"; lock=true) do f
        write(f, msg)
    end
end


"""
    transform_inplace(x, f)
        x = f(x) for a file or directory. Refuses to act if x' exists.
"""
function transform_inplace(x, f)
    return transform_action(x, f; action=mv)
end

"""
    transform_copy(x, f)
        x' = f(x) for a file or directory, a copy rather than a move. Refuses to act if x' exists.
"""
function transform_copy(x, f)
    return transform_action(x, f; action=cp)
end

function transform_copy_to(x, f, oldroot, newroot)
    @warn "WIP"
    return transform_action(x, y->f(newpath(oldroot, y, newroot)))
end

function transform_flatten_to(x, f, newroot)
    @warn "WIP"
    error(-1)
end

function new_path(root, node, newroot)
    rp, np, nwp = splitpath(root), splitpath(node), splitpath(newroot)
    if node == root
        @warn "No-op for $root $node $newroot"
        return node
    end
    @assert length(rp) < length(np)
    LP = length(rp)
    # @info rp np[LP+1:end]
    newpath = joinpath(newroot, np[LP+1:end]...)
    mkpath(splitdir(newpath)[1])
    return newpath
end


"""
    /a/b/c, /a/b/c/d/e, /x/y
        if keeprelative
        -> /x/y/c/d/e
        if ~keeprelative
        -> /x/y/e
"""
function send_to(root, node, newroot; op=cp, keeprelative=true)
    if keeprelative
        np = new_path(root, node, newroot)
        if np == node
            return
        end
        op(node, np)
    else
        #/a "/a/b/c.txt" /Q --> Q/c.txt
        if isfile(node)
            fname = basename(node)
            newp = joinpath(newroot, fname)
            op(node, newp)
        else
            last = splitpath(node)[end]
            newp = joinpath(newroot, last)
            # mkpath(newp)
            op(node, newp)
        end
    end
end

flatten_to = (x, root, newroot) -> copy_to(x, root, newroot; keeprelative=false)

function copy_to(node, existing_root, target_root; keeprelative=true)
    send_to(existing_root, node, target_root; keeprelative=keeprelative, op=cp)
end
function move_to(node, existing_root, target_root; keeprelative=true)
    send_to(existing_root, node, target_root; keeprelative=keeprelative, op=mv)
end
# copy_to = (root, node, newroot) -> send_to(root, node, newroot; op=cp)
# move_to = (root, node, newroot) -> send_to(root, node, newroot; op=mv)


function transform_action(x, f=x->x; action=mv)
    if isfile(x)
        path, file = splitdir(x)
        name, ext = splitext(file)
        y = f(name)
        newfile = joinpath(path, join([y, ext]))
        if isfile(newfile)
            @warn "$newfile already exists"
            return x
        else
            action(x, newfile)
            @debug "Transforming $x -> $newfile"
            return newfile
        end
    else
        if isdir(x)
            components = splitpath(x)
            last = components[end]
            # name, ext = splitext(file)
            y = f(last)
            if y == last
                @warn "noop"
                return x
            end
            components[end] = y
            newdir = joinpath(components...)
            if isdir(newdir)
                @warn "$newdir already exists"
                return x
            else
                action(x, newdir)
                @debug "$x -> $newdir"
                return newdir
            end
        else
            @warn "x is neither file nor dir"
            return x
        end
    end
end


function increment_counter(ct; inc=1, incfunc=nothing)
    vl = ct.data[Base.Threads.threadid()]
    if isnothing(incfunc)
        ct.data[Base.Threads.threadid()] = vl + inc
    else
        ct.data[Base.Threads.threadid()] = vl + incfunc(inc)
    end
end

"""
    Usage
    QT = ParallelCount(zeros(Int64, Base.Threads.nthreads()), Int64(0))
    QT.data[threadid()] = ...

"""
struct ParallelCounter{T<:Number}
       data::Vector{T}
end

Base.show(io::IO, p::ParallelCounter) = print(io, "$(read_counter(p))")
Base.string(p::ParallelCounter) = "$(read_counter(p))"


struct SequentialCounter{T<:Number}
       data::Vector{T}
end

function make_counter(parallel=false)
    if parallel
        return ParallelCounter(zeros(Int64, Base.Threads.nthreads()))
    else
        return SequentialCounter(zeros(Int64, 1))
    end
end


Base.show(io::IO, p::SequentialCounter) = print(io, "Counter = $(read_counter(p))")
Base.string(p::SequentialCounter) = "Counter = $(read_counter(p))"

"""
    verify_template(start, template; expander=expand_filesystem, traversalpolicy=bottomup, parallel_policy="sequential")
    Recursively verifies a dataset anchored at start using a given template.
    For example, start can be the top directory of a filesystem.
    A template has one of 2 forms:
        - template = [(condition, action_on_fail), (condition, action), ...]
            - where condition accepts a node and returns true if ok, false if not.
            - action is a function that accepts a node as argument, and is trigger when condition fails, example warn_on_fail logs a warning
    Traversalpolicy is bottomup or topdown. For modifying actions bottomup is more stable.
    Parallel_policy is one of "sequential" or "parallel". While parallel execution can be a lot faster, be very careful if your actions share global state.
"""
function verify_template(start, template; expander=expand_filesystem, traversalpolicy=bottomup, parallel_policy="sequential", act_on_success=false)
    verify_dispatch_flipped = x -> verify_dispatch(x;on_success=true)
    vf = act_on_success ? verify_dispatch_flipped : verify_dispatch
    if typeof(template) <: Vector || typeof(template) <: Dict
        rv =  traversalpolicy(start, expander, vf; context=Dict([("node", start), ("template", template), ("level",1)]),  inner=_expand_table[parallel_policy])
        @debug "Return value = $rv for $start and $traversalpolicy"
        return rv
    else
        @error "Unsupported template"
        throw(ArgumentError("Template is of type $(typeof(template)) which is neither Vector, nor Dict"))
    end
end

transform_template = verify_template

# function transform_template(start, template; expander=expand_filesystem, traversalpolicy=bottomup, parallel_policy="sequential"; act)
#     vf = act_on_success ? verify_dispatch_flipped : verify_dispatch
#     if typeof(template) <: Vector || typeof(template) <: Dict
#         return traversalpolicy(start, expander, verify_dispatch; context=Dict([("node", start), ("template", template), ("level",1)]),  inner=_expand_table[parallel_policy])
#     else
#         @error "Unsupported template"
#         throw(ArgumentError("Template is of type $(typeof(template)) which is neither Vector, nor Dict"))
#     end
# end


function expand_sequential(node, expander, visitor, context)
    for _node in expander(node)
        if isnothing(context)
            ncontext = context
        else
            ncontext = copy(context)
            ncontext["level"] = context["level"] + 1
            ncontext["node"] = _node
        end
        rv = bottomup(_node, expander, visitor; context=ncontext, inner=expand_sequential)
        @debug "Return value bottomup $rv for $node"
        if rv == :quit
            @debug "Early exit triggered for $node"
            return :quit
        end
    end
    @debug "Returning proceed for $node"
    return :proceed
end


function expand_threaded(node, expander, visitor, context)
    @warn "Threaded"
    @threads for _node in expander(node)
        if isnothing(context)
            ncontext = context
        else
            ncontext = copy(context)
            ncontext["level"] = context["level"] + 1
            ncontext["node"] = _node
        end
        rv = bottomup(_node, expander, visitor; context=ncontext, inner=expand_threaded)
        if rv == :quit
            @debug "Early exit triggered for $node"
            return :quit
        end
    end
    @debug "Returning proceed for $node"
    return :proceed
end

_expand_table = Dict([("parallel", expand_threaded), ("sequential", expand_sequential)])


"""
    topdown(node, expander, visitor; context=nothing, inner=expand_sequential)
        Recursively apply visitor onto node, until expander(node) -> []
        If context is nothing, the visitor function gets the current node as sole arguments.
        Otherwise, context is expected to contain: "node" => node, "level" => recursion level.
        Inner is the delegate function that will execute the expand phase. Options are : expand_sequential, expand_threaded

        Traversal is done in a post-order way, e.g. visit after expanding. In other words, leaves before nodes, working from bottom to top.
"""
function bottomup(node, expander, visitor; context=nothing, inner=expand_sequential)
    # nodes = expander(node)
    rv_inner = inner(node, expander, visitor, context)
    if rv_inner == :quit
        @debug "Early exit triggered for $node by expander"
        return :quit
    end
    early_exit = visitor(isnothing(context) ? node : context)
    if early_exit == :quit
        @debug "Early exit triggered for $node by visitor"
        return :quit
    end
    @debug "Returning proceed for $node"
    return :proceed
end

"""
    topdown(node, expander, visitor; context=nothing, inner=expand_sequential)
    Recursively apply visitor onto node, until expander(node) -> []
    If context is nothing, the visitor function gets the current node as sole arguments.
    Otherwise, context is expected to contain: "node" => node, "level" => recursion level.
    Inner is the delegate function that will execute the expand phase. Options are : expand_sequential, expand_threaded

    Traversal is done in a pre-order way, e.g. visit before expanding.
"""
function topdown(node, expander, visitor; context=nothing, inner=expand_sequential)
    @debug "Topdown @ $node"
    early_exit = visitor(isnothing(context) ? node : context)
    @debug "Visitor for $node -> $(early_exit)"
    if early_exit == :quit
        @debug "Early exit triggered for $node"
        return :quit
    end
    @debug "Expanding for $node"
    rv_inner = inner(node, expander, visitor, context)
    if rv_inner == :quit
        @debug "Expander returned quit for $node"
        return :quit
    end
    @debug "Returning proceed"
    return :proceed
end


function expand_filesystem(node)
    return isdir(node) ? readdir(node, join=true) : []
end


function add_img_to_hdf5_as(imgfile, name, hfile)
	h5open(hfile, "w") do file
    	write(file, name, Float64.(Images.load(imgfile)))  # alternatively, say "@write file A"
	end
end


function add_csv_to_hdf5_as(csv, name, hfile)
	h5open(hfile, "w") do file
        d = CSV.read(csv, DataFrames)
        D = Dict([(nm, d[!,nm]) for nm in names(d)])
    	write(file, name, D)  # alternatively, say "@write file A"
	end
end

function add_to_hdf5(fname::AbstractString,  h5::AbstractString)
    add_to_hdf5(fname, fname, h5)
end

function add_to_mat(fname::AbstractString, m::AbstractString)
    vname = match(r"[a-z,A-Z]+",fname).match
    @info "Writing $fname to $vname in $m"
    return add_to_mat(fname, vname, m)
end

function add_to_hdf5(fname::AbstractString, name::AbstractString, h5::AbstractString)
	if is_img(fname)
		return add_img_to_hdf5_as(fname, name, h5)
	end
	if is_csv_file(fname)
		return add_csv_to_hdf5_as(fname, name, h5)
	end
	throw(ArgumentError("Unsupported file $fname"))
end



function add_csv_to_mat_as(csvfile, name, mfile)
	if ~isfile(mfile)
		touch(mfile)
	end
    @info "Opening csv $csvfile"
	d = CSV.read(csvfile, DataFrame)
	D = Dict([(nm, d[!,nm]) for nm in names(d)])
	# file = matopen(mfile, "w")
    @info "Writing to $mfile"
	matwrite(mfile, D)
	# close(file)
end

function add_img_to_mat_as(imgfile, name, mfile)
	if ~isfile(mfile)
		touch(mfile)
	end
	i = Images.load(imgfile)
	file = matopen(mfile, "w")
	write(file, name, Float64.(i))
	close(file)
end

function toalpha(x)

end


function add_to_mat(fname, name, mfile)
	if is_img(fname)
		return add_img_to_mat_as(fname, name, mfile)
	end
	if is_csv_file(fname)
		return add_csv_to_mat_as(fname, name, mfile)
	end
	throw(ArgumentError("Unsupported file $fname"))
end

## Expand mat
## isdict, else variable

## Expand HDF5

function visit_filesystem(node)
    @info node
end

"""
    verifier(node, template::Vector, level::Int)
    Dispatched function to verify at recursion level with conditions set in template for node.
    Level is ignored for now, except to debug
"""
# Todo : change to Vector[namedtuple]  and use dispatch
function verifier(node, template::Vector, level::Int; on_success=false)
    # ### MARK
    # # for step in template
    #     if step.condition(node) == on_success
    #         @debug "Condition triggered on $node"
    #         rv = step.action(node)
    #         if rv == :quit
    #             @debug "Early exit for $node at $level"
    #             return :quit
    #         end
    #     else
    #
    # for t in template
    # rv = dostep(t)
    for step in template
        rv = dostep(node, step, on_success)
        if rv == :quit
            @debug "Early exit for $node at $level"
            return :quit
        end
    end
    return :proceed

    # for (condition, action) in template
    #     if condition(node) == on_success
    #         @debug "Condition failed on $node"
    #         rv = action(node)
    #         if rv == :quit
    #             @debug "Early exit for $node at $level"
    #             return :quit
    #         end
    #     end
    # end
    # return :proceed
end

function make_aggregator(name, adder, aggregator)
    return @NamedTuple{name, adder, aggregator, transformer}((name, adder, aggregator, identity))
end


function make_aggregator(name, adder)
    return @NamedTuple{name, adder, aggregator, transformer}((name, adder, (x,lst)->shared_list_to_file(x, lst), identity))
end


function make_aggregator(name, adder, aggregator, transformer)
    return @NamedTuple{name, adder, aggregator, transformer}((name, adder, aggregator,transformer))
end

function make_tuple(co, ac, ca)
    return @NamedTuple{condition,action, counteraction}((co,ac,ca))
end

function make_tuple(co, ac)
    return @NamedTuple{condition,action}((co, ac))
end

mt = x->make_tuple(x...)

"""
    verify_dispatch(context)
    Use multiple dispatch to call the right function verifier.
"""
function verify_dispatch(context; on_success=false)
    return verifier(context["node"], context["template"], context["level"];on_success=on_success)
end


"""
    verifier(node, templater::Dict, level::Int)
    Dispatched function to verify at recursion level with conditions set in templater[level] for node.
    Will apply templater[-1] as default if it's given, else no-op.
"""
function verifier(node, templater::Dict, level::Int; on_success=false)
    @debug "Level $level for $node"
    if haskey(templater, level)
        @debug "Level key $level found for $node"
        template = templater[level]
    else
        @debug "Level key $level NOT found for $node"
        if haskey(templater, -1)
            @debug "Default verification"
            template = templater[-1]
        else
            template = []
            @debug "No verification at level $level for $node"
        end
    end
    for step in template
        # MARK 2
        rv = dostep(node, step, on_success)
        @debug "Return value $rv"
        if rv == :quit
            return :quit
        end
    end
    # for (condition, action) in template
    #     if condition(node) == on_success
    #         @debug "Condition fired for $node --> action"
    #         rv = action(node)
    #         @debug "Return value $rv"
    #         if rv == :quit
    #             return :quit
    #         end
    #     end
    # end
    return :proceed
end



function all_of(fs, x)
    @debug "Applying all of $fs to $x"
    for f in fs
        if f(x) == false
            @debug "Condition in sequence failed"
            return false
        end
    end
    @debug "All passed"
    return true
end

function any_of(x, fs)
    for f in fs
        if f(x) == true
            return true
        end
    end
    return false
end
#
# function transformer(node, template)
#     # @warn "X"
#     for (condition, action) in template
#         if condition(node)
#             rv = action(node)
#             if rv == :quit
#                 return :quit
#             end
#             node = isnothing(rv) ? node : rv
#         end
#     end
# end

logical_and = (x, conditions) -> all(c(x) for c in conditions)

end

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
using JSON
using IOCapture
import Images
import SlurmMonitor
import Logging
using LoggingExtras
using Match
using CSV
using DataFrames
using ImageFiltering
using ImageMorphology
using Statistics
import TOML
using ProgressMeter
using HDF5
using MAT
using Logging, LoggingExtras, Dates

export topdown, config_log, upload_to_owncloud, groupbycolumn, tmpname, bottomup, expand_filesystem, mask, stack_images_by_prefix, canwrite, visit_filesystem, verifier, transformer, logical_and,
verify_template, always, filepath, never, increment_counter, make_counter, read_counter, transform_template, all_of, size_image,
transform_inplace, ParallelCounter, transform_copy, warn_on_fail, validate_scp_config, quit_on_fail, sample, expand_sequential, always_fails, filename_ends_with_integer,
expand_threaded, transform_template, quit, proceed, filename, integer_name, extract_columns, wrap_transform,
any_of, whitespace_to, has_whitespace, is_lower, slice_image, is_upper, write_file, stack_images, list_to_image, normalize_linear,
is_img, is_kd_img, is_2d_img, is_3d_img, is_rgb, read_dir, files, subdirs, buildcomp, has_n_files, has_n_subdirs, decode_filelist,
apply_all, ignore, generate_counter, log_to_file, size_of_file, make_shared_list, ifnotsetdefault,
shared_list_to_file, addentry!, n_files_or_more, less_than_n_files, delete_file, delete_folder, new_path, move_to,
copy_to, ends_with_integer, begins_with_integer, contains_integer, to_level, log_to_file_with_message,
safe_match, read_type, read_int, read_float, read_prefix_float, is_csv_file, is_tif_file, is_type_file, is_png_file,
read_prefix_int, read_postfix_float, read_postfix_int, collapse_functions, flatten_to, generate_size_counter, decode_symbol, lookup, guess_argument,
validate_global, decode_level, decode_function, tolowercase, handlecounters!, handle_chained, apply_to, add_to_file_list, create_template_from_toml, delegate, extract_template, has_lower, has_upper,
halt, keep_going, has_integer_in_name, has_float_in_name, is_8bit_img, is_16bit_img, column_names, make_tuple, add_to_mat, add_to_hdf5, not_hidden, mt,
dostep, is_hidden_file, is_hidden_dir, is_hidden, remove_from_to_inclusive, remove_from_to_exclusive,
remove_from_to_extension_inclusive, remove_from_to_extension_exclusive, aggregator_add, aggregator_aggregate, is_dir, is_file, gaussian, laplacian,
less_than_n_subdirs, tmpcopy, has_columns_named, has_more_than_or_n_columns, describe_image, has_less_than_n_columns, has_n_columns, load_content, has_image_extension, file_extension_one_of, save_content, transform_wrapper, path_only, reduce_images, mode_copy, mode_move, mode_inplace, reduce_image, remove, replace_pattern, remove_pattern, remove_from_to_extension,
remove_from_to, stack_list_to_image, concat_to_table, make_aggregator, describe_objects,
gaussian, laplacian, dilate_image, erode_image, invert, opening_image, closing_image, otsu_threshold_image, threshold_image, apply_to_image

is_8bit_img = x -> eltype(Images.load(x)) <: Images.Gray{Images.N0f8}
is_16bit_img = x -> eltype(Images.load(x)) <: Images.Gray{Images.N0f16}
# column_names = x -> names(CSV.read(x, DataFrame))

function column_names(x::T) where{T<:AbstractString}
	return names(CSV.read(x, DataFrame))
end

"""
	config_log(minlevel=Logging.Debug)

	Configure verbose logging. Changes the global logger.
"""
function config_log(minlevel=Logging.Debug)
        date_format = "yyyy-mm-dd HH:MM:SS"
        timestamp_logger(logger) = TransformerLogger(logger) do log
                merge(log, (; message = "$(Dates.format(now(), date_format)) $(basename(log.file)):$(log.line): $(log.message)"))
        end
        defl = minlevel
        ConsoleLogger(stdout, defl) |> timestamp_logger |> global_logger
end


is_file = x -> isfile(x)
has_n_columns = (x, k) -> length(column_names(x)) == k
has_less_than_n_columns = (x, k) -> length(column_names(x)) < k
has_more_than_or_n_columns = (x, k) -> length(column_names(x)) >= k
function has_columns_named(x::AbstractString, nms::AbstractVector{T}) where T<:AbstractString
    cn = column_names(x)
    return all(c ∈ cn for c in nms)
end

function filepath(x::AbstractString)
    if isdir(x)
        @warn "Calling `filepath` on directory"
        @warn "For directory /a/b/c this becomes /a/b"
    end
    return splitdir(x)[1]
end

function validate_scp_config(configfile)
	@info "Validating scp $configfile"
	try
		tb = JSON.parse(String(read(configfile)))
		@info "Parsed to $tb"
	    user = ENV["USER"]
	    defaults = Dict([("user",user), ("port", "22"), ("remote", "localhost"), ("path", "/home/$(user)")])
		@info "Defaults $defaults"
	    for key in keys(defaults)
	        if haskey(tb, key)
	            @info "Found key $key -> $(tb[key])"
	            defaults[key] = tb[key]
	        end
	    end
	    @debug "Config $defaults"
		ENV["DC_SSH_CONFIG"] = JSON.json(defaults)
		return true
	catch e
		@error "Parsing SSH config failed with $e for $configfile"
		return false
	end
end

function upload_to_scp(file)
	conf = JSON.parse(ENV["DC_SSH_CONFIG"])
	@debug "Using SSH config $conf"
    read(`scp -P $(conf["port"]) $(file) $(conf["user"])@$(conf["remote"]):$(conf["path"])`, String)
	return file
end

function filepath(x::AbstractVector)
    @debug "Vectorized filepath invoked for $x"
    return filepath.(x)
end

remove = x -> delete_if_exists(x)
is_hidden_file = x-> isfile(x) && startswith(basename(x), ".")
is_hidden_dir = x-> isdir(x) && (startswith(basename(x), ".") || contains(basename(x), "__MACOSX"))
is_hidden = x -> is_hidden_file(x) || is_hidden_dir(x)
not_hidden = x -> ~is_hidden(x)
is_dir = x -> isdir(x)

function describe_image(x::AbstractString, axis::Int)
    @debug "Describe: loading $x with $axis"
    img = load_content(x)
    df = describe_image(img, axis)
    df[!,:source].=basename(x)
    return df
end

function describe_image(x::AbstractString)
    @debug "Describe: loading $x"
    img = load_content(x)
    df = describe_image(img)
    df[!,:source].=basename(x)
    df[!,:slice] .= 1
    return df
end


function _upload_to_owncloud(file, config)
    if !haskey(config, "initialized")
        @info "Creating path if needed"
        remote=config["remote"]
        _initialize_remote(config)
        config["initialized"]="true"
    end
    try
		@debug "Sending $file"
		IOCapture.capture() do
        	read(`curl -X PUT -u $(config["user"]):$(config["token"]) "$(config["remote"])$(filename(file))" --data-binary @"$file" --create-dirs`, String)
		end
        @debug "Success"
    catch e
        @error "Failed posting $file to $config due to $e"
    end
	return file
end

function upload_to_owncloud(name)
	try
		@info "Upload to owncloud"
		config = JSON.parse(ENV["DC_owncloud_configuration"])
		@info "Executing with $config"
		@info "Uploading to owncloud $name"
		return _upload_to_owncloud(name, config)
	catch e
		@error "Failed upload $name"
	end
end

function upload_to_owncloud(tmp, name)
	try
		@debug "upload to owncloud with $tmp and $name"
		cp(tmp, name, force=true)
		@info "Uploading $name to owncloud"
		config = JSON.parse(ENV["DC_owncloud_configuration"])
		@info "Executing with $config"
		@info "Uploading to owncloud $name"
		return _upload_to_owncloud(name, config)
	catch e
		@error "Failed upload $tmp $name"
	end
end

function _make_remote_path(conf)
	IOCapture.capture() do
    	o=read(`curl -X PUT -u $(conf["user"]):$(conf["token"]) "$(conf["remote"])" -X MKCOL`, String)
	end
end

function _initialize_remote(config)
    remote = config["remote"]
    conf = copy(config)
    ps = split(remote, "/")
    dav = findfirst(x-> x=="webdav", ps)
    L = length(ps) - dav
    for i in 1:L
        conf["remote"] = join(ps[1:dav+i], "/")
        _make_remote_path(conf)
    end
end

function describe_image(x::AbstractVector{<:Any}, axis::Int)
	@debug "Calling vectorized describe image"
	N = length(x)
	p = ProgressMeter.Progress(N)
	r=[DataFrame() for _ in 1:N]
	@threads for i in 1:N
		r[i] = describe_image(x[i], axis)
		next!(p)
	end
	return r
	# return describe_image.(x, axis)
end

function describe_image(x::AbstractVector{<:Any})
	@debug "Calling vectorized describe image"
	N = length(x)
	r=[DataFrame() for _ in 1:N]
	p = ProgressMeter.Progress(N)
	@threads for i in 1:N
		r[i] = describe_image(x[i])
        next!(p)
	end
	return r
	# return describe_image.(x)
end

function describe_image(x::AbstractArray{<:Any, 3})
	@debug "Got image of type $(typeof(x))"
    ds = zeros(Float64, 1, 8)
    ds[1,:] .= dimg(x)
    # end
    columns = [:minimum, :Q1, :mean, :median, :Q3, :maximum, :std, :kurtosis]
    df = DataFrame()
    for (i,c) in enumerate(columns)
        df[!,c] = ds[:,i]
    end
    df[!,:axis] .= 0
    return df
end

"""
	For a bounding box, get the XY span (diagonal), Z range, and z center
"""
function getextent(box)
    xr, yr, zr = abs.(box[1] .- box[2]) .+ 1
    xy = sqrt(xr^2 + yr^2)
    return xy, zr, min(box[1][3], box[2][3]) +zr/2
end

function getextent2(box)
    xr, yr = abs.(box[1] .- box[2]) .+ 1
    xy = sqrt(xr^2 + yr^2)
    return xy
end

function groupbycolumn(df::DataFrame, columns, targets, functions, names)
	# @info df
	# @info typeof(df)
	# @info "DATAFRAME"
    gdf = groupby(df, columns)
    _fs = [lookup(f) for f in functions]
    y = combine(gdf, [c => f => n for (c,f, n) in zip(targets, _fs, names)])
	return y
end

function groupbycolumn(df::AbstractString, columns, targets, functions, names)
	# @info df
	# @info typeof(df)
	# @info "FILE"
	x=load_content(df)
    gdf = groupby(x, columns)
    _fs = [lookup(f) for f in functions]
    y = combine(gdf, [c => f => n for (c,f, n) in zip(targets, _fs, names)])
	CSV.write(df, y)
	return df
end

function describe_objects(img::AbstractArray{T, 2}) where {T<:Any}
	b = copy(img)
    b[b .> 0] .= 1
	## Changed 3-2 connectivity
	get_components_diag = mask -> Images.label_components(mask, length(size(mask))==2 ? trues(3,3) : trues(3,3,3))
    coms = get_components_diag(b)
    lengths = Images.component_lengths(coms)[2:end]
    indices = Images.component_indices(coms)[2:end]
    boxes = Images.component_boxes(coms)[2:end]
    N = maximum(coms)
    w=zeros(N, 11)
	@debug "Processing $N components"
	if N == 0
		@warn "NO COMPONENTS TO PROCESS"
		return nothing, nothing
	end
    for ic in 1:N
        vals = img[indices[ic]]
		n = length(vals)
         # m, Q1, mx, med, Q3, M, std(ys), kurt = dimg(vals)
		w[ic, 2] = sum(vals)
		w[ic, 1] = n
		w[ic,3:10] .= DataCurator.dimg(vals)
		w[ic, 11] = getextent2(boxes[ic])
		# w[ic, 11:13] = _xy, _z, _zp
    end
	columns = [:size, :weighted, :minimum, :Q1, :mean, :median, :Q3, :maximum, :std, :kurtosis, :xyspan]
    df = DataFrame()
    for (i,c) in enumerate(columns)
        df[!,c] = w[:,i]
    end
    return df
end


"""
    canwrite(filename)

    tests if `filename` can be opened for writing
"""
function canwrite(fname)
	if ! isfile(fname)
		@error "$fname is not a file"
		return false
	end
    try
        open(fname, "w") do io
            @info "Can override/write to $fname"
        end;
        return true
    catch e
        @error "Reading $fname failed because of $e"
        return false
    end
end

function describe_objects(img::AbstractArray{T, 3}) where {T<:Any}
    b = copy(img)
    b[b .> 0] .= 1
	## Changed 3-2 connectivity
	get_components_diag = mask -> Images.label_components(mask, length(size(mask))==2 ? trues(3,3) : trues(3,3,3))
    coms = get_components_diag(b)
    lengths = Images.component_lengths(coms)[2:end]
    indices = Images.component_indices(coms)[2:end]
    boxes = Images.component_boxes(coms)[2:end]
    N = maximum(coms)
    w=zeros(N, 15)
	@debug "Processing $N components"
	if N == 0
		@warn "NO COMPONENTS TO PROCESS"
		return nothing, nothing
	end
    for ic in 1:N
        vals = img[indices[ic]]
		n = length(vals)
         # m, Q1, mx, med, Q3, M, std(ys), kurt = dimg(vals)
		w[ic, 2] = sum(vals)
		w[ic, 1] = n
		w[ic,3:10] .= DataCurator.dimg(vals)
		w[ic, 11:13] .= getextent(boxes[ic])
		# w[ic, 11:13] = _xy, _z, _zp
    end
	columns = [:size, :weighted, :minimum, :Q1, :mean, :median, :Q3, :maximum, :std, :kurtosis, :xyspan, :zrange, :zmidpoint]
    df = DataFrame()
    for (i,c) in enumerate(columns)
        df[!,c] = w[:,i]
    end
    return df
end


function describe_objects(img::AbstractString)
	df = describe_objects(load_content(img))
	df[!,:filename].=img
	return df
end

function describe_objects(x::AbstractVector)
	@debug "Calling vectorized describe objects"
	N = length(x)
	p = ProgressMeter.Progress(N)
	r=[DataFrame() for _ in 1:N]
	@threads for i in 1:N
		r[i] = describe_objects(x[i])
		next!(p)
	end
	return r
	# @debug "Vectorized describe_objects called"
	# return describe_objects.(imgs)
end


"""
    gaussian(img, sigma)

    Gaussian blur with σ
"""
function gaussian(img, sigma::Int)
    return ImageFiltering.imfilter(img, ImageFiltering.Kernel.gaussian([sigma for _ in 1:length(size(img))]));
end

"""
    laplacian(image)

    Laplacian of image (2nd derivative of intensity)
"""
function laplacian(img)
    return ImageFiltering.imfilter(img, ImageFiltering.Kernel.Laplacian());
end

function erode_image(img)
    ImageMorphology.erode!(img)
    return img
end

function dilate_image(img)
    ImageMorphology.dilate!(img)
    return img
end


function opening_image(img)
    return dilate_image(erode_image(img))
end

function closing_image(img)
    return erode_image(dilate_image(img))
end


function threshold_image(x::AbstractArray, operator::AbstractString, value::AbstractString)
    return threshold_image(x, operator, parse(Float64, value))
end

"""
    treshold(image, operator, value)

    Set the image to zero where operator(image, value) == true.
    Operator can be one of '<', '>', 'abs >', 'abs <'.
"""
function threshold_image(x::AbstractArray, operator::AbstractString, value::Number)
    @match operator begin
        "<" => (x[x.<value].= 0)
        ">" => (x[x.>value].= 0)
        "=" => (x[x.==value].= 0)
        "abs >" => (x[abs.(x) .> value].= 0)
        "abs <" => (x[abs.(x) .<value].= 0)
        "abs =" => (x[abs.(x) .==value].= 0)
    end
    return x
end

"""
    invert(image)

    For a normed ([0-1]) image, return  1 - image
"""
function invert(x::AbstractArray)
    if ~ all(0 .<= x .<= 1)
        @warn "Inverting assumes your input is [0-1], this not the case!!"
    end
    return 1 .- x
end

function otsu_threshold_image(x::AbstractArray)
    if iszero(x)
        @warn "Image is zero, thresholding will fail."
        return 0
    end
    thres = Images.otsu_threshold(x, 100)
    x[x.<thres] .= 0
    return x
end


"""
    apply_to_image(img, operators::AbstractVector{T}) where {T<:AbstractString}

    Apply each of the operators, left to right, to the image (in place.)

    Operators can be any unary operators in scope that can be vectorized, e.g. log, sin, cos, abs, ...
"""
function apply_to_image(img, operators::AbstractVector{T}) where {T<:AbstractString}
    for op in operators
        apply_to_image!(img, op)
    end
    return img
end

function apply_to_image!(img, operator::AbstractString)
    op = lookup(operator)
    img = op.(img)
end

"""
    describe_image(x::AbstractArray, axis::Int64)::DataFrame

    Describe the array x sliced along axis.
"""
function describe_image(x::AbstractArray, axis::Int64)
    SZ = size(x)
    if ~ (0 < axis <= length(SZ))
        throw(ArgumentError("Describing along invalid axis $axis of image with dimensions $SZ"))
    end
    N = SZ[axis]
    ds = zeros(Float64, N, 8)
    for (i,s) in enumerate(eachslice(x; dims=axis))
        # @info s
        ds[i,:] .= dimg(s)
    end
    columns = [:minimum, :Q1, :mean, :median, :Q3, :maximum, :std, :kurtosis]
    df = DataFrame()
    for (i,c) in enumerate(columns)
        df[!,c] = ds[:,i]
    end
    df[!,:slice]=1:N|>collect
    df[!,:axis].=axis
    return df
end


"""
	dimg(x)

	Describes the image argument as a collapsed Float64 array and returns the statistical moments.
"""
function dimg(x)
    ys = Float64.(x[:])
    if iszero(ys)
        @warn "Return NaN for zeroed image. Describing zero is unlikely what you wanted."
        return [NaN for _ in 1:8]
    end
    ys = ys[ys .> 0]
    Q1, med, Q3 = quantile(ys, [0.25, 0.5, .75])
    mx = mean(ys)
    N = length(ys)
    m2 = sum((ys .- mx).^2)/N
    m4 = sum((ys .- mx).^4)/N
    kurt = m2/m4
    m, M = minimum(ys), maximum(ys)
    return m, Q1, mx, med, Q3, M, std(ys), kurt
end



"""
	load_content(filename)

	Tries to access common formats of content, currently supports tif/png/csv/txt
"""
function load_content(x::AbstractString)
    @debug "Trying to load content for $x"
    ex = splitext(x)[2]
    if ex ∈ [".tif", ".png"]
        return Images.load(x)
    end
    if ex ∈ [".csv", ".txt"]
        return CSV.read(x, DataFrames.DataFrame)
    end
    @error "No matching file type (img, csv), assuming your functions know how to handle this"
    throw(ArgumentError("Invalid file content or not yet supported $x"))
end

function save_content(ct::Array{T}, sink::AbstractString) where {T<:Images.Colorant}
    @debug "Saving image to $sink"
    Images.save(sink, ct)
end

function save_content(ct::Array{T}, sink::AbstractString) where {T<:Images.Gray}
    @debug "Saving image to $sink"
    Images.save(sink, ct)
end

function save_content(ct::Matrix{Images.N0f16}, sink::String)
    @debug "Saving image to $sink"
    Images.save(sink, ct)
end

function save_content(ct::Array{T}, sink::AbstractString) where {T<:AbstractFloat}
    @debug "Saving image to $sink"
    save_content(Images.N0f16.(ct), sink)
end

function save_content(ct::DataFrame, sink::AbstractString)
    @debug "Saving dataframe content to $sink"
    CSV.write(sink, ct)
end

function mode_copy(old::AbstractString, tmp::AbstractString, new::AbstractString)
    @debug "Mode copy: $tmp to $new"
    mv(tmp, new)
end

function mode_move(old::AbstractString, tmp::AbstractString, new::AbstractString)
    @debug "Mode move: $tmp to $new"
    mv(tmp, new, force=true)
    rm(old)
end

function mode_inplace(old::AbstractString, tmp::AbstractString, new::AbstractString)
    @debug "Mode inplace with:$old $tmp $new"
    if old!=new
        @warn "Changing in place and changing the name is not meaningful --> mode_move"
        mode_move(old, tmp, new)
    else
        mv(tmp, old, force=true)
        # rm(old)
    end
end

function transform_wrapper(file::AbstractString, nametransform, contenttransform, mode)
    if isdir(file)
        @warn "You're selecting directories with your condition, but you are trying to modify a file, I'm ignoring it for now"
        @warn file
        return
    end
    tmp = tmpcopy(file)
    @debug "Copying $file to $tmp"
    path, fname = splitdir(file)
    newname = joinpath(path, nametransform(fname))
    @debug "Transforming $file with $path + $fname to $newname"
    oldcontent = load_content(file)
    newcontent = contenttransform(oldcontent)
    save_content(newcontent, tmp)
    if newname == file
        if mode == mode_copy
            # @warn "Name is left intact, but copy (not mv) is set, overriding to save new content"
            if oldcontent == newcontent
                @warn "Filename nor content changed, noop"
                return
            else
                @debug "Name not changed, but you specified copy, changing mode from $mode to mode_inplace"
                mode=mode_inplace
            end
        end
    end
    # save_content(newcontent, tmp)
    @debug "Transform $file -> $newname complete"
    mode(file, tmp, newname)
    @debug "File IO complete for $file -> $newname"
end

"""
    tmpcopy(x; seed=0, length=40)

    Create a temporary copy of file x (with same extension), of length 40.
    40 means there's a 1/10000 for a collision of 2 identical files.
    Note that this function is used on executing a template, in parallel, so it's not the total of number files being processed, but the number of files being processed in the same window of time.
    Return the temporary file name
"""
function tmpcopy(x; seed=0, length=40)
    if seed != 0
        Random.seed!(seed)
    end
    b = basename(x)
    ext = splitext(x)[2]
    rs = Random.randstring(length) ## 40^(54+10) unique names --> log(10, 40^66) = 105, 10^52 files before you get a collision (bday paradox)
    new = joinpath(tempdir(), join([rs, ext]))
    cp(x, new)
    @debug "Copying $x to temporary $new"
    return new
end

function tmpname(length=10)
	rs = Random.randstring(length)
	return rs
end

"""
    reduce_images(list, fname::AbstractString, op::AbstractString)

    Given list of K-D images (tif), stack to K+1, then apply `op` along K+1 th dimension.
    Save to fname in K-D tif

    Example
    maxproject = (list, fname) -> reduce_images(list, fname, "maximum")
"""
function reduce_images(list, fname::AbstractString, op::AbstractString)
    fs = lookup(op)
    if isnothing(fs)
        throw(ArgumentError("Not a valid function $op for reduction"))
    end
    res = list_to_image(list)
    X = fs(res; dims=length(size(res)))
    if ~endswith(fname, ".tif")
        fname = "$(fname).tif"
    end
    Images.save(fname, X)
end

function reduce_image(img::Array{T}, op::AbstractString) where {T<:Images.Colorant}
    fs = lookup(op)
    if isnothing(fs)
        throw(ArgumentError("Not a valid function $op for reduction"))
    end
    X = fs(img; dims=length(size(img)))
    return X
end

function reduce_image(img::Array{T}, op::AbstractVector) where {T<:Images.Colorant}
    fs = lookup(op[1])
    @debug "Reduce Image with $op"
    if isnothing(fs)
        throw(ArgumentError("Not a valid function $op for reduction"))
    end
    d = 0
    if typeof(op[2]) <: AbstractString
        @warn "Dimension $(op[2]) passed as string, trying conversion ..."
        d = tryparse(Int, op[2])
    else
        d = op[2]
    end
    X = fs(img; dims=d)
    return X
end


function ifnotsetdefault(key, new, def)
    if haskey(new, key)
        return new[key]
    else
        return def[key]
    end
end

function mask(x::T) where {T<:AbstractString}
    @debug "File version"
    img = Images.load(x)
	q = img
	q[abs.(q).>0] .= 1
    Images.save(x, q)
end

function mask(q::Array{T}) where {T<:Images.Colorant}
    @debug "Data version"
    q[abs.(q).>0] .= 1
    return q
end

function mask(q)
    error("HALT -- unexpected type")
end

function mask(q::T) where {T<:AbstractArray}
    q[abs.(q).>0] .= 1
    return q
end

"""
	reduce_image(image, operator, dimensions)

	Apply a reduction (for example maximum projection) along the specified dimension, e.g. 3 for Z.
"""
function reduce_image(img, op::AbstractString, dims::Int64)
    fs = lookup(op)
    if isnothing(fs)
        throw(ArgumentError("Not a valid function $op for reduction"))
    end
    if dims < 1 || dims > length(size(img))
        throw(ArgumentError("Invalid dimension with $(size(img)) and dim = $dims"))
    end
    X = fs(img; dims=dims)
	return X
    # if ~endswith(fname, ".tif")
    #     fname = "$(fname).tif"
    # end
    # Images.save(fname, X)
end

"""
	doset(node, tuple, on_success)

	Visitor function, evaluates if(tuple[1](node) -> tuple[2]

	Dispatched by type for the condition-action or condition-action-counteraction
"""
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
        @debug "Condition did not fire for $node with on_success == $(on_success)"
        return :proceed
    end
end


"""
	doset(node, tuple, on_success)

	Visitor function, evaluates if(tuple[1](node) -> tuple[2] else -> tuple[3]
"""
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
    @debug "Removing $f"
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


"""
	handlecounters!(entries, key, global_dict)

	Decodes user specified counters (file size, count, etc)
	Stores the result in global_dict
"""
function handlecounters!(val, key, glob_defaults)
    counter_entries = val
    cts = Dict()
    @debug "Processing counters $(counter_entries)"
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
    l = make_shared_list()
    adder = x::AbstractString -> add_to_file_list(x, l)
    transformer = identity
    aggregator = shared_list_to_file
    Q = make_aggregator(fe, l, adder, aggregator, transformer)
    @info "Creating aggregator --> $fe save file list to txt file."
    return (fe, Q)
end

function decode_filelist(fe::AbstractVector, glob)
    @info "DF with $fe and $glob"
    ### Can only be 2 special cases
    ### name, outpath
    ### name, concat_to_table
    if length(fe) != 2
        @error "Failed decoding filelists $fe"
        throw(ArgumentError("invalid lists"))
    end
    listname, second = fe[1], fe[2]
    l = make_shared_list()
    if second == "concat_to_table"
        @debug "Shortcode for table concatenation found"
        # change_path = x->new_path(glob["inputdirectory"], x, alter_root)
        adder = x::AbstractString -> add_to_file_list(x, l)
        Q = make_aggregator(listname, l, adder, shared_list_to_table, identity)
        return (listname, Q)
    end
	if second == "concat_to_owncloud"
		@info "Shortcode for table concatenation to owncloud"
        # change_path = x->new_path(glob["inputdirectory"], x, alter_root)
        adder = x::AbstractString -> add_to_file_list(x, l)
        Q = make_aggregator(listname, l, adder, (x, y) -> concat_to_owncloud(x, y, glob), identity)
        return (listname, Q)
	end
    @warn "During creation of lists with $(fe), assuming $second is a path and you want to compile in/out filelists"
    change_path = x->new_path(glob["inputdirectory"], x, second)
    adder = x::AbstractString -> add_to_file_list(change_path(x), l)
    Q = make_aggregator(listname, l, adder, shared_list_to_file, change_path)
    return (listname, Q)
end

function decode_filelist(fe::AbstractDict, glob::AbstractDict)
    #Here check for
    # KEys name, transformer, aggregator
    default=Dict([("transformer", identity), ("aggregator", shared_list_to_file)])
    @info "Decoding $fe , default = $default"
    if ~haskey(fe, "name")
        @error "Invalid file list entry $fe"
        throw(ArgumentError("Your list should have at least a name, use file_lists=[{\"name\":\"mylistname\",...}]"))
    end
    fn = fe["name"]
    tf = default["transformer"]
    ag = default["aggregator"]
    if haskey(fe, "transformer")
        TF = fe["transformer"]
        @debug "Found a transformer entry $TF"
        tf = decode_symbol(TF, glob;condition=false)
        if isnothing(tf)
            @error "Invalid $TF"
            throw(ArgumentError("Invalid $TF"))
        end
    end
    if haskey(fe, "aggregator")
        AG = fe["aggregator"]
		@info "Decoding aggregator $AG"
        ag = decode_aggregator(AG, glob)
        @info "Found a aggregator entry $AG -> $ag"
    end
    @info "Constructed aggregation list $fn transform with $tf and aggregation by $ag"
    l = make_shared_list()
    if tf != identity
        @info "Custom transform, wrapping with copy"
        adder = x::AbstractString -> add_to_file_list(tf(wrap_transform(x)), l)
    else
        adder = x::AbstractString -> add_to_file_list(x, l)
    end
    return fn, make_aggregator(fn, l, adder, ag, tf)
end

function decode_aggregator(name::AbstractString, glob::AbstractDict)
	@info "Decoding aggregator String $name"
    fs = lookup(name)
    if isnothing(fs)
        throw(ArgumentError("$name is not valid function call"))
    end
    return fs
end

function decode_aggregator(ag::AbstractVector{<:AbstractString}, glob::AbstractDict)
	@info "Decoding aggregator Vector $ag"
    an = ag[1]
    @info "Decoding aggregator Vector $(ag)"
    if length(ag) < 2
        throw(ArgumentError("Invalid aggregator $ag"))
    end
    # aggregators=[shared_list_to_file, shared_list_to_table, concat_to_table]
    fs = lookup(an)
    if isnothing(fs)
        throw(ArgumentError("$name is not valid function call"))
    end
    return (list, name) -> (fs(list, name, ag[2:end]...))
end

function decode_aggregator(ag::AbstractVector{<:AbstractVector}, glob::AbstractDict)
    ## Inner vector is a chain of A -> B -> SINK
    @info "Decoding chained aggregator $(ag)"
    if length(ag) != 1
        throw(ArgumentError("Invalid aggregator $ag, expecting [[A, B, C, D]] s.t. D(C(B(A)))"))
    end
    nested = ag[1]
    # aggregators=[shared_list_to_file, shared_list_to_table, concat_to_table]
    # @warn "Fixme --> implement transformers $ag"
    @debug "$ag --> nested aggregator $nested"
    sink = nested[end]
    transformers = nested[1:end-1]
    chain = []
    for candidate in transformers
        @info "Decoding $candidate transformer"
        cfs = decode_function(candidate, glob; condition=false)
        if  isnothing(cfs)
            throw(ArgumentError)
        end
        push!(chain, cfs)
    end
    @debug "Collapsing chain"
    functor = collapse_functions(chain; left_to_right=true)
    @debug "Fixme --> Sink $sink"
    fs = lookup(sink)
    if isnothing(fs)
        throw(ArgumentError("$sink is not valid function call"))
    end
    return (list, name) -> (fs(functor(flatten_list(list)), name, ag[2:end]...))
end

function flatten_list(sl)
    @debug "Flattening list $sl"
    ls = []
    for s in sl
        for _l in s
            push!(ls, _l)
        end
    end
    return ls
end

"""
    wrap_transform(x::AbstractString)

    For file x, generate a temp copy before aggregation on a file list
"""
function wrap_transform(x::AbstractString)
    c = joinpath(tempdir(), "_datacuratorjl", "$(Random.randstring(40))")
    @debug "Making path $c"
    mkpath(c)
    c = joinpath(c, basename(x))
    @debug "Temporary copy for x -> $c"
    cp(x, c)
    @debug "Returning $c"
    return c
end


function normalize_linear(ci)
    img = copy(ci)
    MK = img.>0
    A = img[MK]
    m, M = minimum(A), maximum(A)
    ran = M-m
    img[MK] .= (A .- m)/ran
    return img
end

function extract_columns(csv, columns)
    @debug "Extracting columns $columns for $csv"
    df = CSV.read(csv, DataFrame)
    @debug "DF = $(df)"
    extracted=df[!,columns]
    @debug "Extracted = $(extracted))"
    CSV.write(csv, df[!,columns])
    return csv
end

function handlefilelists!(val, key, glob_defaults)
    file_entries = val
    cts = Dict()
    for ce in file_entries
        d = decode_filelist(ce, glob_defaults)
        if isnothing(d)
            @error "Failed decoding filelists"
            throw(ErrorException("invalid lists"))
        else
            name, ctuple = d
            if haskey(cts, name)
                throw(ArgumentError("Invalid file list redefinition with $name already defined as $(cts[name])"))
            end
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
	if f == "upload_to_owncloud"
		return x -> _upload_to_owncloud(x, glob["owncloud_configuration"])
	end
    fs = lookup_common(f, glob, condition)
    if ~isnothing(fs)
        return fs
    end
    fs = lookup(f)
    @debug "0 argument function lookup for $f"
    if isnothing(fs)
        @error "$f is not a valid function"
        return nothing
    end
    return x -> fs(x)
end

function lookup_common(fname::AbstractString, glob::AbstractDict, condition)
    tkey = condition ? "common_conditions" : "common_actions"
    if ~haskey(glob, tkey)
        @warn "Global section has missing $tkey. This isn't a critical problem but unexpected."
        return nothing
    end
    cc = glob[tkey]
    @debug "Checking common $fname in global configuration, condition == $condition"
    @debug "Total conditions: $(glob["common_conditions"])"
    @debug "Total actions: $(glob["common_actions"])"
    if fname ∈ keys(cc)
        @debug "Found common $fname in global configuration"
        return cc[fname]
    end
    return nothing
end


"""
    decode_function(f::AbstractDict, glob::AbstractDict; condition=false)

    Dispatched method for transform entries
"""
function decode_function(f::AbstractDict, glob::AbstractDict; condition=false)
    tomode = Dict([("copy", mode_copy),("move", mode_move),("inplace", mode_inplace)])
    nt = f["name_transform"]
    nts = [DataCurator.decode_function(_nt, glob; condition=false) for _nt in nt]
    if any(isnothing.(nts))
        throw(ArgumentError("Failed decoding $f"))
    end
    nam_fun = collapse_functions(nts; left_to_right=true)
    ct = f["content_transform"]
    cts = [DataCurator.decode_function(_ct, glob; condition=false) for _ct in ct]
    if any(isnothing.(cts))
        throw(ArgumentError("Failed decoding $f"))
    end
    con_fun = collapse_functions(cts; left_to_right=true)
    mode = tomode[f["mode"]]
    return x->transform_wrapper(x, nam_fun, con_fun, mode)
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
    # @debug FN
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
    # @debug FN
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

# Workaround for 1.5, turns out to be faster than original
function fix1p5(xs::T) where {T<:BitVector}
    return all.(xs)
end

function fix1p5(xs)
    return all.(xs|>collect)
end

function execute_dataframe_function(df::DataFrame, command::AbstractString, columns::AbstractVector, operators::AbstractVector, values::AbstractVector)
    _df = copy(df)
    cols = names(df)
    @debug "Dataframe --> Cols = $cols"
    check = x::AbstractString -> x ∈ cols
    # valid = reduce(&, map(check, columns))
    valid = all(map(check, columns)) # reduce doesn't short circuit, even with short circuit operators, because it can't know the reducer
    if ~valid
        throw(ArgumentError("You're specifying conditions on $columns but frame only has $cols"))
    end
    # if command == "extract"
    # BV = reduce(.&, [buildcomp(_df, c, o, v) for (c, o, v) in zip(columns, operators, values)])
    fx = (x, y) -> x .& y
    BV = reduce( fx , (buildcomp(_df, c, o, v) for (c, o, v) in zip(columns, operators, values)))
    sel = _df[BV, :]
    @debug "Remainder selection is"
    @debug sel
    return @match command begin
        "extract" => copy(_df[BV, :])
        "delete" => copy(_df[Not(BV), :])
        _ => throw(ArgumentError("Invalid comman $command"))
    end
end
#
# function decode_dataframe_function(x::AbstractVector, glob::AbstractDict)
#     ### Change to accept vector of tuples
#     ### (col, op, values)
#     ###
#     command = x[1]
#     cols::AbstractVector{T} where {T<:AbstractString} = x[2]
#     ops::AbstractVector{T} where {T<:AbstractString} = x[3]
#     vals::AbstractVector = x[4]
#     if length(cols) != length(ops) != length(vals)
#         throw(ArgumentError("Ops. cols, and values do not match in length"))
#     end
#     @info "Dataframe modifier with $command $cols $ops $vals"
#     return x -> execute_dataframe_function(x, command, cols, ops, vals)
# end


function decode_df_entry(ent::Tuple{AbstractString, AbstractString, Any})
    return ent
end


function decode_df_entry(ent::Tuple{AbstractString, AbstractString})
    return ent[1], ent[2], nothing
end

"""
    decode_dataframe_function(x::AbstractVector, glob::AbstractDict)

    Decodes an entry of the form [command, [(col, op, vals)+]] into a function object for the template

    Both the single tuple version
        command, (col, op, vals)
    and longer version
        command, [(col, op, vals), ...]
    are valid, and dealt by m dispatch.

    Note that an entry can be any of:
        - col, op   (for isnan, isnothing, ...)
        - col, op, val (for <, >, ...)
        - col, op, vals (for in, between, ....)
"""
function decode_dataframe_function(x::AbstractVector, glob::AbstractDict)
    if length(x) != 2
        throw(ArgumentError("Invalid dataframe conditions $x, expecting [command, [(col, op, vals),...]]"))
    end
    command::AbstractString = x[1]
    cols, ops, vals = decode_df_entries(x[2])
    @debug "Decoded $x into "
    @debug cols
    @debug ops
    @debug vals
    if length(cols) != length(ops) != length(vals)
        throw(ArgumentError("Ops. cols, and values do not match in length"))
    end
    @info "Dataframe modifier with $command $cols $ops $vals"
    return x -> execute_dataframe_function(x, command, cols, ops, vals)
end

function decode_df_entries(entries::AbstractVector{<:AbstractVector})
    @debug "Vector of entries"
    cols::Vector{AbstractString} = []
    ops::Vector{AbstractString} = []
    vals = []
    for entry in entries
        col, op, val = decode_df_entry(Tuple(entry))
        push!(cols, col)
        push!(ops, op)
        push!(vals, val)
    end
    return cols, ops, vals
end

function decode_df_entries(entries::AbstractVector)
    @debug "Singular entry"
    if length(entries) ∉ [2,3]
        throw(ArgumentError("Invalid entry for dataframe operation $entries"))
    end
    cols::Vector{AbstractString} = []
    ops::Vector{AbstractString} = []
    vals = []
    col, op, val = decode_df_entry(Tuple(entries))
    push!(cols, col)
    push!(ops, op)
    push!(vals, val)
    return cols, ops, vals
end



### Specialize for negate
function buildcomp(df::DataFrame, col::AbstractString, op::AbstractVector, val)
    if length(op) != 2
        throw(ArgumentError("Expecting not <operator> , got $op"))
    end
    oper = op[2]
    n = op[1]
    if n ∉ ["not", "NOT", "!", "~"]
        throw(ArgumentError("Expecting 'not <operator>' , got $op"))
    end
    return .~(buildcomp(df, col::AbstractString, op[2], val))
end

### Specialize for between/in
function buildcomp(df::DataFrame, col::AbstractString, op::AbstractString, val::AbstractVector)
    if length(val) < 2
        throw(ArgumentError("Expecting not array of values , got $val"))
    end
    c = x-> x in val
    return @match op begin
        "between" => val[1] .< df[:,col] .< val[2]
        "in" => BitVector(map(c,df[:,col]))
        _ => throw(ArgumentError("Op $op is invalid, between or in"))
    end
end

"""
    buildcomp(dataframe, column, operator, value)

    Dispatches to the correct form of operator.(df[:,col], value)

    operator (String) can be one of:
    less, leq, smaller than, more, greater than, equals, euqal, is, geq, isnan, isnothing, ismissing, iszero, <, >, <=, >=, ==

    The operator can be negated: ["not", "less"]
    Multi-argument comparison are also supported:
    - between [x, y]
    - in [x, y, z]

    You can repeat columns, but non-existing columns are an error.

    ```julia
    df = DataFrame(zeros(2,2),:auto)
    df[1,:] .= 5
    cols, ops, vals = ["x1", "x1", "x1"], [["not", "in"],"less", ["not", "isnan"]], [[1,2,3,5],10, "NaN"]
    @info reduce(&., buildcomp(df, c, o, v) for (c, o, v) in zip(["x1", "x1", "x1"], )
    ```
"""
function buildcomp(df::DataFrame, col, op::AbstractString, val)
    return @match op begin
        "less" => df[:,col] .< val
        "<" => df[:,col] .< val
        "leq" => df[:,col] .<= val
        "<=" => df[:,col] .<= val
        "smaller than" => df[:,col] .< val
        "more" => df[:,col] .> val
        ">" => df[:,col] .> val
        "greater than" => df[:,col] .> val
        "equals" => df[:,col] .== val
        "equal" => df[:,col] .== val
        "==" => df[:,col] .== val
        "=" => df[:,col] .== val
        "is" => df[:,col] .== val
        ">=" => df[:,col] .>= val
        "iszero" => df[:,col] .== 0
        "geq" => df[:,col] .>= val
        "isnan" => isnan.(df[:,col])
        "isnothing" => isnothing.(df[:,col])
        "ismissing" => ismissing.(df[:,col])
        _ => throw(ArgumentError("Op $op is invalid"))
    end
end

function _handle_cp(glob, f)
	if length(f) != 2
            throw(ArgumentError("Expecting `change_path newpath`, got $f"))
    end
    old = glob["inputdirectory"]
    @debug "Change path : $old --> $(f[2])"
    return x -> new_path(glob["inputdirectory"], x, f[2])
end

function _handle_extract(glob, f)
	@warn "DataFrame extraction call needed"
    return decode_dataframe_function(f, glob)
end

function _handle_all(glob, f, condition)
	@debug "Nested function with $f $f"
    rem = f[2:end]
    _fs = [decode_function(_f, glob; condition=condition) for _f in rem]
    @debug _fs
	if condition
        @debug "Nested condition"
        return x->all_of(_fs, x)
    else
        @debug "Nested action"
        return x->apply_all(_fs, x)
    end
end

function _handle_nested(glob, f, condition)
	@debug "Nested function with $f"
    if f[1][1] == "all"
        rem_f = f[1][2:end]
        subfs = [decode_function(_f, glob; condition=condition) for _f in rem_f]
        if condition
            @debug "Nested condition"
            return x->all_of(subfs, x)
        else
            @debug "Nested action"
            return x->apply_all(subfs, x)
        end
    else
        @error "$f is not valid nested function"
        throw(ArgumentError("$f"))
    end
end

function decode_function(f::AbstractVector, glob::AbstractDict; condition=false)
    negate=false
	f1 = f[1]
	@debug "Decode function with $f"
	@match f1 begin
		"extract" => return _handle_extract(glob, f)
		"change_path" => return _handle_cp(glob, f)
		"not" => begin negate=true; f=f[2:end]; @debug "Negate on function list is now $f"; end
		"all" => return _handle_all(glob, f, condition)
		"count" => return lookup_counter(f, glob)
		f1::AbstractVector => return _handle_nested(glob, f, condition)#error("Trigger")
		f1::AbstractString, if startswith(f1, "transform_") end => return handle_chained(f, glob; condition=condition)
	end
    fname = f[1] # When negate = on, we need to reindex, so don't do fn=f1
	if fname ∈ ["add_to_file_list", "aggregate", "aggregate_to", "->", "-->", "=>"]
		# @warn "Found add to file list for $f"
        @debug "Resolving file_list with key(s) $f"
		if length(f) != 2
			throw(ArgumentError("Expecting [add_to_file_list, name], or [add_to_file_list, [name,name,...]], got $f"))
		end
        file_adder = lookup_filelist(f[2], glob)
        return file_adder
    end

	if fname == "printtoslack"
		@debug "DEBUG --> Handling print to slack"
		if isnothing(glob["endpoint"])
			@warn "Print to slack but endpoint is not set --> Ignoring"
		else
			# [printtoslack, message]
			return x -> _printtoslack(x, f[2:end], glob["endpoint"])
		end
	end

	## Now we're sure it's a simple function, so find it
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
end

function flipfunctor(f)
    return x -> ~f(x)
end

function lookup_filelist(names::AbstractVector{T}, glob) where {T<:Any}
	@debug "Syntactic sugar for 1-N file lists $names"
	fs = [lookup_filelist(name, glob) for name in names]
	return x->apply_all(fs, x)
end

function lookup_filelist(name::AbstractString, glob)
	return _lookup_filelist(name, glob)
end

function _lookup_filelist(name, glob)
    @debug "Looking up FL on keyword $name"
    if haskey(glob, "file_lists")
        @debug "Checking file list table"
        fl_table = glob["file_lists"]
        @debug "TABLE == "
        @debug fl_table
        if haskey(fl_table, name)
            fl_object = fl_table[name]
            if fl_object.name != name
                @error "Table entry corrupt!!  $(fl_object.name) != $name"
            end
            # _, fl_adder = fl_object
            @debug "Success!"
            return fl_object.adder
        end
    end
    @error "failed decoding filelists"
	throw(ArgumentError("Failed decoding filelist with key $name"))
    return nothing
end

function lookup_n_lists(tpl, glob)
    ac, fn = tpl
    @debug "Looking up FL on keyword $ac with name  $fn"
    if haskey(glob, "file_lists")
        @debug "Checking file list table"
        fl_table = glob["file_lists"]
        @debug "TABLE == "
        @debug fl_table
        if haskey(fl_table, fn)
            fl_object = fl_table[fn]
            if fl_object.name != fn
                @error "Table entry corrupt!!  $(fl_object.name) != fn"
            end
            # _, fl_adder = fl_object
            @debug "Success!"
            return fl_object.adder
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
	Print a message to a connected slack
"""
function _printtoslack(x, argument, endpoint)
	return SlurmMonitor.posttoslack("$argument $x", endpoint)
end

"""
    delegate(config, template)
    Uses the configuration, and template create by `create_template_from_toml', to execute the verifier as specified.
    Returns the counters and file lists, if any are defined.
"""
function delegate(config, template)
    parallel = config["parallel"] ? "parallel" : "sequential"
    # if haskey(config, "outputdirectory")
    CWD = pwd()
    if isnothing(config["outputdirectory"])
        @debug "Using default outputdirectory"
    else
        odir = config["outputdirectory"]
        mkpath(odir)
        cd(odir)
        @debug "Changed output directory from $(CWD) to $odir"
    end
    # end
    rval =  verify_template(config["inputdirectory"], template; traversalpolicy=lookup(String(config["traversal"])), parallel_policy=parallel, act_on_success=config["act_on_success"])
    @debug "Return value == $rval"
    counters, lists = [], []
    for c in config["counters"]
        name, (count, counter) = c
        @info "Counter named $name has value $count"
        push!(counters, (name, read_counter(count)))
    end
    for (list_name, ag) in config["file_lists"]
        @debug "Processing with list $(ag.name)"
        @debug ag.list
        if list_name != ag.name
            @error "Invalid entry!! $ag $list_name"
            throw(ArgumentError("Invalid entry"))
        end
        aggregator_aggregate(ag)
        push!(lists, vcat(ag.list...))
    end
    @info "Finished processing dataset located at $(config["inputdirectory"])"
    if rval == :quit
        @warn "Dataset processing stopped early per your conditions"
    else
        @info "Dataset processing completed without early exit"
    end
    @info "Changing back to current directory $CWD"
    cd(CWD)
    return counters, lists, rval
end

function load_table(x::AbstractString)
    try
        tb = CSV.read(x, DataFrame)
        return tb
    catch e
        @error "Reading $x failed because of $e"
        throw(e)
    end
end

function load_table(x::DataFrame)
    return x
end

function slice_image(img::Array, dim, m::T, M::T) where {T<:Integer}
    check_slice(img, dim, m, M)
    return @match dim begin
        1 => slicex(img, m, M)
        2 => slicey(img, m, M)
        3 => slicez(img, m, M)
    end
end

function slice_image(img::Array, dim, m::T) where {T<:Integer}
    check_slice(img, dim, m, m)
    return @match dim begin
        1 => slicex(img, m, m)
        2 => slicey(img, m, m)
        3 => slicez(img, m, m)
    end
end

function slicex(img::Array{<:Images.Colorant, 3}, m::T, M::T) where {T<:Integer}
    return img[m:M, :, :]
end

function slicex(img::Array{<:Images.Colorant, 2}, m::T, M::T) where {T<:Integer}
    return img[m:M, :]
end

function slicey(img::Array{<:Images.Colorant, 3}, m::T, M::T) where {T<:Integer}
    return img[:, m:M, :]
end

function slicey(img::Array{<:Images.Colorant, 2}, m::T, M::T) where {T<:Integer}
    return img[:,m:M]
end

function slicez(img::Array{<:Images.Colorant, 3}, m::T, M::T) where {T<:Integer}
    return img[:,:,m:M]
end

function slice_image(img, dims::AbstractVector, slices::AbstractVector)
    @debug "Slicing image with size $(size(img)) along $dims with indices $slices"
    for (d, sl) in zip(dims, slices)
        img = slice_image(img, d, sl...)
    end
    return img
end


function size_dim(img, d::T) where {T<:Integer}
    SZ = size(img)
    if 1 <= d <= length(SZ)
        return SZ[d]
    end
    return -1
end

function size_image(x, dim::T, op::AbstractString, lim::T) where {T<:Integer}
    v = size_dim(x, dim)
    if v == -1
        return false
    end
    @debug "Dim $dim lim $lim"
    @match op begin
        ">" => v > lim
        "<" => v < lim
        "=" => v == lim
        ">=" => v >= lim
        "<=" => v <= lim
        _ => throw(ArgumentError("Invalid dimensions $dim $op $lim"))
    end
end

function size_image(x, dim::T, op::AbstractString, lim::AbstractVector{T}) where {T<:Integer}
    v = size_dim(x, dim)
    if v == -1
        return false
    end
    @match op begin
        "between" =>  lim[1] < v < lim[2]
        "in" => v ∈ lim
        _ => throw(ArgumentError("Invalid dimensions $dim $op $lim"))
    end
end


function size_image(x::AbstractString, triples::AbstractVector{<:AbstractVector})
    return size_image(load_content(x), triples)
end

function size_image(x::Array, triples::AbstractVector{<:AbstractVector})
    for (d, op, lims) in triples
        @debug "Checking $d for $op $lims"
        v=size_image(x, d, op, lims)
        if v == false
            return false
        end
    end
    return true
end

function check_slice(img, d, m, M)
    SZ = size(img)
    if 1 <= d <= length(SZ)
        if 1 <= m <= M
            if M<=SZ[d]
                return true
            end
        end
    end
    throw(ArgumentError("Invalid slice index for image with size $(SZ) , $d, $m, $M"))
    return false
end

function shared_list_to_table(list::AbstractVector, name::AbstractString="")
	if name == ""
		@debug "Aggregator without name specified"
		rs = tmpname(10)
		while isfile("$(rs).csv")
			@debug "$rs exists, trying again"
			rs = tmpname(10)
		end
		name = "$(rs).csv"
	end
    tables = []
    for csv_file in list
        @debug "Loading table $csv_file"
        tb = load_table(csv_file)
        push!(tables, tb)
    end
    @info "Saving total of $(length(tables)) to $name csv"
    DF = vcat(tables...)
    if ~endswith(name, ".csv")
        @debug "Postfixing .csv"
        name="$(name).csv"
    end
    @info "Writing to $name"
    CSV.write("$name", DF)
	return name
end

function shared_list_to_table(list::AbstractVector{<:AbstractVector}, name::AbstractString="")
    return shared_list_to_table(flatten_list(list), name)
end

function stack_list_to_image(list, name="")
	if name == ""
		@debug "Aggregator without name specified"
		rs = tmpname(10)
		while isfile("$(rs).tif")
			@debug "$rs exists, trying again"
			rs = tmpname(10)
		end
		name = "$(rs).tif"
	end
    res = list_to_image(list)
    @info "Saving aggregated image"
    if ~endswith(name, ".tif")
        @debug "Postfixing tif"
        name = "$(name).tif"
    end
	@info "Saving to $name"
    Images.save(name, res)
	return name
end




function sort_stack(list; aggregator=list_to_image)
    prefixes = Dict()
    for sl in list
        for f in sl
            b = basename(f)
            name, ext = splitext(b)
            m = match(r"[0-9]+$", name)
            if isnothing(m)
                @warn "Not ending with slice integer, skipping"
                continue
            end
            mi = m.match
            index = parse(Int, mi)
            N = length(m.match)
            prefix = name[1:end-N-1]
            key = "$(prefix)$(ext)"
            @debug "For file $f -> prefix $prefix and slice $index"
            if key ∈ keys(prefixes)
                prefixes[key][index] = f
            else
                prefixes[key]=Dict(index=>f)
            end
        end
    end
    @debug "have a total of $(keys(prefixes))"
    for prefix in keys(prefixes)
        slicedict = prefixes[prefix]
        s = sort(keys(slicedict) |> collect)
        @debug s
        fs = [slicedict[_s] for _s in s]
        agg = aggregator(fs)
        @debug "Saving aggregation for $prefix"
        Images.save(prefix, agg)
    end
end

stack_images_by_prefix = (x, n) -> sort_stack(x)

function list_to_image(list::AbstractVector{<:AbstractVector})
    @debug "Nested list with $(length(list))"
    ls = [list_to_image(li) for li in list if length(li) > 0]
    if length(ls) == 0
        @warn "No entries at all to process"
        return
    end
    SZ = size(ls[1])
    D = length(SZ)
    @debug "Cat with $length(ls) and $D from $SZ"
    return cat(ls..., dims=D) #D, because each list is already flattened
end

function list_to_image(list::AbstractVector{<:Any})
    @debug "List with $(length(list))"
    return _list_to_image(list)
end


function _list_to_image(list)
    sz = nothing
    ims = []
    for img in list
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
    N = length(ims)
    if N < 1
        @warn "No images to process for list"
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
    return res
end

function stack_images(l, n)
    return stack_list_to_image(l, n)
end

concat_to_table = shared_list_to_table


function concat_to_owncloud(list::AbstractVector{<:AbstractVector}, name::AbstractString)
    shared_list_to_table(flatten_list(list), name)
end

function concat_to_owncloud(list::AbstractVector, name::AbstractString)
	@info "Concatenate to owncloud"
	@info list
    tables = []
    for csv_file in list
        @debug "Loading table $csv_file"
        tb = load_table(csv_file)
        push!(tables, tb)
    end
    @info "Saving total of $(length(tables)) to $name csv"
    DF = vcat(tables...)
    if ~endswith(name, ".csv")
        @debug "Postfixing .csv"
        name="$(name).csv"
    end
    @info "Writing to $name"
    CSV.write("$name", DF)
	config = JSON.parse(ENV["DC_owncloud_configuration"])
	@info "Executing with $config"
	if isnothing(config)
		@error "Config = nothing"
		return
	end
	@info "Uploading to owncloud $name"
	_upload_to_owncloud(name, config)
end

function validate_top_config(cfg)
    keys_c = keys(cfg)|>collect
    @debug "Top level keys : $(keys_c)"
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


"""
	create_template_from_toml(tomlfile)

	Parse a toml encoded recipe, decode all the actions and conditions, and return a configuration (Dict) and executable template.

	```julia
	c, t = create_template_from_toml(tomlfile)
	delegate(c, t)
	```
"""
function create_template_from_toml(tomlfile)
    config = TOML.parsefile(tomlfile)
    validate_top_config(config)
    glob = validate_global(config)
    @info "Global configuration is:"
    for key in keys(glob)
        if key == "file_lists"
            @info "Aggregation file lists:"
            FL = glob["file_lists"]
            for k in keys(FL)
                @info "$k with aggregator $(FL[k].aggregator) and transformer $(FL[k].transformer)"
            end
        else
            if (key == "common_actions") || (key=="common_conditions")
                @info key
                @debug "$key --> $(glob[key])"
            else
                @info "$key --> $(glob[key])"
            end
        end
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
    @info "!!! Succesfully decoded your template !!!"
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
    @debug "Parsing all $acs with condition $condition"
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
        @debug "Enabling Counter Action mode"
        if (length(actions) != length(conditions)) || (length(actions) != length(conditions))
            if all_mode == false
                @error "Action and conditions do not align, this is accepted only when all=true"
                @error "Actions: $actions"
                @error "Conditions: $conditions"
                return nothing
            end
        end
        @debug "Counteractions with glob common actions"
        @debug "$(globalconfig["common_actions"])"
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
        lvl = to_level(parse_all(actions, globalconfig;condition=false) , parse_all(conditions, globalconfig;condition=true) ;all=all_mode)
        @debug "Decode level success"
        return lvl
    end
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

is_type_file = (x, t) -> isfile(x) && endswith(x, t)
is_csv_file = x -> is_type_file(x, ".csv")
has_image_extension = x -> splitext(x)[2] ∈ [".tif", ".png", ".jpg", ".jpeg"]
file_extension_one_of = (x, _set) -> splitext(x)[2] ∈ _set
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
show_warn_with_message = (x, y) -> @warn "$x :: $y"
warn_on_fail = x -> show_warning(x)
halt = x -> begin @info "Triggered early exit for $x"; return :quit; end
quit = x -> return :quit
keep_going = x-> :proceed
filename = x->basename(x)
integer_name = x->~isnothing(tryparse(Int, basename(x)))
has_integer_in_name = x->read_int(basename(x))
has_float_in_name = x->read_float(basename(x))
quit_on_fail = x -> begin @warn "$x"; return :quit; end
is_img = x -> isfile(x) & ~isnothing(try Images.load(x) catch e end;)
is_kd_img = (x, k) -> is_img(x) & (length(size(Images.load(x)))==k)
is_2d_img = x -> is_kd_img(x, 2)
is_3d_img = x -> is_kd_img(x, 3)
is_rgb = x -> is_img(x) && (eltype(Images.load(x)) <: RGB)
read_dir = x -> isdir(x) ? (readdir(x, join=true) |>collect) : []
files = x -> [_x for _x in read_dir(x) if isfile(_x)]
has_n_files = (x, k) -> isdir(x) && (length(files(x))==k)
n_files_or_more = (x, k) -> isdir(x) && (length(files(x))>=k)
less_than_n_files = (x, k) -> isdir(x) && (length(files(x))<k)
subdirs = x -> [_x for _x in read_dir(x) if isdir(x)]
has_n_subdirs = (x, k) -> (length(subdirs(x))==k)
less_than_n_subdirs = (x, k) -> (length(subdirs(x))<k)
log_to_file = (x, fname) -> write_file(fname, x)
log_to_file_with_message = (x, fname, reason) -> write_file(fname, "$(x) :: reason $(reason)")
ignore = x -> nothing
always = x->true
always_triggers = always
never = x->false
fail = never
always_fails = never
sample = x->Random.rand()>0.5
size_of_file = x -> isfile(x) ? filesize(x) : 0
filename_ends_with_integer = x -> isfile(x) && endswith(splitext(basename(x))[1], r"[0-9]+$")
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

function decode_owncloud(config)
	c = config["owncloud_configuration"]
	if c == ""
		@debug "No owncloud configuration active"
		return nothing
	else
		try
        	tb = JSON.parse(String(read(c)))
			@info "Read $(tb)"
			_initialize_remote(tb)
			ENV["DC_owncloud_configuration"]=String(read(c))
        	return tb
    	catch e
        	@error "Reading $c failed because of $e"
        end
    end
end

function validate_global(config)
    glob_defaults = Dict([("endpoint", ""),("owncloud_configuration", ""),("scp_configuration", ""),("parallel", false),("common_conditions", Dict()), ("outputdirectory", nothing),("common_actions", Dict()), ("counters", Dict()), ("file_lists", Dict()),("regex", false),("act_on_success", false), ("inputdirectory", nothing),("traversal", Symbol("bottomup")), ("hierarchical", false)])
    # glob = config["global"]
    glob_default_types = Dict([("endpoint", String),("parallel", Bool), ("owncloud_configuration", String),("scp_configuration", String), ("counters", AbstractDict), ("file_lists", AbstractDict),("act_on_success", Bool), ("inputdirectory", AbstractString), ("traversal", Symbol("bottomup")), ("hierarchical", Bool)])
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
                "file_aggregators" => handlefilelists!(val, key, glob_defaults)
                "inputdirectory" => nothing
                "common_actions" => nothing
                "common_conditions" => nothing
                "outputdirectory" => nothing
                _ => handle_default!(val, key, glob_defaults)
            end
        else
            @error "Key $key in global not valid."
            return nothing
        end
    end
    if haskey(glob_config, "common_actions")
        @info "Handling common actions"
        @debug glob_config
        handle_common_actions(glob_config, glob_defaults)
    end
    if haskey(glob_config, "common_conditions")
        @info "Handling common conditions"
        @debug glob_config
        handle_common_conditions(glob_config, glob_defaults)
    end
    if haskey(glob_config, "outputdirectory")
        @info "Setting outputdirectory to $(glob_config["outputdirectory"])"
        glob_defaults["outputdirectory"] = glob_config["outputdirectory"]
    end
	if haskey(glob_config, "endpoint")
		if glob_config["endpoint"] != ""
			endpoint=SlurmMonitor.readendpoint(glob_config["endpoint"])
			if isnothing(endpoint)
				@error "Not a valid Slack Endpoint $(glob_config["endpoint"])"
			else
				glob_defaults["endpoint"] = endpoint
			end
        else
			@info "No slack support enabled"
		end
    end
	if haskey(glob_config, "owncloud_configuration")
		@info "Decoding OwnCloud"
		oc = decode_owncloud(glob_config)
		glob_defaults["owncloud_configuration"] = oc
    end
	if haskey(glob_config, "scp_configuration")
		@info "Decoding scp"
		validate_scp_config(glob_config["scp_configuration"])
		@info "Decoding scp success"
    end
    return glob_defaults
end


function handle_common_actions(config, default)
    entry = config["common_actions"]
    for name in keys(entry)
        @debug "Found $name with $(entry[name])"
        fun_desc = entry[name]
        fs = decode_function(fun_desc, default, condition=false)
        if isnothing(fs)
            @warn "Invalid common action $fun_desc for $name"
        else
            @info "Created common action for $name"
            default["common_actions"][name]=fs
        end
    end
end


function handle_common_conditions(config, default)
    entry = config["common_conditions"]
    for name in keys(entry)
        @debug "Found common condition with $name with $(entry[name])"
        fun_desc = entry[name]
        fs = decode_function(fun_desc, default, condition=true)
        if isnothing(fs)
            @warn "Invalid common condition $fun_desc for $name"
        else
            @info "Created common condition for $name"
            default["common_conditions"][name]=fs
        end
    end
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
            throw(ArgumentError("Invalid symbol $sym"))
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

## Fixme to use AG objects
function add_to_file_list(x, list)
    @debug "adding $x to $list"
    addentry!(list, x)
end

function aggregate_to(x, list)
    @debug "adding $x to $list"
    addentry!(list, x)
end

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

function list_to_file(x, f)
    return shared_list_to_file(x, f)
end

function shared_list_to_file(list::AbstractVector{<:AbstractVector}, fname)
    @debug "Nested list to file"
    return shared_list_to_file(flatten_list(list), fname)
end

function shared_list_to_file(list::AbstractVector, fname)
    @info "Writing $(length(list)) entries to $fname"
    if ~endswith(fname, ".txt")
        @debug "Changing extension to .txt"
        fname="$(fname).txt"
    end
    open(fname, "w"; lock=true) do f
        for entry in list
            @debug "Writing $entry"
            write(f, pad(entry))
        end
    end
	return fname
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

function new_path(root, node::AbstractVector, newroot)
    @debug "Vectorized new path called with $node $newroot"
    return new_path.(root, node, newroot)
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
    @debug "Threaded"
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
    @debug "Writing $fname to $vname in $m"
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
    @debug "Opening csv $csvfile"
	d = CSV.read(csvfile, DataFrame)
	D = Dict([(nm, d[!,nm]) for nm in names(d)])
	# file = matopen(mfile, "w")
    @debug "Writing to $mfile"
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
function verifier(node, template::Vector, level::Int; on_success=false)
    for step in template
        rv = dostep(node, step, on_success)
        if rv == :quit
            @debug "Early exit for $node at $level"
            return :quit
        end
    end
    return :proceed
end

function make_aggregator(name, list, adder, aggregator)
	@info "MAG $name"
    return @NamedTuple{name, list, adder, aggregator, transformer}((name, list, adder, aggregator, identity))
end


function make_aggregator(name, list, adder)
	@info "MAG2 $name"
    return @NamedTuple{name::AbstractString, list, adder, aggregator, transformer}((name, list, adder, shared_list_to_file, identity))
end


function make_aggregator(name::AbstractString, list, adder, aggregator, transformer)
	@info "MAG3 $name"
    return @NamedTuple{name, list, adder, aggregator, transformer}((name, list, adder, aggregator,transformer))
end

function aggregator_add(nt::NamedTuple{(:name, :list, :adder, :aggregator, :transformer), Tuple{Any, Any, Any, Any, Any}})
    nt.adder(nt.list, nt.transformer(x))
end

function aggregator_aggregate(nt::NamedTuple{(:name, :list, :adder, :aggregator, :transformer), Tuple{Any, Any, Any, Any, Any}})
    @info "Executing aggregator named: $(nt.name) with list $(nt.list)"
    nt.aggregator(nt.list, nt.name)
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
    # return all(f(x) for f in fs)
    @debug "Checking all of $fs to $x"
    for f in fs
        if f(x) == false
            @debug "Condition $f in sequence failed for $x"
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

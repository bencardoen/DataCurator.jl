module DataCurator
using Base.Threads
import Random
import Logging
# Write your package code here.

export topdown, bottomup, expand_filesystem, visit_filesystem, verifier, transformer, logical_and,
verify_template, always, never, warn_on_fail, quit_on_fail, sample, expand_sequential, expand_threaded, transform_template, quit, proceed, filename, integer_name

quit = :quit
proceed = :proceed
filename = x->basename(x)
integer_name = x->~isnothing(tryparse(Int, filename(x)))
warn_on_fail = x -> @warn "$x"
quit_on_fail = x -> begin @warn "$x"; return :quit; end

always = x->true
never = x->false
sample = x->Random.rand()>0.5


function verify_template(start, template; expander=expand_filesystem, traversalpolicy=bottomup, parallel_policy="sequential")
    if typeof(template) <: Vector || typeof(template) <: Dict
        return traversalpolicy(start, expander, verify_dispatch; context=Dict([("node", start), ("template", template), ("level",1)]),  inner=_expand_table[parallel_policy])
    else
        @error "Unsupported template"
        throw(ArgumentError("Template is of type $(typeof(template)) which is neither Vector, nor Dict"))
    end
end


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
        if rv == :quit
            @debug "Early exit triggered"
            return :quit
        end
    end
end


function expand_threaded(node, expander, visitor, context)
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
            @debug "Early exit triggered"
            return :quit
        end
    end
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
    inner(node, expander, visitor, context)
    early_exit = visitor(isnothing(context) ? node : context)
    if early_exit == :quit
        @debug "Early exit triggered"
        return :quit
    else
        return :proceed
    end
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
    early_exit = visitor(isnothing(context) ? node : context)
    if early_exit == :quit
        @debug "Early exit triggered"
        return :quit
    end
    inner(node, expander, visitor, context)
    return :proceed
end


function expand_filesystem(node)
    return isdir(node) ? readdir(node, join=true) : []
end

## Expand mat
## isdict, else variable

## Expand HDF5

function visit_filesystem(node)
    @info node
end

function transform_template(start, template; expander=expand_filesystem, traversalpolicy=bottomup, parallel_policy=:sequential)
    executor = _expand_table(parallel_policy)
    @error "FIXME"
    if typeof(template) <: Vector
        return traversalpolicy(start, expander, x->verifier(x, template), 1)
    else
        if typeof(template) <: Dict
            @info "Scaffolding"
        else
            @error "Unsupported template"
        end
    end
end
"""
    verifier(node, template::Vector, level::Int)
    Dispatched function to verify at recursion level with conditions set in template for node.
    Level is ignored for now, except to debug
"""
function verifier(node, template::Vector, level::Int)
    for (condition, onfail) in template
        if condition(node) == false
            rv = onfail(node)
            if rv == :quit
                @debug "Early exit for $node at $level"
                return :quit
            end
        end
    end
    return :proceed
end

"""
    verify_dispatch(context)
    Use multiple dispatch to call the right function verifier.
"""
function verify_dispatch(context)
    return verifier(context["node"], context["template"], context["level"])
end


"""
    verifier(node, templater::Dict, level::Int)
    Dispatched function to verify at recursion level with conditions set in templater[level] for node.
    Will apply templater[-1] as default if it's given, else no-op.
"""
function verifier(node, templater::Dict{Int, <:Vector{<:Tuple}}, level::Int)
    if haskey(templater, level)
        template = templater[level]
    else
        if haskey(templater, -1)
            @debug "Default verification"
            template = templater[-1]
        else
            template = []
            @debug "No verification at level $level for $node"
        end
    end
    for (condition, onfail) in template
        if condition(node) == false
            rv = onfail(node)
            if rv == :quit
                return :quit
            end
        end
    end
    return :proceed
end

function transformer(node, template)
    # @warn "X"
    for (condition, action) in template
        if condition(node)
            rv = action(node)
            if rv == :quit
                return :quit
            end
            node = isnothing(rv) ? node : rv
        end
    end
end

logical_and = (x, conditions) -> all(c(x) for c in conditions)

end

module DataCurator
using Base.Threads
import Random
import Logging
# Write your package code here.

export topdown, bottomup, expand_filesystem, visit_filesystem, verifier, transformer, logical_and,
verify_template, always, never, warn_on_fail, quit_on_fail, sample, transform_template, quit, proceed, filename, integer_name

quit = :quit
proceed = :proceed
filename = x->basename(x)
integer_name = x->~isnothing(tryparse(Int, filename(x)))
warn_on_fail = x -> @warn "$x"
quit_on_fail = x -> begin @warn "$x"; return :quit; end

function verify_template(start, template; expander=expand_filesystem, traversalpolicy=bottomup, parallel_policy=:sequential)
    if typeof(template) <: Vector || typeof(template) <: Dict
        return traversalpolicy(start, expander, verify_dispatch; context=Dict([("node", start), ("template", template), ("level",1)]))
    else
        @error "Unsupported template"
        throw(ArgumentError("Template is of type $(typeof(template)) which is neither Vector, nor Dict"))
    end
end

always = x->true
never = x->false
sample = x->Random.rand()>0.5

function bottomup(node, expander, visitor; context=nothing)
    nodes = expander(node)
    for _node in nodes
        if isnothing(context)
            ncontext = context
        else
            ncontext = copy(context)
            ncontext["level"] = context["level"] + 1
            ncontext["node"] = _node
        end
        rv = bottomup(_node, expander, visitor; context=ncontext)
        if rv == :quit
            @debug "Early exit triggered"
            return :quit
        end
    end
    early_exit = visitor(isnothing(context) ? node : context)
    if early_exit == :quit
        @debug "Early exit triggered"
        return :quit
    else
        return :proceed
    end
end



function topdown(node, expander, visitor; context=nothing)
    @debug node
    early_exit = visitor(isnothing(context) ? node : context)
    if early_exit == :quit
        @debug "Early exit triggered"
        return :quit
    end
    nodes = expander(node)
    for _node in nodes
        if isnothing(context)
            ncontext = context
        else
            ncontext = copy(context)
            ncontext["level"] = context["level"] + 1
            ncontext["node"] = _node
        end
        rv = topdown(_node, expander, visitor; context=ncontext)
        if rv == :quit
            @debug "Early exit triggered"
            return :quit
        end
    end
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

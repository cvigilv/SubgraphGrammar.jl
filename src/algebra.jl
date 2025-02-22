using Revise
using Graphs
using Tables: rows, columns, getcolumn, columnnames, columntable, AbstractColumns

# Layer type
abstract type AbstractAlgebraic end

Base.@kwdef struct Operation <: AbstractAlgebraic
    transformation::Function = identity
    graph::Any = nothing
    data::Any = nothing
    type::Any = []
end

# TODO: Add string representation of Layer
#   - Add 3 character hash at end of layer type
#   - Hash based on combination of layer arguments

# Collection of operations (a.k.a subgraph decomposition pipeline)
struct Pipeline <: AbstractAlgebraic
    operations::Vector{Operation}
end

Base.convert(::Type{Pipeline}, l::Operation) = Pipeline([l])
Base.getindex(pipeline::Pipeline, i::Int) = pipeline.operations[i]
Base.length(pipelinr::Pipeline) = length(pipelinr.operations)
Base.eltype(::Type{Pipeline}) = Operation
Base.iterate(pipeline::Pipeline, args...) = iterate(pipeline.operations, args...)

function Base.:+(a::AbstractAlgebraic, a′::AbstractAlgebraic)
    operations::Pipeline, operations′::Pipeline = a, a′
    return Pipeline(vcat(operations.operations, operations′.operations))
end

function Base.:*(a::AbstractAlgebraic, a′::AbstractAlgebraic)
    operations::Pipeline, operations′::Pipeline = a, a′
    return Pipeline([
        operation * operation′ for operation in operations for operation′ in operations′
    ])
end

# TODO: Add string representation of Layers
#   - Since the algebra is composable, we need to represent different layers
#   - Idea: has distinct instances of operators and add a #N after each symbol (similar to
#     how Julia does it with anonymous function

# Inter-operations algebra
⨟(f, g) = f === identity ? g : g === identity ? f : (x, y) -> g(f(x, y)...)

function Base.:*(l::T, l′::T) where {T<:Operation}
    # Check if operation is valid
    if l.type == l′.type
        error("Multipliying the same kind of operations is dissallowed")
    elseif (l.type == :match && l′.type == :infer) ||
           (l.type == :infer && l′.type == :match)
        error("Multiplying operations that generate subgraphs is dissallowed")
    end

    # Create new operation based on composition of previous operations
    transformation = l.transformation ⨟ l′.transformation
    graph = isnothing(l′.graph) ? l.graph : l′.graph
    data = isnothing(l′.data) ? l.data : l′.data
    type = vcat(l.type, l′.type)

    return Operation(
        graph = graph,
        transformation = transformation,
        data = data,
        type = type,
    )
end

# API
function data(G::AbstractGraph, data = nothing)
    return Operation(
        graph = G,
        data = !isnothing(data) ? columns(data) : nothing,
        type = :data,
    )
end

# Alternative names: apply, ruleset, rule
function infer(ƒ::Function, args...; kwargs...)
    Operation(transformation = (G, data) -> (ƒ(G, args...; kwargs...), data), type = :infer)
end

# Alternative names: search
function match(g::AbstractGraph)
    Operation(
        transformation = (G, data) -> (
            collect(
                map(
                    p -> first.(p),
                    collect(Graphs.Experimental.all_induced_subgraphisomorph(G, g)),
                ),
            ),
            data,
        ),
        type = :match,
    )
end

# Alternative names: annotate
function label(d::Any = nothing)
    Operation(
        transformation = (G, data) -> (collect(map(G) do s
            if !isnothing(d)
                map(n -> get(data[d], n, missing), s)
            else
                s
            end
        end), data),
        type = :label,
    )
end

# Alternative names: fold, combine
function reduce(ƒ::Function = hash, args...; kwargs...)
    Operation(
        transformation = (G, data) -> (ƒ(G, args...; kwargs...), data),
        type = :reduce,
    )
end

function compute(l::Operation)
    return first(l.transformation(l.graph, l.data))
end

function compute(L::Pipeline; flatten = true)
    results = map(L) do l
        compute(l)
    end
    if flatten
        return Base.reduce(append!, results, init = [])
    else
        return results
    end
end

# Test
# G1 = smallgraph(:krackhardtkite)
# G2 = smallgraph(:karate)
#
# M1 = (; c = rand([:red, :blue, :yellow], nv(G1)), k = collect(degree(G1)))
# M2 = (; c = rand([:red, :blue, :yellow], nv(G2)), k = collect(degree(G2)))
#
# df = (data(G1, M1) + data(G2, M2))
#
# layers = match(path_graph(3)) * (label(:c) + label(:k)) * reduce(unique)
#
# compute(df * layers; flatten = false)
#
# compute(df * layers; flatten = true)

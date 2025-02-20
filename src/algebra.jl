using Revise
using Graphs
using Tables: rows, columns, getcolumn, columnnames, columntable, AbstractColumns

# Layer type
abstract type AbstractAlgebraic end

Base.@kwdef struct Layer <: AbstractAlgebraic
    transformation::Function = identity
    graph::Any = nothing
    data::Any = nothing
    type::Any = []
end

# TODO: Add string representation of Layer
#   - Add 3 character hash at end of layer type
#   - Hash based on combination of layer arguments

# Collection of layers (a.k.a subgraph decomposition pipeline)
struct Layers <: AbstractAlgebraic
    layers::Vector{Layer}
end

Base.convert(::Type{Layers}, l::Layer) = Layers([l])
Base.getindex(layers::Layers, i::Int) = layers.layers[i]
Base.length(layers::Layers) = length(layers.layers)
Base.eltype(::Type{Layers}) = Layer
Base.iterate(layers::Layers, args...) = iterate(layers.layers, args...)

function Base.:+(a::AbstractAlgebraic, a′::AbstractAlgebraic)
    layers::Layers, layers′::Layers = a, a′
    return Layers(vcat(layers.layers, layers′.layers))
end

function Base.:*(a::AbstractAlgebraic, a′::AbstractAlgebraic)
    layers::Layers, layers′::Layers = a, a′
    return Layers([layer * layer′ for layer in layers for layer′ in layers′])
end

# TODO: Add string representation of Layers
#   - Since the algebra is composable, we need to represent different layers
#   - Idea: has distinct instances of operators and add a #N after each symbol (similar to
#     how Julia does it with anonymous function

# Inter-layer operations
⨟(f, g) = f === identity ? g : g === identity ? f : (x, y) -> g(f(x, y)...)

function Base.:*(l::T, l′::T) where {T<:Layer}
    # Check if operation is valid
    if l.type == l′.type
        error("Multipliying the same kind of layers is dissallowed")
    elseif (l.type == :match && l′.type == :infer) ||
           (l.type == :infer && l′.type == :match)
        error("Multiplying layers that generate subgraphs is dissallowed")
    end

    # Create new layer based on composition of previous layers
    transformation = l.transformation ⨟ l′.transformation
    graph = isnothing(l′.graph) ? l.graph : l′.graph
    data = isnothing(l′.data) ? l.data : l′.data
    type = vcat(l.type, l′.type)

    return Layer(graph = graph, transformation = transformation, data = data, type = type)
end

# API
function data(G::AbstractGraph, data = nothing)
    return Layer(graph = G, data = data, type = :data)
end

# Alternative names: apply, ruleset, rule
function infer(ƒ::Function, args...; kwargs...)
    Layer(transformation = (G, data) -> (ƒ(G, args...; kwargs...), data), type = :infer)
end

# Alternative names: search
function match(g::AbstractGraph)
    Layer(
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
    Layer(
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
    Layer(transformation = (G, data) -> (ƒ(G, args...; kwargs...), data), type = :reduce)
end

function compute(l::Layer)
    return first(l.transformation(l.graph, l.data))
end

function compute(L::Layers; flatten = true)
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

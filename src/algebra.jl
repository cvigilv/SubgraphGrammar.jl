using Graphs
using Tables: rows, columns, getcolumn, columnnames, columntable, AbstractColumns

# Types and structs {{{1
abstract type AbstractProcess end
abstract type AbstractAlgebraic <: AbstractProcess end

# Layer {{{2
struct Columns{T}
    columns::T
end

Base.@kwdef struct Layer <: AbstractAlgebraic
    transformation::Function = identity
    graph::Any = nothing
    data::Any = nothing
    type::Symbol = :base
end

⨟(f, g) = f === identity ? g : g === identity ? f : g ∘ f

function Base.:*(l::Layer, l′::Layer)
    if l.type == l′.type
        error("Multipliying the same kind of layers is dissallowed")
    end
    transformation = l.transformation ⨟ l′.transformation
    graph = isnothing(l′.graph) ? l.graph : l′.graph
    data = isnothing(l′.data) ? l.data : l′.data

    return Layer(graph = graph, transformation = transformation, data = data, type = :type)
end



# Layers {{{2
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

# Operators {{{2
function data(G::AbstractGraph, M::Any = nothing)
    Layer(graph = G, data = isnothing(M) ? nothing : Columns(columns(M)), type = :data)
end

function match(g::AbstractGraph)
    Layer(
        transformation = G ->
            Graphs.Experimental.all_induced_subgraphisomorph(G, g) |>
            collect |>
            s -> map(p -> first.(p), s),
        type = :match,
    )
end

function infer(ƒ::Function, args...; kwargs...)
    Layer(transformation = G -> ƒ(G, args...; kwargs...), type = :infer)
end

# FIXME: This doesn't take into consideration metadata provided
function label(d::Symbol)
    Layer(transformation = S -> map(S) do s
        map(n -> get(data[d], n, missing), s)
    end, type = :label)
end

function reduce()
    Layer(transformation = hash; type = :reduce)
end

function reduce(ƒ::Function, args...; kwargs...)
    Layer(transformation = S -> ƒ(S, args...; kwargs...), type = :reduce)
end


function compute(l::Layer)
    return l.transformation(l.graph)
end

function compute(L::Layers)
    return Base.reduce(append!, map(L) do l
        compute(l)
    end, init = [])
end

# # Examples {{{1
#
n_nodes = 50
mygraph = erdos_renyi(n_nodes, 0.1)
mydata = (; color = rand([:red, :blue, :yellow], n_nodes))

using DataStructures: counter

allneighborhoods(g, args...; kwargs...) =
    map(1:nv(g)) do node
        neighborhood(g, node, args...; kwargs...)
    end |> collect

#! format: off
(
    data(mygraph, mydata)
    * (
        match(Graph([0 1 0 1; 1 0 1 0; 0 1 0 1; 1 0 1 0])) +
        infer(allneighborhoods, 1)
    )
    * label(:color)
    * reduce(unique)
) |> compute
# #! format: on

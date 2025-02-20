# # Getting started with SubgraphGrammar.jl

using Graphs
using SubgraphGrammar

# Let's count how many neighboorhoods share the same characteristics:
#
# First, we will load the Zachary's karate club social network:

G = smallgraph(:krackhardtkite)

# From here we will compute some kind if characteristic of interest. For this example, we
# will are interested on knowing how many connections my connections have, therefore we
# will use as characteristic the node degree:

df = (; k = degree(G))

# define what to search

pattern = path_graph(3)

# Now, let's build our pipeline to extract all unique subgraphs:

data(G, df) * SubgraphGrammar.match(pattern) |> compute

# Not very informative, let's label the nodes by there degree to see if we get more information:

data(G, df) * SubgraphGrammar.match(pattern) * label(:k) * SubgraphGrammar.reduce(unique) |>
compute

# We can count them using the help of other packages, e.g. DataStructures

using DataStructures: counter

(
    data(G, df) *
    SubgraphGrammar.match(pattern) *
    label(:k) *
    SubgraphGrammar.reduce(counter)
) |> compute

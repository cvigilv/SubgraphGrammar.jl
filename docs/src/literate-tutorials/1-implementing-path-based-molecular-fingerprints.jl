# # Implementing molecular fingerprints with SubgraphGrammar.jl
#
# TODO: Description with image

using CairoMakie
using Graphs
using MolecularGraph
using SubgraphGrammar
using DataStructures: counter

# Read molecules
# TODO: explain

mol1 = smilestomol("Cc1ccc(OC(=O)c2ccc(CN3CCN(C)CC3)cc2)cc1Nc1nccc(-c2c(C)cnc2)n1")
#
mol2 = smilestomol("Cc1ccc(NC(=O)c2ccc(CN3CCN(CCO)CC3)cc2)cc1Nc1nccc(-c2cccnc2)n1")

# ## Atom count descriptor

mol_atoms = m -> [m.vprops[i].symbol for i = 1:nv(m.graph)]


(
    data(mol1.graph, (; atom = mol_atoms(mol1))) *  # Initialize pipeline
    SubgraphGrammar.match(Graph(1))               # Find all nodes
    *
    label(:atom)                                # Label them by atom type
    *
    SubgraphGrammar.reduce(counter)             # Count instances of each labeled node
) |> compute

#

(
    data(mol2.graph, (; atom = mol_atoms(mol2))) *
    SubgraphGrammar.match(Graph(1)) *
    label(:atom) *
    SubgraphGrammar.reduce(counter)
) |> compute

# You can also define the pipeline to use for fingerprinting and then compute

atom_count_fp = (
    SubgraphGrammar.match(Graph(1))               # Find all nodes
    * label(:atom)                                # Label them by atom type
    * SubgraphGrammar.reduce(counter)             # Count instances of each labeled node
)

#

compute(data(mol1.graph, (; atom = mol_atoms(mol1))) * atom_count_fp)

#

compute(data(mol2.graph, (; atom = mol_atoms(mol2))) * atom_count_fp)

# Or we can compute both on the fly and get a vector of fingerprints:

df = (
    data(mol1.graph, (; atom = mol_atoms(mol1))) +
    data(mol2.graph, (; atom = mol_atoms(mol2)))
)

compute(df * atom_count_fp; flatten = false)

# ---

# ## Path-based fingerprint
# TODO: explain

path_fp = (
    sum([SubgraphGrammar.match(path_graph(i)) for i = 1:7])  # Find all paths from 1 to 7 atoms long
    *
    label(:atom)                                            # Label by atom type
    *
    SubgraphGrammar.reduce(unique)                          # Remove duplicate subgraphs
)

# Getting information from molecules
# TODO: explain

computed_path_fp = [compute(mol * path_fp) for mol in df.layers]


# Compute Tanimoto / Jaccard index to assess molecule similarity

length(Set(computed_path_fp[1]) ∩ Set(computed_path_fp[2])) /
length(Set(computed_path_fp[1]) ∪ Set(computed_path_fp[2]))

# # Circular fingerprints
#
# Small helper function to get circular patterns
allneighbors = (G, args) -> map(1:nv(G)) do node
    neighborhood(G, node, args...)
end

allneighbors(mol1, 1)

# Define pipeline

circular_fp = (SubgraphGrammar.infer(allneighbors, 2) * (label(:atom) + label()))

# Compute pipeline

function merger(arr1, arr2)
    return [
        [(a, b) for (a, b) in zip(subarr1, subarr2)] for
        (subarr1, subarr2) in zip(arr1, arr2)
    ]
end

mol1_circ_fp = compute(first(df.layers) * circular_fp; flatten = false)

#

mol2_circ_fp = compute(last(df.layers) * circular_fp; flatten = false)

# Lets see the common subgraphs

common_fp = Set(first(mol1_circ_fp)) ∩ Set(first(mol2_circ_fp))

# Lets paint this in the molecules
mol1_common_fp = last(mol1_circ_fp)[map(collect(common_fp)) do circ
    findall(==(circ), first(mol1_circ_fp))
end|>Iterators.flatten|>collect]
mol2_common_fp = last(mol2_circ_fp)[map(collect(common_fp)) do circ
    findall(==(circ), first(mol2_circ_fp))
end|>Iterators.flatten|>collect];

#
html_fixed_size(mol1, 300, 300; atomhighlight = unique(Iterators.flatten(mol1_common_fp)))
#
html_fixed_size(mol2, 300, 300; atomhighlight = unique(Iterators.flatten(mol2_common_fp)))

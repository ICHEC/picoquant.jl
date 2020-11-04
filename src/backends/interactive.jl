export InteractiveBackend

# *************************************************************************** #
#                             Interactive Backend
# *************************************************************************** #

"The Interactive backend gets functions to act on a TensorNetworkCircuit
interactively."
mutable struct InteractiveBackend <: AbstractBackend
    use_gpu::Bool
    memory_size_mb::Int64
    tensors::Dict{Symbol, Array{<:Number}}
    metrics::Metrics

    function InteractiveBackend(use_gpu::Bool=false, memory_size_mb::Int64=0)
        tensors = Dict{Symbol, Array{<:Number}}()
        new(use_gpu, memory_size_mb, tensors, Metrics())
    end
end

"""
    function save_tensor_data(backend::InteractiveBackend,
                              tensor_label::Symbol,
                              tensor_data::Array{<:Number})

Function to save tensor data to a dictionary in an interactive backend.
"""
function save_tensor_data(backend::InteractiveBackend,
                          node_label::Symbol,
                          tensor_label::Symbol,
                          tensor_data::Array{<:Number})
    # TODO: node_label isn't used here but could be used when a tensor registry
    # is added to avoid duplication of tensor data.
    backend.tensors[tensor_label] = tensor_data
end

"""
    function load_tensor_data(backend::InteractiveBackend,
                              tensor_label::Symbol)

Function to load tensor data from backend storage (if present)
"""
function load_tensor_data(backend::InteractiveBackend,
                          tensor_label::Symbol)
    if tensor_label in keys(backend.tensors)
        return backend.tensors[tensor_label]
    end
end


"""
    function contract_tensors(backend::InteractiveBackend,
                              A_label::Symbol, A_ncon_indices::Array{<:Integer, 1},
                              B_label::Symbol, B_ncon_indices::Array{<:Integer, 1},
                              C_label::Symbol)

Function to interactively contract two tensors A and B to create a tensor C.
"""
function contract_tensors(backend::InteractiveBackend,
                          A_label::Symbol, A_ncon_indices::Array{<:Integer, 1},
                          B_label::Symbol, B_ncon_indices::Array{<:Integer, 1},
                          C_label::Symbol)

    # Get the tensor data for A and B and compute the tensor data for C.
    A_data = backend.tensors[A_label]
    B_data = backend.tensors[B_label]
    C_data = contract_tensors((A_data, B_data),
                              (A_ncon_indices, B_ncon_indices))
    if typeof(C_data) <: Number
        C_data = [C_data]
    end

    # Save the new tensor and delete the tensors that were contracted.
    backend.tensors[C_label] = C_data
    delete_tensor!(backend, A_label)
    delete_tensor!(backend, B_label)
end

"""
    function save_output(backend::InteractiveBackend, node::Symbol, name::String)

Function to save the result of fully contracting a network under the given
name.
"""
function save_output(backend::InteractiveBackend,
                     node::Symbol, name::String="result")
    name = Symbol(name)
    backend.tensors[name] = backend.tensors[node]
end

"""
    function reshape_tensor(backend::InteractiveBackend,
                            tensor::Symbol,
                            groups::Array{Array{<:Integer, 1}, 1})

Function to reshape a given tensor.
"""
function reshape_tensor(backend::InteractiveBackend,
                        tensor::Symbol,
                        groups::Array{<:Array{<:Integer, 1}, 1})
    tensor_dims = size(backend.tensors[tensor])
    backend.tensors[tensor] = reshape_tensor(backend.tensors[tensor], [prod(tensor_dims[x]) for x in groups])
end


"""
    function permute_tensor(backend::InteractiveBackend, tensor::Symbol, axes)

Function to permute the axes of the given tensor
"""
function permute_tensor(backend::InteractiveBackend,
                        tensor::Symbol,
                        axes::Array{<:Integer, 1})
    backend.tensors[tensor] = permute_tensor(backend.tensors[tensor], axes)
end

"""
    function decompose_tensor!(backend::InteractiveBackend,
                               tensor::Symbol,
                               left_positions::Array{Int, 1},
                               right_positions::Array{Int, 1};
                               threshold::AbstractFloat=1e-13,
                               max_rank::Integer=0,
                               left_label::Symbol,
                               right_label::Symbol)

Function to decompose a single tensor into two tensors and return the dimension
of the newly created virtual edge.
"""
function decompose_tensor!(backend::InteractiveBackend,
                           tensor::Symbol,
                           left_positions::Array{Int, 1},
                           right_positions::Array{Int, 1};
                           threshold::AbstractFloat=1e-13,
                           max_rank::Integer=0,
                           left_label::Symbol,
                           right_label::Symbol)

    node_data = backend.tensors[tensor]

    (B, C, chi) = decompose_tensor(node_data,
                              left_positions,
                              right_positions,
                              threshold=threshold,
                              max_rank=max_rank)

    backend.tensors[left_label] = B
    backend.tensors[right_label] = C

    delete_tensor!(backend, tensor)
    chi
end

"""
    function delete_tensor!(backend::InteractiveBackend, tensor_label::Symbol)

Mark tensor for deletion
"""
function delete_tensor!(backend::InteractiveBackend, tensor_label::Symbol)
    delete!(backend.tensors, tensor_label)
end


"""
    function view_tensor!(backend::InteractiveBackend, view_node, node, bond_idx, bond_range)

Create a view on a tensor
"""
function view_tensor!(backend::InteractiveBackend, view_node, node, bond_idx, bond_range)
    node_data = backend.tensors[node]
    backend.tensors[view_node] = tensor_view(node_data, bond_idx, bond_range)
end
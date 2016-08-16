"""

#### References

Smooth function approximation using neural networks.

S Ferrari and R F Stengel.

IEEE Trans Neural Netw, 2005 vol. 16 (1) pp. 24-38.

http://ieeexplore.ieee.org/lpdocs/epic03/wrapper.htm?arnumber=1388456
"""
type AlgebraicNetwork{TA<:AbstractActivation} <: AbstractSLFN
    p::Int  # Number of training points
    q::Int  # Dimensionality of function domain
    s::Int  # number of neurons
    n_train_it::Int  # number of training iterations
    activation::TA
    Wt::Matrix{Float64}  # transpose of W matrix
    d::Vector{Float64}
    v::Vector{Float64}

    function AlgebraicNetwork(p::Int, q::Int, s::Int, activation::TA)
        Wt = Array(Float64, q, s)
        d = Array(Float64, s)
        v = Array(Float64, s)
        new(p, q, s, 0, activation, Wt, d, v)
    end
end

function AlgebraicNetwork{TA<:AbstractActivation}(x::AbstractArray, y::AbstractArray,
                                                  activation::TA=Sigmoid(),
                                                  s::Int=size(x, 1), f::Float64=4.5, maxit::Int=1000)
    p = size(x, 1)
    q = size(x, 2)

    @assert size(y, 1) == p "x and y must have same number of observations"

    s = min(s, p)
    out = AlgebraicNetwork{TA}(p, q, s, activation)
    fit!(out, x, y, f, maxit)
    out
end

# algorithm that includes gradient information
function AlgebraicNetwork(x::AbstractArray, y::AbstractArray,
                          c::AbstractArray, activatoin::AbstractActivation=Sigmoid,
                          s::Int=size(y, 1), f::Float64=5.0,
                          tol::Float64=1e-5, maxit::Int=1000)
    e = size(c, 1)
    p = size(x, 1)
    @assert size(c, 2) == p "need one gradient column for each training sample"

    # do initial fit
    out = AlgebraicNetwork(x, y, activation; s=s, f=f, maxit=maxit)

    N = input_to_node(out, x)

    # now loop over training points to refine fit using gradient info
    for i in 1:p
        wi_old = vec(out.Wt[:, i])
        c_i = slice(c, :, i)
        c_network = (out.v' .* deriv(out.activation, N[i, :])) * out.Wt'
        if maxabs(c_network - c_i) > tol
            wi = out.Wt[:, i] + (c_i - c_network)/(out.v[i] * deriv(out.activation, N[i, i]))
            wi_new = maxabs(wi) > 50 ? wi : wi_old
        else
            wi_new = wi_old
        end

        out.Wt[:, i] = wi_new
        out.d[i] = -dot(slice(x, i, :), out.Wt[:, i])
        N[:, i] = out.d[i] + x*out.Wt[:, i]

        S = out.activation(N)
        out.v = S \ y
    end

    out

end

## API methods

isexact(an::AlgebraicNetwork) = an.p == an.s
input_to_node(an::AlgebraicNetwork, y::AbstractArray) = y*an.Wt .+ an.d'
sigmoid_mat(an::AlgebraicNetwork, y::AbstractArray) = an.activation(input_to_node(an, y))

function fit!(an::AlgebraicNetwork, x::AbstractArray, y::AbstractVector,
              f::Float64=4.5, maxit::Int=1000)
    for i in 1:maxit
        scale!(randn!(an.Wt), f)
        an.d = -diag(x * an.Wt)
        S = sigmoid_mat(an, x)

        the_rank = rank(S)

        if rank(S) < an.s && i < maxit
            an.n_train_it += 1
            continue
        else
            an.v = S \ y
            return an
        end
    end

end

function (an::AlgebraicNetwork)(x′::AbstractArray)
    @assert size(x′, 2) == an.q "wrong input dimension"
    return sigmoid_mat(an, x′) * an.v
end

function Base.show{TA}(io::IO, an::AlgebraicNetwork{TA})
    s =
    """
    AlgebraicNetwork with
      - $(TA) Activation function
      - $(an.q) input dimension(s)
      - $(an.s) neuron(s)
      - $(an.p) training point(s)
    """
    print(io, s)
end
module OffsetIndices

export ZeroIndex, Z, @zeroindexing

immutable ZeroIndex <: Integer
    i::Int
end
typealias Z ZeroIndex

Base.to_index(z::ZeroIndex) = z.i+1
Base.checkbounds(::Type{Bool}, sz::Integer, z::ZeroIndex) = checkbounds(Bool, sz, z.i+1)

Base.one(::ZeroIndex) = ZeroIndex(1)
Base.one(::Type{ZeroIndex}) = ZeroIndex(1)
import Base: *, <, <=, -, +
*(i::Integer, ::Type{ZeroIndex}) = ZeroIndex(i)
for op in (:(<), :(<=))
    @eval ($op)(a::ZeroIndex, b::ZeroIndex) = $(op)(a.i, b.i)
end
for op in (:(-), :(+))
    @eval ($op)(a::ZeroIndex, b::ZeroIndex) = ZeroIndex($(op)(a.i, b.i))
    @eval ($op)(a::ZeroIndex, b::Int) = ZeroIndex($(op)(a.i, b))
end
# This is a kludge, but I don't want to define conversion methods
# to ensure we don't lose the zero-indexing-ness in unexpected places
Base.length(r::UnitRange{ZeroIndex}) = (r.stop - r.start + 1).i

# Let's define zero-indexing for tuples, too:
Base.getindex(t::Tuple, i::ZeroIndex) = t[i+1]

# And a macro to make entire blocks zero-indexed
macro zeroindexing(expr)
    esc(_zi(expr))
end

_zi(x) = x
function _zi(expr::Expr)
    if expr.head == :ref
        Expr(:ref, expr.args[1], map(x->:(OffsetIndices._ziwrap($(_zi(x)))), expr.args[2:end])...)
    else
        Expr(expr.head, expr.args[1], map(_zi, expr.args[2:end])...)
    end
end
_ziwrap(i::Integer) = ZeroIndex(i)
_ziwrap(A::AbstractArray) = map(ZeroIndex, A) # TODO: should @zeroindex A[0:end] be half open?
_ziwrap(c::Colon) = c

## Range indexing doesn't use to_index
Base.getindex{T}(r::UnitRange{T}, i::ZeroIndex) = r[i.i+1]
Base.getindex{T}(r::Range{T}, i::ZeroIndex) = r[i.i+1]
Base.getindex{T}(r::FloatRange{T}, i::ZeroIndex) = r[i.i+1]
Base.getindex{T}(r::LinSpace{T}, i::ZeroIndex) = r[i.i+1]
Base.getindex(r::UnitRange, s::UnitRange{ZeroIndex}) = error("unimplemented")
Base.getindex(r::UnitRange, s::StepRange{ZeroIndex}) = error("unimplemented")
Base.getindex(r::StepRange, s::Range{ZeroIndex}) = error("unimplemented")
Base.getindex(r::FloatRange, s::OrdinalRange{ZeroIndex}) = error("unimplemented")
Base.getindex{T}(r::LinSpace{T}, s::OrdinalRange{ZeroIndex}) = error("unimplemented")

# And SubArray also doesn't use to_index for its LinearFast compuations:
import Base: compute_first_index, @_inline_meta, tail
compute_first_index(f, s, parent, dim, I::Tuple{ZeroIndex, Vararg{Any}}) =
    (@_inline_meta; compute_first_index(f + I[1].i*s, s*size(parent, dim), parent, dim+1, tail(I)))


## Midpoint indices are tougher since they require context to resolve.
# we hack into base a different way
immutable MidpointIndex
    i::Int
end
typealias M MidpointIndex
import Base: LinearIndexing, @propagate_inbounds
# MidpointIndex is not an Integer! This allows us to hack into base:
@propagate_inbounds function Base._getindex{T,N}(l::Base.LinearIndexing, A::AbstractArray{T,N}, I::Union{Number,AbstractArray,Colon,MidpointIndex}...)
    A[_ti(A, 1, I)...]
end
import Base: *
*(i::Integer, ::Type{MidpointIndex}) = MidpointIndex(i)
_ti(A, d, I::Tuple{}) = ()
@propagate_inbounds function _ti(A, d, I::Tuple{MidpointIndex, Vararg{Any}})
    sz = size(A, d)
    @boundscheck iseven(sz) && throw_size_error(A, d)
    (sz>>1+I[1].i+1, _ti(A, d+1, Base.tail(I))...)
end
@propagate_inbounds _ti(A, d, I::Tuple{Any, Vararg{Any}}) = (I[1], _ti(A, d+1, Base.tail(I))...)

@noinline throw_size_error(A, d) = error("dimension $d must be odd to use a MidpointIndex")
# But since MidpointIndexes aren't integers, range support is much tougher.

end # module

module OffsetIndices

export ZeroIndex, Z, @zeroindexing, MidpointIndex, M

struct ZeroIndex{T}
    i::T
end
const Z = ZeroIndex
Base.:*(i, ::Type{<:ZeroIndex}) = ZeroIndex(i)

Base.to_index(z::ZeroIndex) = z.i+1
Base.to_index(Z::AbstractArray{<:ZeroIndex}) = [Base.to_index(z) for z in Z]
Base.to_index(Z::Base.Range{<:ZeroIndex}) = Z[1]+1:Z[end]+1
# Some index types are not modified by zero-indexing:
Base.to_index(Z::ZeroIndex{<:AbstractArray{Bool}}) = Z.i
Base.to_index(Z::ZeroIndex{Colon}) = Z.i

# Implement zero-indexing directly for common Base datastructures that don't use to_index:
const NonArrayZeroIndexedTypes = Union{AbstractString, Tuple, Number, Char, Pair, SimpleVector}
Base.@propagate_inbounds Base.getindex(x::NonArrayZeroIndexedTypes, i::ZeroIndex) = t[i.i+1]

# And a macro to make entire blocks zero-indexed
macro zeroindexing(expr)
    _zi(expr, nothing)
end
_zi(x, ctx) = esc(x)
_zi(x::Symbol, ctx) = x == :end ? :(_ziend($(esc(x)), $(ctx))) : esc(x)
function _zi(expr::Expr, ctx)
    if expr.head == :quote
        esc(expr)
    elseif expr.head == :ref
        src = gensym(:src)
        quote
            $src = $(esc(expr.args[1]))
            $(Expr(:ref, src, map(x->:(_ziwrap($src, $(_zi(x, src)))), expr.args[2:end])...))
        end
    else
        Expr(expr.head, map(_zi, expr.args)...)
    end
end
const SupportedZeroIndexTypes = Union{AbstractArray, NonArrayZeroIndexedTypes}
_ziwrap(::SupportedZeroIndexTypes, i) = ZeroIndex(i)
_ziwrap(::Any, i) = i
_ziend(sz, ::SupportedZeroIndexTypes) = sz - 1
_ziend(sz, ::Any) = sz

## Midpoint indices are similar, but we use to_indices since they require context to resolve.
struct MidpointIndex{T}
    i::T
end
const M = MidpointIndex
import Base: *
*(i, ::Type{<:MidpointIndex}) = MidpointIndex(i)

@noinline throw_size_error(d, sz) = throw(ArgumentError("dimension $d has length $sz but it must be odd to use a MidpointIndex"))

function Base.to_indices(A, inds, I::Tuple{MidpointIndex, Vararg{Any}})
    rest = Base.tail(I)
    sz = Base.unsafe_length(Base.uncolon(inds, (:, rest...)))
    iseven(sz) && throw_size_error(ndims(A)-length(inds)+1, sz)
    to_indices(A, inds, (sz>>1+I[1].i+1, rest...))
end

# And support for tuples:
Base.@propagate_inbounds function Base.getindex(t::Tuple, m::MidpointIndex)
    @boundscheck iseven(length(t)) && throw_size_error(1, length(t))
    t[sz>>1+m.i+1]
end

end # module

# OffsetIndices

[![Build Status](https://travis-ci.org/mbauman/OffsetIndices.jl.svg?branch=master)](https://travis-ci.org/mbauman/OffsetIndices.jl)

Tech demo for zero-indexing (and maybe other offset indexing) support using custom index types.  The special `ZeroIndex` type flags an index as an offset from 0. Instead of the verbose `ZeroIndex(0)` spelling, the alias `Z` is exported and juxtaposed multiplication is supported such that `5Z == ZeroIndex(5)`:

```julia
julia> A = reshape(collect(1:60), 4, 5, 3);

julia> A[0Z,0Z,0Z]
1

julia> A[3Z,4Z,2Z]
60

julia> A[[0Z,2Z],:,0Z]
2×5 Array{Int64,2}:
 1  5   9  13  17
 3  7  11  15  19
 
julia> view(A, 0Z, :, [0Z, 1Z])
5×2 SubArray{Int64,2,Array{Int64,3},Tuple{Int64,Base.Slice{Base.OneTo{Int64}},Array{Int64,1}},false}:
  1  21
  5  25
  9  29
 13  33
 17  37
```

There's also a `@zeroindexing` macro that automatically wraps indices with the ZeroIndex type:

```
julia> @zeroindexing A[3,4,2]
60

julia> @zeroindexing A[0,:,0]
5-element Array{Int64,1}:
  1
  5
  9
 13
 17
 
julia> @zeroindexing for i=0:2
           println(A[i, 0, 0])
       end
1
2
3
```

It's notable that there is no overhead in using the ZeroIndex type.  In fact, religous zero-indexing zealots will be pleased to note that there's no need for subtracting one in multi-dimensional array accesses:

```jl
julia> f(A, i1, i2, i3) = @inbounds return A[i1,i2,i3]
       A = rand(3,3,3)
       @code_native f(A, 1,1,1)
	.section	__TEXT,__text,regular,pure_instructions
Filename: REPL[5]
	pushq	%rbp
	movq	%rsp, %rbp
	movq	(%rdi), %rax
Source line: 1
	decq	%rcx
	imulq	32(%rdi), %rcx
	leaq	-1(%rdx,%rcx), %rcx
	imulq	24(%rdi), %rcx
	addq	%rsi, %rcx
	movsd	-8(%rax,%rcx,8), %xmm0  ## xmm0 = mem[0],zero
	popq	%rbp
	retq
	nopw	%cs:(%rax,%rax)

julia> @code_native f(A, 0Z, 0Z, 0Z)
	.section	__TEXT,__text,regular,pure_instructions
Filename: REPL[28]
Source line: 0
	pushq	%rbp
	movq	%rsp, %rbp
	movq	(%rdi), %r8
	movq	32(%rdi), %rax
Source line: 1
	imulq	(%rcx), %rax
	addq	(%rdx), %rax
	imulq	24(%rdi), %rax
	addq	(%rsi), %rax
	movsd	(%r8,%rax,8), %xmm0     ## xmm0 = mem[0],zero
	popq	%rbp
	retq
	nopw	%cs:(%rax,%rax)
```

#### Open questions:

* Should `A[0Z:end*Z]` form a half-open pythonic range? What about `@zeroindexing A[0:end]`?
* Should `@zeroindexing` try to identify `sub` and `slice` and similarly munge its indices?
* Midpoint indices could supported in the same way if a little extra context were provided in `to_index` (e.g., https://github.com/JuliaLang/julia/pull/15750). But there's another way to hack into Base's indexing algorithm: if the index type isn't a Number, we can catch the it in the fallback indexing methods with a `::Union{Real, AbstractArray, Colon, MidpointIndex}` and override it there. Is this more robust? Or more fragile? Or simply more bizarre?  It does make midpoint ranges more difficult.

```jl
julia> A = rand(3,3)
3×3 Array{Float64,2}:
 0.311084  0.769411    0.0739746
 0.133199  0.370099    0.549994
 0.933168  0.00262457  0.358948

julia> M = OffsetIndices.M
OffsetIndices.MidpointIndex

julia> A[0M, 0M]
0.3700991722926237
```

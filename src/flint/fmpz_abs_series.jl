###############################################################################
#
#   fmpz_abs_series.jl : Power series over flint fmpz integers
#
###############################################################################

export fmpz_abs_series, FmpzAbsSeriesRing, PowerSeriesRing

###############################################################################
#
#   Data type and parent object methods
#
###############################################################################

function O(a::fmpz_abs_series)
   if iszero(a)
      return deepcopy(a)    # 0 + O(x^n)
   end
   prec = length(a) - 1
   prec < 0 && throw(DomainError(prec, "Precision must be non-negative"))
   z = fmpz_abs_series(Vector{fmpz}(undef, 0), 0, prec)
   z.parent = parent(a)
   return z
end

elem_type(::Type{FmpzAbsSeriesRing}) = fmpz_abs_series

parent_type(::Type{fmpz_abs_series}) = FmpzAbsSeriesRing

base_ring(R::FmpzAbsSeriesRing) = R.base_ring

abs_series_type(::Type{fmpz}) = fmpz_abs_series

var(a::FmpzAbsSeriesRing) = a.S

###############################################################################
#
#   Basic manipulation
#
###############################################################################

max_precision(R::FmpzAbsSeriesRing) = R.prec_max

function normalise(a::fmpz_abs_series, len::Int)
   if len > 0
      c = fmpz()
      ccall((:fmpz_poly_get_coeff_fmpz, libflint), Nothing,
         (Ref{fmpz}, Ref{fmpz_abs_series}, Int), c, a, len - 1)
   end
   while len > 0 && iszero(c)
      len -= 1
      if len > 0
         ccall((:fmpz_poly_get_coeff_fmpz, libflint), Nothing,
            (Ref{fmpz}, Ref{fmpz_abs_series}, Int), c, a, len - 1)
      end
   end

   return len
end

function length(x::fmpz_abs_series)
   return ccall((:fmpz_poly_length, libflint), Int, (Ref{fmpz_abs_series},), x)
end

precision(x::fmpz_abs_series) = x.prec

function coeff(x::fmpz_abs_series, n::Int)
   if n < 0
      return fmpz(0)
   end
   z = fmpz()
   ccall((:fmpz_poly_get_coeff_fmpz, libflint), Nothing,
         (Ref{fmpz}, Ref{fmpz_abs_series}, Int), z, x, n)
   return z
end

zero(R::FmpzAbsSeriesRing) = R(0)

one(R::FmpzAbsSeriesRing) = R(1)

function gen(R::FmpzAbsSeriesRing)
   z = fmpz_abs_series([fmpz(0), fmpz(1)], 2, max_precision(R))
   z.parent = R
   return z
end

function deepcopy_internal(a::fmpz_abs_series, dict::IdDict)
   z = fmpz_abs_series(a)
   z.prec = a.prec
   z.parent = parent(a)
   return z
end

function isgen(a::fmpz_abs_series)
   return precision(a) == 0 || ccall((:fmpz_poly_is_gen, libflint), Bool,
                            (Ref{fmpz_abs_series},), a)
end

iszero(a::fmpz_abs_series) = length(a) == 0

isunit(a::fmpz_abs_series) = valuation(a) == 0 && isunit(coeff(a, 0))

function isone(a::fmpz_abs_series)
   return precision(a) == 0 || ccall((:fmpz_poly_is_one, libflint), Bool,
                                (Ref{fmpz_abs_series},), a)
end

# todo: write an fmpz_poly_valuation
function valuation(a::fmpz_abs_series)
   for i = 1:length(a)
      if !iszero(coeff(a, i - 1))
         return i - 1
      end
   end
   return precision(a)
end

characteristic(::FmpzAbsSeriesRing) = 0

###############################################################################
#
#   Similar
#
###############################################################################

function similar(f::AbsSeriesElem, R::FlintIntegerRing, max_prec::Int,
                                   s::Symbol=var(parent(f)); cached::Bool=true)
   z = fmpz_abs_series()
   if base_ring(f) === R && s == var(parent(f)) &&
      typeof(f) == fmpz_abs_series && max_precision(parent(f)) == max_prec
      # steal parent in case it is not cached
      z.parent = parent(f)
   else
      z.parent = FmpzAbsSeriesRing(max_prec, s, cached)
   end
   z.prec = max_prec
   return z
end

###############################################################################
#
#   abs_series constructor
#
###############################################################################

function abs_series(R::FlintIntegerRing, arr::Vector{T},
                           len::Int, prec::Int, var::String="x";
                            max_precision::Int=prec, cached::Bool=true) where T
   prec < len && error("Precision too small for given data")
   coeffs = T == fmpz ? arr : map(R, arr)
   coeffs = length(coeffs) == 0 ? fmpz[] : coeffs
   z = fmpz_abs_series(coeffs, len, prec)
   z.parent = FmpzAbsSeriesRing(max_precision, Symbol(var), cached)
   return z
end

###############################################################################
#
#   AbstractString I/O
#
###############################################################################

function show(io::IO, a::FmpzAbsSeriesRing)
   print(io, "Univariate power series ring in ", var(a), " over ")
   show(io, base_ring(a))
end

###############################################################################
#
#   Unary operators
#
###############################################################################

function -(x::fmpz_abs_series)
   z = parent(x)()
   ccall((:fmpz_poly_neg, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}),
               z, x)
   z.prec = x.prec
   return z
end

###############################################################################
#
#   Binary operators
#
###############################################################################

function +(a::fmpz_abs_series, b::fmpz_abs_series)
   check_parent(a, b)
   lena = length(a)
   lenb = length(b)

   prec = min(a.prec, b.prec)

   lena = min(lena, prec)
   lenb = min(lenb, prec)

   lenz = max(lena, lenb)
   z = parent(a)()
   z.prec = prec
   ccall((:fmpz_poly_add_series, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
               z, a, b, lenz)
   return z
end

function -(a::fmpz_abs_series, b::fmpz_abs_series)
   check_parent(a, b)
   lena = length(a)
   lenb = length(b)

   prec = min(a.prec, b.prec)

   lena = min(lena, prec)
   lenb = min(lenb, prec)

   lenz = max(lena, lenb)
   z = parent(a)()
   z.prec = prec
   ccall((:fmpz_poly_sub_series, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
               z, a, b, lenz)
   return z
end

function *(a::fmpz_abs_series, b::fmpz_abs_series)
   check_parent(a, b)
   lena = length(a)
   lenb = length(b)

   aval = valuation(a)
   bval = valuation(b)

   prec = min(a.prec + bval, b.prec + aval)
   prec = min(prec, max_precision(parent(a)))

   lena = min(lena, prec)
   lenb = min(lenb, prec)

   z = parent(a)()
   z.prec = prec

   if lena == 0 || lenb == 0
      return z
   end

   lenz = min(lena + lenb - 1, prec)

   ccall((:fmpz_poly_mullow, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
               z, a, b, lenz)
   return z
end

###############################################################################
#
#   Ad hoc binary operators
#
###############################################################################

function *(x::Int, y::fmpz_abs_series)
   z = parent(y)()
   z.prec = y.prec
   ccall((:fmpz_poly_scalar_mul_si, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
               z, y, x)
   return z
end

*(x::fmpz_abs_series, y::Int) = y * x

function *(x::fmpz, y::fmpz_abs_series)
   z = parent(y)()
   z.prec = y.prec
   ccall((:fmpz_poly_scalar_mul_fmpz, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Ref{fmpz}),
               z, y, x)
   return z
end

*(x::fmpz_abs_series, y::fmpz) = y * x

*(x::Integer, y::fmpz_abs_series) = fmpz(x)*y

*(x::fmpz_abs_series, y::Integer) = y*x

###############################################################################
#
#   Shifting
#
###############################################################################

function shift_left(x::fmpz_abs_series, len::Int)
   len < 0 && throw(DomainError(len, "Shift must be non-negative"))
   xlen = length(x)
   z = parent(x)()
   z.prec = x.prec + len
   z.prec = min(z.prec, max_precision(parent(x)))
   zlen = min(z.prec, xlen + len)
   ccall((:fmpz_poly_shift_left, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
               z, x, len)
   ccall((:fmpz_poly_set_trunc, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
               z, z, zlen)
   return z
end

function shift_right(x::fmpz_abs_series, len::Int)
   len < 0 && throw(DomainError(len, "Shift must be non-negative"))
   xlen = length(x)
   z = parent(x)()
   if len >= xlen
      z.prec = max(0, x.prec - len)
   else
      z.prec = x.prec - len
      ccall((:fmpz_poly_shift_right, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
               z, x, len)
   end
   return z
end

###############################################################################
#
#   Truncation
#
###############################################################################

function truncate(x::fmpz_abs_series, prec::Int)
   prec < 0 && throw(DomainError(prec, "Index must be non-negative"))
   if x.prec <= prec
      return x
   end
   z = parent(x)()
   z.prec = prec
   ccall((:fmpz_poly_set_trunc, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
               z, x, prec)
   return z
end

###############################################################################
#
#   Powering
#
###############################################################################

function ^(a::fmpz_abs_series, b::Int)
   b < 0 && throw(DomainError(b, "Exponent must be non-negative"))
   if precision(a) > 0 && isgen(a) && b > 0
      return shift_left(a, b - 1)
   elseif length(a) == 1
      return parent(a)([coeff(a, 0)^b], 1, a.prec)
   elseif b == 0
      z = one(parent(a))
      z = set_precision!(z, precision(a))
      return z
   else
      z = parent(a)()
      z.prec = a.prec + (b - 1)*valuation(a)
      z.prec = min(z.prec, max_precision(parent(a)))
      ccall((:fmpz_poly_pow_trunc, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int, Int),
               z, a, b, z.prec)
   end
   return z
end

###############################################################################
#
#   Comparison
#
###############################################################################

function ==(x::fmpz_abs_series, y::fmpz_abs_series)
   check_parent(x, y)
   prec = min(x.prec, y.prec)

   n = max(length(x), length(y))
   n = min(n, prec)

   return Bool(ccall((:fmpz_poly_equal_trunc, libflint), Cint,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
               x, y, n))
end

function isequal(x::fmpz_abs_series, y::fmpz_abs_series)
   if parent(x) != parent(y)
      return false
   end
   if x.prec != y.prec || length(x) != length(y)
      return false
   end
   return Bool(ccall((:fmpz_poly_equal, libflint), Cint,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}),
               x, y))
end

###############################################################################
#
#   Ad hoc comparisons
#
###############################################################################

function ==(x::fmpz_abs_series, y::fmpz)
   if length(x) > 1
      return false
   elseif length(x) == 1
      z = fmpz()
      ccall((:fmpz_poly_get_coeff_fmpz, libflint), Nothing,
                       (Ref{fmpz}, Ref{fmpz_abs_series}, Int), z, x, 0)
      return ccall((:fmpz_equal, libflint), Bool,
               (Ref{fmpz}, Ref{fmpz}, Int), z, y, 0)
   else
      return precision(x) == 0 || iszero(y)
   end
end

==(x::fmpz, y::fmpz_abs_series) = y == x

==(x::fmpz_abs_series, y::Integer) = x == fmpz(y)

==(x::Integer, y::fmpz_abs_series) = y == x

###############################################################################
#
#   Exact division
#
###############################################################################

function divexact(x::fmpz_abs_series, y::fmpz_abs_series; check::Bool=true)
   check_parent(x, y)
   iszero(y) && throw(DivideError())
   v2 = valuation(y)
   v1 = valuation(x)
   if v2 != 0
      if check && v1 < v2
         error("Not an exact division")
      end
      x = shift_right(x, v2)
      y = shift_right(y, v2)
   end
   prec = min(x.prec, y.prec - v2 + v1)
   z = parent(x)()
   z.prec = prec
   ccall((:fmpz_poly_div_series, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
               z, x, y, prec)
   return z
end

###############################################################################
#
#   Ad hoc exact division
#
###############################################################################

function divexact(x::fmpz_abs_series, y::Int; check::Bool=true)
   y == 0 && throw(DivideError())
   z = parent(x)()
   z.prec = x.prec
   ccall((:fmpz_poly_scalar_divexact_si, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
               z, x, y)
   return z
end

function divexact(x::fmpz_abs_series, y::fmpz; check::Bool=true)
   iszero(y) && throw(DivideError())
   z = parent(x)()
   z.prec = x.prec
   ccall((:fmpz_poly_scalar_divexact_fmpz, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Ref{fmpz}),
               z, x, y)
   return z
end

divexact(x::fmpz_abs_series, y::Integer; check::Bool=true) = divexact(x, fmpz(y); check=check)

###############################################################################
#
#   Inversion
#
###############################################################################

function inv(a::fmpz_abs_series)
    iszero(a) && throw(DivideError())
    !isunit(a) && error("Unable to invert power series")
    ainv = parent(a)()
    ainv.prec = a.prec
    ccall((:fmpz_poly_inv_series, libflint), Nothing,
          (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
                  ainv, a, a.prec)
    return ainv
end

###############################################################################
#
#   Square root
#
###############################################################################

function Base.sqrt(a::fmpz_abs_series; check::Bool=true)
    asqrt = parent(a)()
    v = valuation(a)
    asqrt.prec = a.prec - div(v, 2)
    flag = Bool(ccall((:fmpz_poly_sqrt_series, libflint), Cint,
               (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
                  asqrt, a, a.prec))
    check && !flag && error("Not a square")
    return asqrt
end

###############################################################################
#
#   Unsafe functions
#
###############################################################################

function zero!(z::fmpz_abs_series)
   ccall((:fmpz_poly_zero, libflint), Nothing,
                (Ref{fmpz_abs_series},), z)
   z.prec = parent(z).prec_max
   return z
end

function fit!(z::fmpz_abs_series, n::Int)
   ccall((:fmpz_poly_fit_length, libflint), Nothing,
                 (Ref{fmpz_abs_series}, Int), z, n)
   return nothing
end

function setcoeff!(z::fmpz_abs_series, n::Int, x::fmpz)
   ccall((:fmpz_poly_set_coeff_fmpz, libflint), Nothing,
                (Ref{fmpz_abs_series}, Int, Ref{fmpz}),
               z, n, x)
   return z
end

function mul!(z::fmpz_abs_series, a::fmpz_abs_series, b::fmpz_abs_series)
   lena = length(a)
   lenb = length(b)

   aval = valuation(a)
   bval = valuation(b)

   prec = min(a.prec + bval, b.prec + aval)
   prec = min(prec, max_precision(parent(z)))

   lena = min(lena, prec)
   lenb = min(lenb, prec)

   lenz = min(lena + lenb - 1, prec)
   if lenz < 0
      lenz = 0
   end

   z.prec = prec
   ccall((:fmpz_poly_mullow, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
               z, a, b, lenz)
   return z
end

function addeq!(a::fmpz_abs_series, b::fmpz_abs_series)
   lena = length(a)
   lenb = length(b)

   prec = min(a.prec, b.prec)

   lena = min(lena, prec)
   lenb = min(lenb, prec)

   lenz = max(lena, lenb)
   a.prec = prec
   ccall((:fmpz_poly_add_series, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
               a, a, b, lenz)
   return a
end

function add!(c::fmpz_abs_series, a::fmpz_abs_series, b::fmpz_abs_series)
   lena = length(a)
   lenb = length(b)

   prec = min(a.prec, b.prec)

   lena = min(lena, prec)
   lenb = min(lenb, prec)

   lenc = max(lena, lenb)
   c.prec = prec
   ccall((:fmpz_poly_add_series, libflint), Nothing,
                (Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Ref{fmpz_abs_series}, Int),
               c, a, b, lenc)
   return c
end

function set_length!(a::fmpz_abs_series, n::Int)
   ccall((:_fmpz_poly_set_length, libflint), Nothing,
         (Ref{fmpz_abs_series}, Int), a, n)
   return a
end

###############################################################################
#
#   Promotion rules
#
###############################################################################

promote_rule(::Type{fmpz_abs_series}, ::Type{T}) where {T <: Integer} = fmpz_abs_series

promote_rule(::Type{fmpz_abs_series}, ::Type{fmpz}) = fmpz_abs_series

###############################################################################
#
#   Parent object call overload
#
###############################################################################

function (a::FmpzAbsSeriesRing)()
   z = fmpz_abs_series()
   z.prec = a.prec_max
   z.parent = a
   return z
end

function (a::FmpzAbsSeriesRing)(b::Integer)
   if b == 0
      z = fmpz_abs_series()
      z.prec = a.prec_max
   else
      z = fmpz_abs_series([fmpz(b)], 1, a.prec_max)
   end
   z.parent = a
   return z
end

function (a::FmpzAbsSeriesRing)(b::fmpz)
   if iszero(b)
      z = fmpz_abs_series()
      z.prec = a.prec_max
   else
      z = fmpz_abs_series([b], 1, a.prec_max)
   end
   z.parent = a
   return z
end

function (a::FmpzAbsSeriesRing)(b::fmpz_abs_series)
   parent(b) != a && error("Unable to coerce power series")
   return b
end

function (a::FmpzAbsSeriesRing)(b::Vector{fmpz}, len::Int, prec::Int)
   z = fmpz_abs_series(b, len, prec)
   z.parent = a
   return z
end

###############################################################################
#
#   PowerSeriesRing constructor
#
###############################################################################

function PowerSeriesRing(R::FlintIntegerRing, prec::Int, s::Symbol;  model=:capped_relative, cached = true)
   if model == :capped_relative
      parent_obj = FmpzRelSeriesRing(prec, s, cached)
   elseif model == :capped_absolute
      parent_obj = FmpzAbsSeriesRing(prec, s, cached)
   else
      error("Unknown model")
   end

   return parent_obj, gen(parent_obj)
end

function PowerSeriesRing(R::FlintIntegerRing, prec::Int, s::AbstractString; model=:capped_relative, cached = true)
   return PowerSeriesRing(R, prec, Symbol(s); model=model, cached=cached)
end

function AbsSeriesRing(R::FlintIntegerRing, prec::Int)
   return FmpzAbsSeriesRing(prec, :x, false)
end

function RelSeriesRing(R::FlintIntegerRing, prec::Int)
   return FmpzRelSeriesRing(prec, :x, false)
end

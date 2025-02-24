module Rust_primitives.Integers

open FStar.Mul

#set-options "--max_fuel 0 --max_ifuel 1 --z3rlimit 20"

val pow2_values: x:nat -> Lemma
  (let p = pow2 x in
   match x with
   | 0  -> p=1
   | 1  -> p=2
   | 8  -> p=256
   | 16 -> p=65536
   | 31 -> p=2147483648
   | 32 -> p=4294967296
   | 63 -> p=9223372036854775808
   | 64 -> p=18446744073709551616
   | 2 | 3 | 4 | 5 | 6 | 7
   | 9 | 10 | 11 | 12 | 13 | 14 | 15 
   | 17 | 18 | 19 | 20 | 21 | 22 | 23
   | 24 | 25 | 26 | 27 | 28 | 29 | 30
   | 33 | 34 | 35 | 36 | 37 | 38 | 39
   | 40 | 41 | 42 | 43 | 44 | 45 | 46
   | 47 | 48 | 49 | 50 | 51 | 52 | 53
   | 54 | 55 | 56 | 57 | 58 | 59 | 60
   | 61 | 62 | 63 | 65 | 127 | 128 -> p = normalize_term (pow2 x)
   | _ -> True)
  [SMTPat (pow2 x)]

type inttype =
  | I8 | I16 | I32 | I64 | I128 | ISIZE
  | U8 | U16 | U32 | U64 | U128 | USIZE

let unsigned t = match t with
  | U8 | U16 | U32 | U64 | U128 | USIZE -> true
  | I8 | I16 | I32 | I64 | I128 | ISIZE -> false

let signed t = match t with
  | U8 | U16 | U32 | U64 | U128 | USIZE -> false
  | I8 | I16 | I32 | I64 | I128 | ISIZE -> true

type uinttype = t:inttype{unsigned t}

val size_bits:n:nat{n == 32 \/ n == 64}

let bits t = match t with
  | U8 | I8 -> 8 
  | U16 | I16 -> 16
  | U32 | I32 -> 32
  | U64 | I64 -> 64
  | U128 | I128 -> 128 
  | USIZE | ISIZE -> size_bits 

let minint (t:inttype) =
  if unsigned t then 0 else -(pow2 (bits t - 1))

let maxint (t:inttype) =
  if unsigned t then pow2 (bits t) - 1
  else pow2 (bits t - 1) - 1

let max_usize = maxint USIZE
let max_isize = maxint ISIZE

let range (n:int) (t:inttype) : bool =
  minint t <= n && n <= maxint t

let range_t t = x:int{range x t}

type int_t t = | MkInt: range_t t -> int_t t

let u8_inttype = U8
let i8_inttype = I8
let u16_inttype = U16
let i16_inttype = I16
let u32_inttype = U32
let i32_inttype = I32
let u64_inttype = U64
let i64_inttype = I64
let u128_inttype = U128
let i128_inttype = I128
let usize_inttype = USIZE
let isize_inttype = ISIZE

type u8 = int_t U8 
type i8 = int_t I8
type u16 = int_t U16
type i16 = int_t I16
type u32 = int_t U32
type i32 = int_t I32
type u64 = int_t U64
type i64 =  int_t I64
type u128 = int_t U128
type i128 = int_t I128
type usize = int_t USIZE
type isize = int_t ISIZE

[@(strict_on_arguments [0])]
let v (#t:inttype) (x:int_t t) : range_t t = x._0

[@(strict_on_arguments [0])]
let mk_int (#t:inttype) (n:range_t t) : int_t t = MkInt n

let mk_int_v_lemma (#t:inttype) (a:int_t t) : Lemma
  (mk_int #t (v #t a) == a)
  [SMTPat (mk_int #t (v #t a))]
  = ()

let v_mk_int_lemma (#t:inttype) (n:range_t t) : Lemma
  (v #t (mk_int #t n) == n)
  [SMTPat (v #t (mk_int #t n))]
  = ()

let mk_u8 x = mk_int #U8 x
let mk_i8  x = mk_int #I8 x
let mk_u16  x = mk_int #U16 x
let mk_i16  x = mk_int #I16 x
let mk_u32 x = mk_int #U32 x
let mk_i32  x = mk_int #I32 x
let mk_u64 x = mk_int #U64 x
let mk_i64  x = mk_int #I64 x
let mk_u128 x = mk_int #U128 x
let mk_i128  x = mk_int #I128 x
let mk_usize x = mk_int #USIZE x
let mk_isize  x = mk_int #ISIZE x

let sz x = mk_usize x
let isz  x = mk_isize x

let from_uint8 (x:FStar.UInt8.t) : u8  = mk_int (FStar.UInt8.v x)
let from_int8 (x:FStar.Int8.t) : i8  = mk_int (FStar.Int8.v x)
let from_uint16 (x:FStar.UInt16.t) : u16  = mk_int (FStar.UInt16.v x)
let from_int16 (x:FStar.Int16.t) : i16  = mk_int (FStar.Int16.v x)
let from_uint32 (x:FStar.UInt32.t) : u32  = mk_int (FStar.UInt32.v x)
let from_int32 (x:FStar.Int32.t) : i32  = mk_int (FStar.Int32.v x)
let from_uint64 (x:FStar.UInt64.t) : u64  = mk_int (FStar.UInt64.v x)
let from_int64 (x:FStar.Int64.t) : i64  = mk_int (FStar.Int64.v x)
let from_uint128 (x:FStar.UInt128.t) : u128  = mk_int (FStar.UInt128.v x)
let from_int128 (x:FStar.Int128.t) : i128  = mk_int (FStar.Int128.v x)
let from_usize (x:FStar.UInt32.t) : usize  = mk_int (FStar.UInt32.v x)
let from_isize (x:FStar.Int32.t) : isize  = mk_int (FStar.Int32.v x)

let to_uint8 (x:u8) : FStar.UInt8.t = FStar.UInt8.uint_to_t (v x)
let to_int8 (x:i8) : FStar.Int8.t  = FStar.Int8.int_to_t (v x)
let to_uint16 (x:u16) : FStar.UInt16.t  = FStar.UInt16.uint_to_t (v x)
let to_int16 (x:i16) : FStar.Int16.t  = FStar.Int16.int_to_t (v x)
let to_uint32 (x:u32) : FStar.UInt32.t  = FStar.UInt32.uint_to_t (v x)
let to_int32 (x:i32) : FStar.Int32.t  = FStar.Int32.int_to_t (v x)
let to_uint64 (x:u64) : FStar.UInt64.t  = FStar.UInt64.uint_to_t (v x)
let to_int64 (x:i64) : FStar.Int64.t  = FStar.Int64.int_to_t (v x)
let to_uint128 (x:u128) : FStar.UInt128.t  = FStar.UInt128.uint_to_t (v x)
let to_int128 (x:i128) : FStar.Int128.t  = FStar.Int128.int_to_t (v x)

let modulus (t:inttype) = pow2 (bits t)

(* Wrap-around modulo: wraps into [-p/2; p/2[ *)
let op_At_Percent (v:int) (p:int{p>0 /\ p%2=0}) : Tot int =
  let m = v % p in if m >= p/2 then m - p else m

let op_At_Percent_Dot x t : range_t t =
  if unsigned t then x % modulus t
  else x @% modulus t

let cast (#t:inttype) (#t':inttype)
    (u1:int_t t{range (v u1) t'}) =
    mk_int #t' (v u1)
let cast_mod (#t:inttype) (#t':inttype)
    (u1:int_t t) = 
    mk_int #t' (v u1 @%. t')

/// Arithmetic operations
/// 

let add_mod (#t:inttype) (a:int_t t) (b:int_t t) =
    mk_int #t ((v a + v b) @%. t)

let add (#t:inttype) (a:int_t t)
        (b:int_t t{range (v a + v b) t}) =
    mk_int #t (v a + v b)

let incr (#t:inttype) (a:int_t t{v a < maxint t}) =
    mk_int #t (v a + 1)

let mul_mod (#t:inttype) (a:int_t t)
            (b:int_t t) =
            mk_int #t (v a * v b @%. t)

let mul (#t:inttype) (a:int_t t)
        (b:int_t t{range (v a * v b) t}) =
        mk_int #t (v a * v b)

let sub_mod (#t:inttype) (a:int_t t) (b:int_t t) =
    mk_int #t ((v a - v b) @%. t)

let sub (#t:inttype) (a:int_t t)
        (b:int_t t{range (v a - v b) t}) =
    mk_int #t (v a - v b)

let decr (#t:inttype) (a:int_t t{minint t < v a}) =
    mk_int #t (v a - 1)

let div (#t:inttype) (a:int_t t) (b:int_t t{v b <> 0 /\ (unsigned t \/ range (v a / v b) t)}) =
  assert (unsigned t \/ range (v a / v b) t);
  mk_int #t (v a / v b)
  
let mod (#t:inttype) (a:int_t t) (b:int_t t{v b <> 0}) =
  mk_int #t (v a % v b)


/// Comparison Operators
/// 
let eq (#t:inttype) (a:int_t t) (b:int_t t) = v a = v b
let ne (#t:inttype) (a:int_t t) (b:int_t t) = v b <> v b
let lt (#t:inttype) (a:int_t t) (b:int_t t) = v a < v b
let lte (#t:inttype) (a:int_t t) (b:int_t t) = v a <= v b
let gt (#t:inttype) (a:int_t t) (b:int_t t) = v a > v b
let gte (#t:inttype) (a:int_t t) (b:int_t t) = v a >= v b


/// Bitwise Operations

/// Todo: define bitvector-based normalizable definitions
///       for all these operations

let ones (#t:inttype) : n:int_t t =
  if unsigned t then mk_int #t (pow2 (bits t) - 1)
  else mk_int #t (-1)

let zero (#t:inttype) : n:int_t t =
  mk_int #t 0

val lognot: #t:inttype -> int_t t -> int_t t
val lognot_lemma: #t:inttype -> a:int_t t -> Lemma
  (lognot #t zero == ones /\
   lognot #t ones == zero /\
   lognot (lognot a) == a /\
   (signed t ==> v (lognot a) = -1 - v a) /\
   (unsigned t ==> v (lognot a)  = pow2 (bits t) - 1 - v a)
   )

val logxor: #t:inttype
  -> int_t t
  -> int_t t
  -> int_t t
 
val logxor_lemma: #t:inttype -> a:int_t t -> b:int_t t -> Lemma
  (a `logxor` a == zero /\
   (a `logxor` b == zero ==> b == a) /\
   a `logxor` (a `logxor` b) == b /\
   a `logxor` (b `logxor` a) == b /\
   zero `logxor` a == a /\
   a `logxor` zero == a /\
   ones `logxor` a == lognot a /\
   a `logxor` ones == lognot a)
    
val logand: #t:inttype
  -> int_t t
  -> int_t t
  -> int_t t

val logand_lemma: #t:inttype -> a:int_t t -> b:int_t t ->
  Lemma (logand a zero == zero /\
         logand zero a == zero /\
         logand a ones == a /\
         logand ones a == a /\
         (a == b ==> logand a b == a) /\
         (b == lognot a ==> logand a b == zero) /\
         (v a >= 0 ==> (v (logand a b) >= 0) /\ (v (logand a b) <= v a)) /\
         (v b >= 0 ==> (v (logand a b) >= 0) /\ (v (logand a b) <= v b)))

val logand_mask_lemma: #t:inttype
  -> a:int_t t
  -> m:nat{m < bits t} ->
  Lemma (pow2 m < maxint t /\
         logand a (sub #t (mk_int #t (pow2 m)) (mk_int #t 1)) ==
         mk_int (v a % pow2 m))
  [SMTPat (logand #t a (sub #t (mk_int #t (pow2 m)) (mk_int #t 1)))]

val logor: #t:inttype
  -> int_t t
  -> int_t t
  -> int_t t

val logor_lemma: #t:inttype -> a:int_t t -> b:int_t t ->
  Lemma (logor a zero == a /\
         logor a ones == ones /\
         logor zero a == a /\
         logor ones a == ones /\
         ((v a >= 0 /\ v b >= 0) ==> (v (logor a b) >= v a /\ v (logor a b) >= v b)))

unfold type shiftval (t:inttype) (t':inttype) =
     b:int_t t'{v b >= 0 /\ v b < bits t}
unfold type rotval (t:inttype) (t':inttype) =
     b:int_t t'{v b > 0 /\ v b < bits t}

val shift_right (#t:inttype) (#t':inttype)
    (a:int_t t) (b:shiftval t t') : int_t t 

val shift_right_lemma (#t:inttype) (#t':inttype)
    (a:int_t t) (b:shiftval t t'):
    Lemma (v (shift_right #t #t' a b) == (v a / pow2 (v b)))
          [SMTPat (shift_right #t #t' a b)]
    
val shift_left (#t:inttype) (#t':inttype)
    (a:int_t t) (b:shiftval t t') : int_t t

val shift_left_positive_lemma (#t:inttype) (#t':inttype)
    (a:int_t t) (b:shiftval t t'):
    Lemma (requires (unsigned t \/ v a >= 0))
          (ensures ((v (shift_left #t #t' a b) == (v a * pow2 (v b)) @%. t)))
          [SMTPat (shift_left #t #t' a b)]


val rotate_right: #t:inttype{unsigned t} -> #t':inttype
  -> a:int_t t
  -> rotval t t'
  -> int_t t

val rotate_left: #t:inttype{unsigned t} -> #t':inttype
  -> a:int_t t
  -> rotval t t'
  -> int_t t

let shift_right_i (#t:inttype) (#t':inttype) (s:shiftval t t') (u:int_t t) : int_t t = shift_right u s

let shift_left_i (#t:inttype) (#t':inttype) (s:shiftval t t') (u:int_t t{v u >= 0}) : int_t t = shift_left u s

let rotate_right_i (#t:inttype{unsigned t}) (#t':inttype) (s:rotval t t') (u:int_t t) : int_t t = rotate_right u s

let rotate_left_i (#t:inttype{unsigned t}) (#t':inttype) (s:rotval t t') (u:int_t t) : int_t t = rotate_left u s

let abs_int (#t:inttype) (a:int_t t{minint t < v a}) =
    mk_int #t (abs (v a))

let neg (#t:inttype{signed t}) (a:int_t t{range (0 - v a) t}) =
    mk_int #t (0 - (v a))

val neg_equiv_lemma: #t:inttype{signed t /\ not (I128? t)}
  -> a:int_t t{range (0 - v a) t}
  -> Lemma (neg a == sub #t (mk_int 0) a /\
          (lognot a = sub (neg a) (mk_int 1)))


///
/// Operators available for all machine integers
///

// Strict: with precondition
unfold
let (+!) #t = add #t

// Wrapping: no precondition
unfold
let (+.) #t = add_mod #t

unfold
let ( *! ) #t = mul #t

unfold
let ( *. ) #t = mul_mod #t

unfold
let ( -! ) #t = sub #t

unfold
let ( -. ) #t = sub_mod #t

unfold
let ( >>! ) #t #t' = shift_right #t #t'

unfold
let ( <<! ) #t #t' = shift_left #t #t'

unfold
let ( >>>. ) #t #t' = rotate_right #t #t'

unfold
let ( <<<. ) #t #t' = rotate_left #t #t'

unfold
let ( ^. ) #t = logxor #t

unfold
let ( |. ) #t = logor #t

unfold
let ( &. ) #t = logand #t

unfold
let ( ~. ) #t = lognot #t

unfold
let (/!) #t = div #t

unfold
let (%!) #t = mod #t

unfold
let (=.) = (=)

unfold
let (<>.) = (<>)

unfold
let (<.) #t = lt #t

unfold
let (<=.) #t = lte #t

unfold
let (>.) #t = gt #t

unfold
let (>=.) #t = gte #t

type bit = n: nat {n < 2}

/// Mathematical `get_bit` definition on `nat`s
let get_bit_nat (x: nat) (nth: nat): bit
  = (x / pow2 nth) % 2

/// `get_bit` definition for machine integer of any size and signedness
[@"opaque_to_smt"]
let get_bit (#n: inttype) (x: int_t n) (nth: usize {v nth < bits n}): bit
  = if v x >= 0 then get_bit_nat (v x) (v nth)
               else // two's complement
                    get_bit_nat (pow2 (bits n) + v x) (v nth)

unfold let bit_and (x y: bit): bit = match x, y with | (1, 1) -> 1 | _ -> 0
unfold let bit_or  (x y: bit): bit = (x + y) % 2

/// Bit-wise semantics for `&.`
val get_bit_and #t (x y: int_t t) (i: usize {v i < bits t})
  : Lemma (get_bit (x &. y) i == get_bit x i `bit_and` get_bit y i)
          [SMTPat (get_bit (x &. y) i)]

/// Bit-wise semantics for `|.`
val get_bit_or #t (x y: int_t t) (i: usize {v i < bits t})
  : Lemma (get_bit (x |. y) i == get_bit x i `bit_or` get_bit y i)
          [SMTPat (get_bit (x |. y) i)]

/// Bit-wise semantics for `<<!`
val get_bit_shl #t #u (x: int_t t) (y: int_t u) (i: usize {v i < bits t})
  : Lemma (requires v y >= 0 /\ v y < bits t)
          (ensures get_bit (x <<! y) i 
                == (if v i < v y then 0 else get_bit x (mk_int (v i - v y))))
    [SMTPat (get_bit (x <<! y) i)]

/// Bit-wise semantics for `>>!`
val get_bit_shr #t #u (x: int_t t) (y: int_t u) (i: usize {v i < bits t})
  : Lemma (requires v y >= 0 /\ v y < bits t)
          (ensures get_bit (x >>! y) i 
                == (if v i < bits t - v y
                    then get_bit x (mk_int (v i + v y))
                    else if signed t
                         then get_bit x (mk_int (bits t - 1))
                         else 0))
    [SMTPat (get_bit (x >>! y) i)]

/// Bit-wise semantics of integer casts
val get_bit_cast #t #u
  (x: int_t t) (nth: usize)
  : Lemma (requires v nth < bits u /\ v nth < bits t)
          (ensures get_bit (cast_mod #t #u x) nth == get_bit x nth)
          [SMTPat (get_bit (cast_mod #t #u x) nth)]

val get_bit_cast_extend #t #u
  (x: int_t t) (nth: usize)
  : Lemma (requires bits t < bits u /\ v nth >= bits t /\ v nth < bits u)
          (ensures get_bit (cast_mod #t #u x) nth == 0)
          [SMTPat (get_bit (cast_mod #t #u x) nth)]


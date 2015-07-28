module yabe;

import std.algorithm;
import std.array;
import std.exception;
import std.range;
import std.traits;
import std.variant;
import std.c.stdlib;

enum ubyte Int16 = 0b11000001;
enum ubyte Int32 = 0b11000010;
enum ubyte Int64 = 0b11000011;

enum ubyte Flt0  = 0b11000100;
enum ubyte Flt16 = 0b11000101;
enum ubyte Flt32 = 0b11000110;
enum ubyte Flt64 = 0b11000111;

enum ubyte False = 0b11001000;
enum ubyte True  = 0b11001001;

enum SHORT_STRING_LENGTH = 64;
enum ubyte Str6  = 0b10000000;
enum ubyte Str16 = 0b11001101;
enum ubyte Str32 = 0b11001110;
enum ubyte Str64 = 0b11001111;

enum ubyte Null  = 0b11000000;

enum ubyte ShortArray = 0b11010000;
enum ubyte Array      = 0b11010111;
enum ubyte EndS       = 0b11001011;

enum ubyte ShortObject = 0b11011000;
enum ubyte LongObject  = 0b11011111;

/**
 * Encode an integer.
 *
 * This function returns an input range of unsigned bytes that 
 * contains the encoded data.
 */
auto encode(long l)
{
    /**
     * An InputRange that represents the encoded integral value.
     */
    struct IntegralRange
    {
        ubyte[1 + long.sizeof] buffer;
        ubyte length;
        ubyte index;

        bool  empty() const { return index == length; }
        ubyte front() const { return buffer[index]; }
        void  popFront() { ++index; }

    }

    IntegralRange result;

    if (-32 <= l && l < 128)
    {
        result.buffer[0] = l & 0xFF;
        result.length = 1;
    }
    else if (short.min <= l && l <= short.max)
    {
        result.buffer[0] = Int16;
        result.buffer[1] = l & 0xFF;
        result.buffer[2] = (l >>> 8) & 0xFF;
        result.length = 3;
    }
    else if (int.min <= l && l <= int.max)
    {
        result.buffer[0] = Int32;
        result.buffer[1] = l & 0xFF;
        result.buffer[2] = (l >>> 8)  & 0xFF;
        result.buffer[3] = (l >>> 16) & 0xFF;
        result.buffer[4] = (l >>> 24) & 0xFF;
        result.length = 5;
    }
    else
    {
        result.buffer[0] = Int64;
        result.buffer[1] = l & 0xFF;
        result.buffer[2] = (l >>> 8)  & 0xFF;
        result.buffer[3] = (l >>> 16) & 0xFF;
        result.buffer[4] = (l >>> 24) & 0xFF;
        result.buffer[5] = (l >>> 32) & 0xFF;
        result.buffer[6] = (l >>> 40) & 0xFF;
        result.buffer[7] = (l >>> 48) & 0xFF;
        result.buffer[8] = (l >>> 56) & 0xFF;
        result.length = 9;
    }

    return result;
}


/**
 * Encode a double precision floating point value.
 */
auto encode(double val)
{
    /**
     * An InputRange that represents our encoded value.
     */
    struct FloatRange
    {
        ubyte[1 + double.sizeof] buffer; 
        ubyte length;
        ubyte index;

        bool empty() const { return index == length; }
        ubyte front() const { return buffer[index] ; }
        void popFront() { ++index; }
    }

    FloatRange result;
    
    double* vPtr = &val;
    long dr = *(cast(long*) vPtr);

    // If value is zero
    if ((dr & 0x7FFFFFFFFFFFFFFFUL) == 0)
    {
        result.buffer[0] = Flt0;
        result.length = 1;
    }
    else
    {
        enum EXPONENT_BITS = 0x7FFUL << 52;
        ulong de = dr & EXPONENT_BITS;
        ushort he = cast(ushort)((de >> 52) - 1023);

        // if value is infinity or NaN, write it as flt16
        if (de == EXPONENT_BITS)
        {
            ushort hr;
            if( dr & 0xFFFFFFFFFFFFFL )
                hr = 0x7D00; // normalized NaN
            else if( dr < 0 )
                hr = 0xFC00; // - infinity
            else
                hr = 0x7C00; // + infinity

            result.buffer[0] = Flt16;
            result.buffer[1] = hr & 0xFF;
            result.buffer[2] = (hr >> 8) & 0xFF;
            result.length = 3;
        }        
        // if value fits in flt16, write it as flt16
        else if (he > -14 && he <= 15 && (dr & 0x3FFFFFFFFFFL) == 0)
        {
            ushort hr = cast(ushort)( (he + 15) << 10);
            if (dr < 0)
                hr |= 0x8000;

            hr |= (cast(ushort)(dr >>(52-10)) &0x3FF);

            result.buffer[0] = Flt16;
            result.buffer[1] = hr & 0xFF;
            result.buffer[2] = (hr >> 8) & 0xFF;
            result.length = 3;
        }
        // if value fits in flt32, write it as flt32
        else if (he >=-126 && he <= 127 && (dr & 0x1FFFFFFFL) == 0)
        {
            // initialize output value v with exponent bits
            uint fr = cast(uint)(he + 127) << 23;
            if (dr < 0)
                fr |= 0x8000_0000;
            fr |= (cast(uint)(dr>>29))&0x7FFFFF;

            result.buffer[0] = Flt32;
            result.buffer[1] = fr & 0xFF;
            result.buffer[2] = (fr >> 8) & 0xFF;
            result.buffer[3] = (fr >> 16) & 0xFF;
            result.buffer[4] = (fr >> 24) & 0xFF;
            result.length = 5;
        }
        else
        {
            result.buffer[0] = Flt64;
            result.buffer[1] = dr & 0xFF;
            result.buffer[2] = (dr >>> 8) & 0xFF;
            result.buffer[3] = (dr >>> 16) & 0xFF;
            result.buffer[4] = (dr >>> 24) & 0xFF;
            result.buffer[5] = (dr >>> 32) & 0xFF;
            result.buffer[6] = (dr >>> 40) & 0xFF;
            result.buffer[7] = (dr >>> 48) & 0xFF;
            result.buffer[8] = (dr >>> 56) & 0xFF;
            result.length = 9;
        }
    }

    return result;
}

auto encode(bool val)
{
    struct BooleanRange
    {
        ubyte[1] buffer;
        ubyte index;

        size_t length() const { return 1; }
        bool empty() const { return index == length; }
        ubyte front() const { return buffer[index]; }
        void popFront() { ++index; }
    }

    BooleanRange result;
    result.buffer[0] = val ? True : False; 
    return result;
}

/**
 * Encode a string.
 */
auto encode(string val)
{
    struct StringPrefixRange
    {
        ubyte[9] buffer;
        ubyte index;
        ubyte length;

        bool  empty()    const { return index == length; }
        ubyte front()    const { return buffer[index]; }
        void  popFront() { ++index; }
    }

    StringPrefixRange result;

    if (val.length < SHORT_STRING_LENGTH)
    {
        result.buffer[0] = Str6 | cast(ubyte)(val.length);
        result.length = 1;
    }
    else if (val.length < ushort.max)
    {
        result.buffer[0] = Str16;
        result.buffer[1] = val.length & 0xFF;
        result.buffer[2] = (val.length >> 8) & 0xFF;
        result.length = 3;
    }
    else if (val.length < uint.max)
    {
        // for 32 bit machines
        static if (size_t.sizeof == uint.sizeof)
        {
            enforce(val.length < size_t.max - 5);
        }

        result.buffer[0] = Str32;
        result.buffer[1] = val.length & 0xFF;
        result.buffer[2] = (val.length >> 8)  & 0xFF;
        result.buffer[3] = (val.length >> 16) & 0xFF;
        result.buffer[4] = (val.length >> 24) & 0xFF;
        result.length = 5;
    }
    else if (val.length < ulong.max)
    {
        enforce(size_t.sizeof == ulong.sizeof);
        enforce(val.length < size_t.max - 9);

        result.buffer[0] = Str64;
        foreach (i; 0..8)
        {
            result.buffer[1+i] = (val.length >> (i * 8)) & 0xFF;
        }
        result.length = 9;
    }

    return chain(result, cast(ubyte[])val);
}

unittest
{
    auto s1 = "BONJOUR";
    ubyte[] e1 = [Str6 | 7, 66, 79, 78, 74, 79, 85, 82];

    assert (equal(e1, encode(s1)));
}

/**
 * Encode null value 
 */
auto encodeNull()
{
    ubyte[1] nullValue;
    nullValue[0] = Null;

    return nullValue;
}

/**
 * Encode an InputRange as a Yabe array.
 *
 */
auto encode(R)(R elems) 
        if (isInputRange!R && !isSomeChar!(ElementType!R))
{
    auto buffer = appender!(ubyte[])();

    buffer.put(Array);
    size_t count; // counts array elements

    foreach (elem; elems)
    {
        buffer.put(encode(elem));
        count++;
    }

    if (count > 6)
    {
        buffer.put(EndS);
    }
    else
    {
        buffer.data[0] = cast(ubyte)(ShortArray | elems.length);
    }
    
    return buffer.data;
}

unittest
{
    int[] a1 = [6, 42, 4095];
    ubyte[] e1 = [ShortArray | 3, 6, 42, Int16, 0xFF, 0x0F];
    assert (equal(e1, encode(a1)));

    int[] a2 = [1, 2, 3, 4, 5, 6, 7];
    ubyte[] e2 = [Array, 1, 2, 3, 4, 5, 6, 7, EndS];
    assert (equal(e2, encode(a2)));

}

/**
 * Encode any user data type that defines yabeSerialize() method that returns 
 * an InputRange.
 *
 * This function enables the user to customize the way its objects are
 * encoded, skipping transients fields, for instance.
 */
auto encode(T)(T t)
        if (hasMember!(T, "yabeSerialize")
            && isInputRange!(ReturnType!(T.yabeSerialize)))
{
    return t.yabeSerialize();
}

unittest
{
    struct S
    {
        int a = 4;
        int b = 5;

        auto yabeSerialize()
        {
            return chain(cast(ubyte[])[ShortObject | 2],
                         encode("a"),
                         encode(a),
                         encode("b"),
                         encode(b));
        }
    }

    S s;
    auto r = encode(s);
    auto e = [218, 129, 97, 4, 129, 98, 5];

    assert (equal(r, e));
}

/**
 * Encodes an aggregate type using compile-time reflexion
 * 
 * This function iterates over each public data member of the type (in 
 * declaration order and calls encode() on it. Useful for encoding 
 * POD types without needing to define a yabeSerialize() function.
 */
auto encode(T)(T t)
        if (isAggregateType!T 
            && !hasMember!(T, "yabeSerialize"))
{
    auto buffer = appender!(ubyte[])();

    size_t memberCount;

    buffer.put(ShortObject);
    foreach (member; __traits(allMembers, T))
    {
        static if (__traits(getProtection, __traits(getMember, t, member)) == "public"
                && (isNumeric!(typeof(__traits(getMember, t, member)))
                    || isNarrowString!(typeof(__traits(getMember, t, member)))
                    || isBoolean!(typeof(__traits(getMember, t, member)))
                    || isArray!(typeof(__traits(getMember, t, member)))
                    || isAggregateType!(typeof(__traits(getMember, t, member)))))
        {
            ++memberCount;

            auto m = encode(member);

            buffer.put(m);
            buffer.put(encode(__traits(getMember, t, member)));
        }
    }

    if (memberCount < 0b111)
    {
        buffer.data[0] |= memberCount;
    }
    else
    {
        buffer.data[0] |= 0b111;
        buffer.put(EndS);
    }

    return buffer.data;
}

unittest
{
    import std.algorithm;

    struct S
    {
        int a = 4;
        bool b = true;
        double c = 3.14159;
    }

    S s;
    auto r = encode(s);


    auto e = [219, 129, 97, 4, 129, 98, 201, 129, 99, 
              199, 110, 134, 27, 240, 249, 33, 9, 64];

    assert (equal(r, e));
}

class YabeDecodingException : Exception
{
    public this(string msg)
    {
        super(msg);
    }
}

class EorException : YabeDecodingException
{
    public this()
    {
        super("End of range while decoding.");
    }
}

private void enforceNotEmpty(R)(R r)
        if (isInputRange!R)
{
    if (r.empty)
        throw new EorException;
}

Variant decode(R)(ref R r)
        if (isInputRange!R && is(ElementType!R == ubyte))
in 
{
    assert (r.empty == false);
}
body
{
    Variant v;

    switch (r.front)
    {
    case 0: .. case 127:
    case 224: .. case 255:
        v = decodeTinyInt(r);
        break;

    case Int16:
        v = decodeInt!2(r);
        break;

    case Int32:
        v = decodeInt!4(r);
        break;

    case Int64:
        v = decodeInt!8(r);
        break;

    case Flt0:
        v = decodeFloat0(r);
        break;

    case Flt16:
        v = decodeFloat16(r);
        break;

    case Flt32:
        v = decodeFloat32(r);
        break;

    case Flt64:
        v = decodeFloat64(r);
        break;

    case 0x80: .. case 0xBF: // short string 
    case Str16:
    case Str32:
    case Str64:
        v = decodeString(r);
        break;

    case True:
    case False:
        v = decodeBoolean(r);
        break;

    case 0xD0: .. case 0xD7: // arrays
        v = decodeArray(r);
        break;

    case 0xD8: .. case 0xDF: // objects
        v = decodeObject(r);
        break;
    
    case Null:
        v = decodeNull(r);
    break;
    
    default:
        throw new YabeDecodingException("Unknow object type");
    }

    return v;
}

/**
 * Decode any integer between -32 and 127 included.
 */
long decodeTinyInt(R)(ref R r) 
    if (isInputRange!R
        && is(ElementType!R == ubyte))
in 
{
    assert (r.empty == false);
    assert (r.front >= 224 || r.front < 128);
}
body
{
    long result = r.front;
    r.popFront();

    return result;
}

/**
 * Decode any integer value between Int16 and Int64.
 * 
 * This function takes the number of bytes the integer is supposed to 
 * be stored as, and the input range from which to extract data.
 * 
 * Returns the decoded integral value
 */
long decodeInt(size_t IntSize, R)(ref R r) 
        if (isInputRange!R
            && is(ElementType!R == ubyte)
            && IntSize >= short.sizeof
            && IntSize <= long.sizeof)
in
{
    assert (r.empty == false);
    static if (IntSize == short.sizeof)
        assert (r.front == Int16);
    else static if (IntSize == int.sizeof)
        assert (r.front == Int32);
    else static if (IntSize == long.sizeof)
        assert (r.front == Int64);
    else
        assert (0);
}
body
{
    long result;
    r.popFront();

    foreach (i; 0..IntSize)
    {
        enforceNotEmpty(r);
        result |= (r.front << (i * 8));
        r.popFront();
    }

    return result;
}

/**
 * Decode a zero floating point value.
 */
double decodeFloat0(R)(ref R r)
        if (isInputRange!R && is(ElementType!R == ubyte))
in
{
    assert (r.empty == false);
    assert (r.front == Flt0);
}
body
{
    r.popFront();
    return 0;
}

/**
 * Decode a floating point value encoded as Flt16.
 */
double decodeFloat16(R)(ref R r)
        if (isInputRange!R && is(ElementType!R == ubyte))
in
{
    assert (r.empty == false);
    assert (r.front == Flt16);
}
body
{
    double result;
    ushort hr;
    r.popFront();

    foreach (i; 0..ushort.sizeof)
    {
        enforceNotEmpty(r);
        hr |= (r.front << (i * 8));
        r.popFront();
    }

    // get exponent bits of half float
    ushort he = hr & 0x7C00;
    ulong dr;

    if (he == 0x7C00)
    {
        if (hr & 0x3FF)
            dr = 0x7FF4000000000000L; // normalized Nan
        else if (hr & 0x8000)
            dr = 0xFFF0000000000000L; // - inf
        else 
            dr = 0x7FF0000000000000L; // + inf
    }
    else
    {
        dr = (he >> 10)-15+1023;          // set value exponent bits
        dr <<= 52;
        if( hr & 0x8000 )
            dr |= (1L<<63); // set value sign bit
        dr |= (cast(ulong)(hr & 0x3FF)) << (52-10);     // set value mantissa
    }
    // get float value as ulong value
    ulong* rPtr = &dr;
    double value = *(cast(double*)(rPtr));              // assign value as double float
    return value;
}

unittest
{
    foreach (d; [4.5, -4.5] )
    {
        auto r = encode(d);
        double d2 = decodeFloat16(r);
        assert (d == d2);
    }
}

/**
 * Decode a floating point value encoded as Flt32.
 */
double decodeFloat32(R)(ref R r)
        if (isInputRange!R && is(ElementType!R == ubyte))
in
{
    assert (r.empty == false);
    assert (r.front == Flt32);
}
body
{
    double result;
    uint fr;
    r.popFront();

    foreach (i; 0..float.sizeof)
    {
        enforceNotEmpty(r);
        fr |= (r.front << (i * 8));
        r.popFront();
    }

    result = *(cast(float*)&fr);
    return result;
}

unittest
{
    float f = 3.14f;
    auto r = encode(f);
    float f2 = decodeFloat32(r);
    assert (f == f2);
}


/**
 * Decode a floating point value encoded as Flt64.
 */
double decodeFloat64(R)(ref R r)
        if (isInputRange!R && is(ElementType!R == ubyte))
in 
{
    assert (r.empty == false);
    assert (r.front == Flt64);
}
body
{
    double result;
    ulong dr;
    r.popFront();

    foreach (i; 0..double.sizeof)
    {
        enforceNotEmpty(r);
        dr |= (cast(ulong)(r.front) << (i * 8));
        r.popFront();
    }

    result = *(cast(double*)&dr);
    return result;
}

unittest 
{
    double d = 3.14159265359;
    auto r = encode(d);
    double d2 = decodeFloat64(r);
    assert (d == d2);
}

string decodeString(R)(ref R r)
        if (isInputRange!R && is(ElementType!R == ubyte))
in
{
    assert (r.empty == false);
    assert ((r.front == Str16)
            || (r.front == Str32)
            || (r.front == Str64)
            || ((r.front & 0xC0) == Str6));
}
body
{
    // for 32bit architectures
    static if ((size_t.sizeof == uint.sizeof))
    {
        if (r.front == Str64)
        {
            throw new YabeDecodingException("Not enough memory to hold decoded object.");
        }
    }

    // get string length 
    size_t length;
    if ((r.front & 0xC0) == Str6)
    {
        length = r.front & 0x3F;
        r.popFront();
    }
    else
    {
        size_t sizeBytes;
        if (r.front == Str16)
            sizeBytes = 2;
        else if (r.front == Str32)
            sizeBytes = 4;
        else if (r.front == Str64)
            sizeBytes = 8;

        r.popFront();

        foreach (i; 0 .. sizeBytes)
        {
            enforceNotEmpty(r);
            length = length | (cast(size_t)(r.front) << (i * 8));
            r.popFront();
        }
    }

    // get string 
    return cast(string)r.takeExactly(length).array;
}

unittest 
{
    auto s1 = "Bonjour, ceci est un texte suffisamment long pour dépasser les 64 caractères";
    auto r1 = encode(s1);
    auto s2 = decodeString(r1);
    assert (s1 == s2);
}

bool decodeBoolean(R)(ref R r)
        if (isInputRange!R && is(ElementType!R == ubyte))
in
{
    assert (r.empty == false);
    assert (r.front == True || r.front == False);
}
body
{
    bool value = r.front == True ? true : false;
    r.popFront();

    return value;
}

/**
 * Decode an array.
 */
Variant[] decodeArray(R)(ref R r)
        if (isInputRange!R && is(ElementType!R == ubyte))
in
{
    assert (r.empty == false);
    assert (r.front == Array || (r.front & 0xF8) == ShortArray);
}
body
{
    auto buffer = appender!(Variant[])();
    
    if ((r.front & 0xF8) == ShortArray)
    {
        size_t size = r.front & 7;
        r.popFront();

        foreach (i; 0 .. size)
        {
            enforceNotEmpty(r);
            Variant v = decode(r);
            buffer.put(v);
        }
    }
    else
    {
        r.popFront();

        while (r.front != EndS)
        {
            enforceNotEmpty(r);
            Variant v = decode(r);
            buffer.put(v);
        }

        r.popFront();
    }

    return buffer.data;
}

unittest 
{
    long[] a1 = [1, 2, 3];
    auto r = encode(a1);
    Variant[] a2 = decodeArray(r);
    long[3] a3;

    foreach (i; 0..3)
    {
        a3[i] = a2[i].get!long();
    }

    assert (equal(a1[], a3[]));
}

/**
 * Decode an object
 */
Variant[string] decodeObject(R)(R r)
        if (isInputRange!R && is(ElementType!R == ubyte))
in 
{
    assert (r.empty == false);
    assert (r.front == LongObject || r.front == ShortObject);
}
body
{
    Variant[string] result;
    
    if ((r.front & 0xF8) == ShortObject)
    {
        size_t length = r.front & 7;
        r.popFront();

        foreach (i; 0 .. length)
        {
            enforceNotEmpty(r);
            enforce(r.front == Str16 ||r.front == Str32 || r.front == Str64 
                    || ((r.front & 0xC0) == Str6));
            auto key = decodeString(r);
            enforceNotEmpty(r);
            Variant value = decode(r);

            result[key] = value;
        }
    }
    else
    {
        r.popFront();

        while (r.front != EndS)
        {
            enforceNotEmpty(r);
            enforce(r.front == Str16 ||r.front == Str32 || r.front == Str64 
                    || ((r.front & 0xC0) == Str6));
            auto key = decodeString(r);
            enforceNotEmpty(r);
            Variant value = decode(r);
            result[key] = value;
        }
    }

    return result;
}

/**
 * Decode a null value.
 */
Variant decodeNull(R)(R r)
        if (isInputRange!R && is(ElementType!R == ubyte))
in
{
    assert (r.empty == false);
    assert (r.front == Null);
}
body
{
    r.popFront();
    Variant v;
    return v;
}

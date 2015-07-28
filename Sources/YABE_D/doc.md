# YABE D documentation 

## Encoding data 

### Primitive types

All the encoding methods take the value to encode as an argument and return 
an input range of unsigned bytes that contains a view to the encoded data.

        auto encode(long value);
        auto encode(double value);
        auto encode(bool value);
        auto encode(string value);

The returned value is an input range, which integrates pretty well with the 
Phobos library. 

### Arrays, null and user defined types

 * To encode the special null value, use the following: 

        auto encodeNull();


 * To encode any input range as a YABE array, use the following :

        auto encode(R)(R range);

Any container or standard library facility that presents an input range interface
can be encoded as a Yabe array this way.


 * To encode a struct or class object, you have two options:
  * You can create a public _yabeSerialize()_ method that returns an input range of 
    unsigned bytes. This method gives you maximum flexibility as you can customize
    the way your object is encoded. 

        
        struct S
        {
            int a = 4;
            int b = 5;

            auto yabeSerialize()
            {
                return chain( cast(ubyte[]) [ShortObject | 2], // 2 fields
                              encode("a"),                     // member name
                              encode(a),                       // member value
                              encode("b"),                     // member name
                              encode(b));                      // member value
            }
        }

        S s;
        auto range = encode(s); // calls s.yabeSerialize()

   * If you don't provide a _yabeSerialize()_ method, yabe.d will use compile-time
     instrospection to encode all the public data fields that can be be represented 
     in YABE : (long, double, bool, string, array and object).


        struct S2
        {
            int a = 42;
            bool b = true;
            double c = 3.14159;
        }

        S2 s2;
        auto range2 = encode(s2); // use compile-time introspection


## Decoding data 

As YABE type-system is dynamic (arrays can contain any type of data), the decoding 
function takes an input range of bytes by reference and return a std.variant.Variant.

        Variant decode(R)(ref R range);

This Variant can be of the following types:

 * long \(for any integer type\)
 * double \(for any floating point type\)
 * bool
 * string
 * Variant\[\] \(for arrays\)
 * empty Variant \(for null\)
 * Variant\[string\] \(for objects\). 

        
        Variant v = decode(range);
        try
        {
            long l = v.get!long();
            // ...
        }
        catch (VariantException e)
        {
            writeln("Expected a long value");
        }

See std.variant documentation for more help.

module assign;

import std.meta;
import std.traits;
import std.typecons;

template isProp(T)
{
    enum isProp = is(Unqual!T : Prop!(Name, U), string Name, U);
}

unittest
{
    alias TProp = Prop!("text", string);
    static assert(isProp!TProp);
    static assert(isProp!(const(TProp)));
    static assert(isProp!(immutable(TProp)));
    static assert(isProp!(inout(TProp)));
    static assert(isProp!(shared(TProp)));
}

template isPropTuple(T)
{
    static if (is(Unqual!T : Tuple!U, U...))
    {
        enum isPropTuple = allSatisfy!(isProp, U);
    }
    else
    {
        enum isPropTuple = false;
    }
}

unittest
{
    alias TProp1 = Prop!("text", string);
    alias TProp2 = Prop!("number", int);
    alias TPropTuple1 = Tuple!(TProp1);
    alias TPropTuple2 = Tuple!(TProp2);
    alias TPropTuple3 = Tuple!(TProp1, TProp1);
    alias TPropTuple4 = Tuple!(TProp2, TProp2);
    alias TPropTuple5 = Tuple!(TProp1, TProp2);

    static assert(isPropTuple!TPropTuple1);
    static assert(isPropTuple!TPropTuple2);
    static assert(isPropTuple!TPropTuple3);
    static assert(isPropTuple!TPropTuple4);
    static assert(isPropTuple!TPropTuple5);
}

template isPropLike(T)
{
    enum isPropLike = isProp!T || isPropTuple!T;
}

auto makeProps(T)(immutable T obj)
out (result)
{
    static assert(isPropTuple!(typeof(result)));
}
body
{
    FieldProps!T result;
    foreach (i, name; FieldNameTuple!T)
    {
        result[i] = prop!name(__traits(getMember, obj, name));
    }
    return tuple(result);
}

private template FieldProps(T)
{
    alias FieldProps = FieldProps!(T, FieldNameTuple!T);
}

private template FieldProps(T, Names...) if (Names.length > 0)
{
    static if (Names.length == 1)
    {
        alias FieldProps = Prop!(Names[0], FieldTypeByName!(T, Names[0]));
    }
    else static if (Names.length > 1)
    {
        alias FieldProps = AliasSeq!(Prop!(Names[0], FieldTypeByName!(T,
                Names[0])), FieldProps!(T, Names[1 .. $]));
    }
}

private template FieldTypeByName(T, string Name)
{
    alias FieldTypeByName = ReturnType!({
        T temp = void;
        return __traits(getMember, temp, Name);
    });
}

template prop(string name)
{
    immutable(Prop!(name, Unqual!T)) prop(T)(T value)
            if (is(typeof({ immutable x = value; })))
    {
        return typeof(return)(value);
    }

    immutable(Prop!(name, T)) prop(T)(immutable T value)
            if (!is(typeof({ immutable x = T.init; })))
    {
        return typeof(return)(value);
    }
}

unittest
{
    auto text = prop!"number"(1);
    assert(text.name == "number");
    assert(text.value == 1);
}

unittest
{
    auto text = prop!"text"("some text");
    assert(text.name == "text");
    assert(text.value == "some text");
}

struct Prop(string Name, T)
{
    enum name = Name;
    T value;

    this(immutable T value) immutable
    {
        this.value = value;
    }
}

mixin template AssignConstructor()
{
    this(Props...)(Props props) immutable 
            if (allSatisfy!(isPropLike, Props) && Props.length > 0)
    {
        static if (isPropTuple!(Props[0]))
        {
            mixin("this." ~ props[0][0].name ~ " = props[0][0].value;");
            static if (props[0].length > 1)
            {
                static if (props.length > 1)
                    this(props[0][1 .. $], props[1 .. $]);
                else
                    this(props[0][1 .. $]);
            }
            else static if (props.length > 1)
                this(props[1 .. $]);
        }
        else //isProp!T
        {
            mixin("this." ~ props[0].name ~ " = props[0].value;");
            static if (props.length > 1)
            {
                this(props[1 .. $]);
            }
        }
    }
}

unittest
{
    static struct Test
    {
        mixin AssignConstructor;

        string text;
        int number;
    }

    auto test = immutable Test(prop!"text"("test"), prop!"number"(1));
    assert(test.text == "test");
    assert(test.number == 1);

    auto rep = immutable Test(makeProps(test), prop!"text"("some text"));
    assert(test.text == "test");
    assert(rep.number == 1);
}

# assign

A flexible constructer for immutable struct.


## Usage

```d
import assign;

struct Test
{
    string text;
    int number;

    mixin AssignConstructor;
}

void main()
{
    auto test = immutable Test(prop!"text"("test"), prop!"number"(1));
    assert(test.text == "test");
    assert(test.number == 1);

    //rep takes over test's props, and assign the text field.
    auto rep = immutable Test(makeProps(test), prop!"text"("some text"));
    assert(test.text == "test");
    assert(rep.number == 1);
}
```
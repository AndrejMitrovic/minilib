# Todo

- Run separate tests from outside the module scope, to verify that mixin templates still work.
  Some mixins might call into functions which might not have access to user-defined symbols
  due to access restrictions, or even forward reference errors.

- Add ddoc generation build script.

- Test for function conflicts between library modules, and also between the library and Phobos.

- Update DispatchObject so it works the same as DynamicDispatch which makes sure
  dynamic types of unknown origin are cast to the appropriate base-class type.

- Implement DispatchObject with a Tag

- Implement DispatchMethod which require a 'this' field:

class A { }
class B : A { }

class C
{
    void test()
    {
        A a = new B;
        foo(b);
    }

    void foo(B b) { }
}

# minilib

This is a collection of D code that I use in my own projects, which are now part of this central library.

This is a personal library and does not have any feature list / plans / or any guarantees that it will work for you.

**Code in this library can change at any time, it is not stable. If you still want to use it, either clone the repository or copy the code snippets, all code is Boost-licensed and therefore doesn't require permission to copy and use it.**

That being said, most (if not all) functions are unittested, so there's at least **some** guarantee that the code will work.

Currently it's only tested on Windows 7, but has little platform-specific code.

## Building

**NOTE (June 17th 2013)**: Make sure you're using the latest compiler from git-head, otherwise building minilib statically might cause linking failures due to [Bug 10386](http://d.puremagic.com/issues/show_bug.cgi?id=10386).

Make sure you're using the latest compiler. Sometimes that even means using the latest git-head version
(sorry about that).

Either set the `%AE_HOME%` and `%DCOLLECTIONS_HOME%` environment variables, or clone these dependencies
alongside minilib, so `AE`, `dcollections-2.0c`, and `minilib` are alongside one another in the same directory.

Run the `build.bat` file to both run the unittests and generate a static library in the bin subfolder.

## Dependencies

- [AE](https://github.com/CyberShadow/ae)
- [DCollections](http://www.dsource.org/projects/dcollections)

## License

Distributed under the Boost Software License, Version 1.0.
See accompanying file LICENSE_1_0.txt or copy [here][BoostLicense].

[BoostLicense]: http://www.boost.org/LICENSE_1_0.txt

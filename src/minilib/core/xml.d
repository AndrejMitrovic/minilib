/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.xml;

import std.array;
import std.conv;
import std.string;

import ae.utils.xmllite;

/**
    Read data as xml and return node named
    rootName (if set) or the root node.
*/
XmlNode getRootNode(string data, string rootName = null)
{
    XmlNode document = new XmlDocument(data);

    if (rootName.length)
        return document[rootName];
    else
        return document.children[0];
}

///
unittest
{
    string xmlData = q{
        <?xml version="1.0"?>
        <GCC_XML cvs_revision="1.135">
          <File id="f2" name="&lt;built-in&gt;"/>
        </GCC_XML>
    };

    XmlNode root1 = getRootNode(xmlData);
    assert(root1.attributes["version"] == "1.0");

    XmlNode root2 = getRootNode(xmlData, "GCC_XML");
    assert(root2.attributes["cvs_revision"] == "1.135");

    XmlNode fn = root2.children[0];
    assert(fn.attributes["name"] == "<built-in>");
}

/** Return all child nodes that match 'tag' */
XmlNode[] getChildren(XmlNode node, string tag)
{
    Appender!(XmlNode[]) result;

    foreach (child; node.children)
    {
        if (child.tag == tag)
            result ~= child;
    }

    return result.data;
}

///
unittest
{
    string xmlData = q{
        <?xml version="1.0"?>
        <GCC_XML>
          <File id="f1" name="test1.cpp"/>
          <File id="f2" name="test2.cpp"/>
        </GCC_XML>
    };

    XmlNode root = getRootNode(xmlData, "GCC_XML");
    XmlNode[] children = root.getChildren("File");
    assert(children.length == 2);
    assert(children[0].attributes["id"] == "f1");
    assert(children[1].attributes["id"] == "f2");
}


/** Return boolean value of attribute. */
bool get(T : bool)(XmlNode node, string attribute)
{
    if (auto val = attribute in node.attributes)
        return (*val == "1");

    return false;
}

///
unittest
{
    string xmlData = q{
        <?xml version="1.0"?>
        <GCC_XML>
          <Value state="1"/>
          <Value state="0"/>
        </GCC_XML>
    };

    XmlNode root = getRootNode(xmlData, "GCC_XML");
    XmlNode[] children = root.getChildren("Value");
    assert(children.length == 2);
    assert(children[0].get!bool("state"));
    assert(!children[1].get!bool("state"));
}

/** Return string value of attribute. */
string get(T : string)(XmlNode node, string attribute)
{
    if (auto str = attribute in node.attributes)
        return (*str).strip;

    return null;
}

///
unittest
{
    string xmlData = q{
        <?xml version="1.0"?>
        <GCC_XML>
          <Value name="foo"/>
          <Value name="bar"/>
        </GCC_XML>
    };

    XmlNode root = getRootNode(xmlData, "GCC_XML");
    XmlNode[] children = root.getChildren("Value");
    assert(children.length == 2);
    assert(children[0].get!string("name") == "foo");
    assert(children[1].get!string("name") == "bar");
}

/** Return integral value of attribute. */
size_t get(T : size_t)(XmlNode node, string attribute)
{
    if (auto val = attribute in node.attributes)
        return to!size_t((*val).strip);

    return 0;
}

///
unittest
{
    string xmlData = q{
        <?xml version="1.0"?>
        <GCC_XML>
          <Value size="10"/>
          <Value size="20"/>
        </GCC_XML>
    };

    XmlNode root = getRootNode(xmlData, "GCC_XML");
    XmlNode[] children = root.getChildren("Value");
    assert(children.length == 2);
    assert(children[0].get!size_t("size") == 10);
    assert(children[1].get!size_t("size") == 20);
}

/** Convenience template to make aliases for node properties. */
template getNodeField(Type, string attribute)
{
    Type getNodeField(XmlNode node)
    {
        return node.get!Type(attribute);
    }
}

///
unittest
{
    alias getNodeField!(bool, "state") isConst;

    string xmlData = q{
        <?xml version="1.0"?>
        <GCC_XML>
          <Value state="1"/>
          <Value state="0"/>
        </GCC_XML>
    };

    XmlNode root = getRootNode(xmlData, "GCC_XML");
    XmlNode[] children = root.getChildren("Value");
    assert(children.length == 2);
    assert(isConst(children[0]));
    assert(!isConst(children[1]));
}

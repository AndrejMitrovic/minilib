/*********************************************************
   Copyright: (C) 2008-2010 by Steven Schveighoffer.
              All rights reserved

   License: Boost Software License version 1.0

   Permission is hereby granted, free of charge, to any person or organization
   obtaining a copy of the software and accompanying documentation covered by
   this license (the "Software") to use, reproduce, display, distribute,
   execute, and transmit the Software, and to prepare derivative works of the
   Software, and to permit third-parties to whom the Software is furnished to
   do so, all subject to the following:

   The copyright notices in the Software and this entire statement, including
   the above license grant, this restriction and the following disclaimer, must
   be included in all copies of the Software, in whole or in part, and all
   derivative works of the Software, unless such copies or derivative works are
   solely in the form of machine-executable object code generated by a source
   language processor.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
   SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
   FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
   ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
   DEALINGS IN THE SOFTWARE.

**********************************************************/
module dcollections.Link;

private import dcollections.DefaultAllocator;

/**
 * Linked-list node that is used in various collection classes.
 */
struct Link(V)
{
    /**
     * convenience alias
     */
    alias Link *Node;
    Node next;
    Node prev;

    /**
     * the value that is represented by this link node.
     */
    V value;

    /**
     * insert the given node between this node and prev.  This updates all
     * pointers in this, n, and prev.
     *
     * returns this to allow for chaining.
     */
    Node prepend(Node n)
    {
        attach(prev, n);
        attach(n, &this);
        return &this;
    }

    /**
     * insert the given node between this node and next.  This updates all
     * pointers in this, n, and next.
     *
     * returns this to allow for chaining.
     */
    Node append(Node n)
    {
        attach(n, next);
        attach(&this, n);
        return &this;
    }

    /**
     * remove this node from the list.  If prev or next is non-null, their
     * pointers are updated.
     *
     * returns this to allow for chaining.
     */
    Node unlink()
    {
        attach(prev, next);
        next = prev = null;
        return &this;
    }

    /**
     * link two nodes together.
     */
    static void attach(Node first, Node second)
    {
        if(first)
            first.next = second;
        if(second)
            second.prev = first;
    }

    /**
     * count how many nodes until endNode.
     */
    uint count(Node endNode = null)
    {
        Node x = &this;
        uint c = 0;
        while(x !is endNode)
        {
            x = x.next;
            c++;
        }
        return c;
    }

    //
    // root is the target.  If it is null, a new node is created, otherwise
    // this node is copied to the root node, and subsequent nodes are allocated
    // using the createFunction
    //
    Node dup(Node delegate(V v) createFunction, Node root = null)
    {
        //
        // create a duplicate of this and all nodes after this.
        //
        auto n = next;
        if(root)
            root.value = value;
        auto retval = root ? root : createFunction(value);
        auto cur = retval;
        while(n !is null && n !is &this)
        {
            auto x = createFunction(n.value);
            attach(cur, x);
            cur = x;
            n = n.next;
        }
        if(n is &this)
        {
            //
            // circular list, complete the circle
            //
            attach(cur, retval);
        }
        return retval;
    }

    Node dup()
    {
        Node _create(V v)
        {
            auto n = new Link!(V);
            n.value = v;
            return n;
        }
        return dup(&_create);
    }
}

/**
 * This struct uses a Link(V) to keep track of a link-list of values.
 *
 * The implementation uses a dummy link node to be the head and tail of the
 * list.  Basically, the list is circular, with the dummy node marking the
 * end/beginning.
 */
struct LinkHead(V, alias Allocator=DefaultAllocator)
{
    /**
     * Convenience alias
     */
    alias Link!(V).Node Node;

    /**
     * Convenience alias
     */
    alias Allocator!(Link!(V)) allocator;

    /**
     * The allocator for this link head
     */
    allocator alloc;

    /**
     * The node that denotes the end of the list
     */
    Node end; // not a valid node

    Link!V _end; // storage for end

    /**
     * The number of nodes in the list
     */
    uint count;

    /**
     * Get the first valid node in the list
     */
    @property Node begin()
    {
        return end.next;
    }

    /**
     * Initialize the list
     */
    void setup()
    {
        end = &_end;
        Node.attach(end, end);
        count = 0;
    }

    /**
     * Remove a node from the list, returning the next node in the list, or
     * end if the node was the last one in the list. O(1) operation.
     */
    Node remove(Node n)
    {
        count--;
        Node retval = n.next;
        n.unlink;
        static if(allocator.freeNeeded)
            alloc.free(n);
        return retval;
    }

    /**
     * sort the list according to the given compare function
     */
    void sort(alias Less)()
    {
        if(end.next.next is end)
            //
            // no nodes to sort
            //
            return;

        //
        // detach the sentinel
        //
        end.prev.next = null;

        //
        // use merge sort, don't update prev pointers until the sort is
        // finished.
        //
        int K = 1;
        while(K < count)
        {
            //
            // end.next serves as the sorted list head
            //
            Node head = end.next;
            end.next = null;
            Node sortedtail = end;
            int tmpcount = count;

            while(head !is null)
            {

                if(tmpcount <= K)
                {
                    //
                    // the rest is alread sorted
                    //
                    sortedtail.next = head;
                    break;
                }
                Node left = head;
                for(int k = 1; k < K && head.next !is null; k++)
                    head = head.next;
                Node right = head.next;

                //
                // head now points to the last element in 'left', detach the
                // left side
                //
                head.next = null;
                int nright = K;
                while(true)
                {
                    if(left is null)
                    {
                        sortedtail.next = right;
                        while(nright != 0 && sortedtail.next !is null)
                        {
                            sortedtail = sortedtail.next;
                            nright--;
                        }
                        head = sortedtail.next;
                        sortedtail.next = null;
                        break;
                    }
                    else if(right is null || nright == 0)
                    {
                        sortedtail.next = left;
                        sortedtail = head;
                        head = right;
                        sortedtail.next = null;
                        break;
                    }
                    else
                    {
                        if(Less(right.value, left.value))
                        {
                            sortedtail.next = right;
                            right = right.next;
                            nright--;
                        }
                        else
                        {
                            sortedtail.next = left;
                            left = left.next;
                        }
                        sortedtail = sortedtail.next;
                    }
                }

                tmpcount -= 2 * K;
            }

            K *= 2;
        }

        //
        // now, attach all the prev nodes
        //
        Node n;
        for(n = end; n.next !is null; n = n.next)
            n.next.prev = n;
        Node.attach(n, end);
    }

    /**
     * Remove all the nodes from first to last.  This is an O(n) operation.
     */
    Node remove(Node first, Node last)
    {
        Node.attach(first.prev, last);
        auto n = first;
        while(n !is last)
        {
            auto nx = n.next;
            static if(alloc.freeNeeded)
                alloc.free(n);
            count--;
            n = nx;
        }
        return last;
    }

    /**
     * Insert the given value before the given node.  Use insert(end, v) to
     * add to the end of the list, or to an empty list. O(1) operation.
     */
    Node insert(Node before, V v)
    {
        count++;
        return before.prepend(allocate(v)).prev;
    }

    /**
     * Remove all nodes from the list
     */
    void clear()
    {
        static if(alloc.freeNeeded)
            alloc.freeAll();
        Node.attach(end, end);
        count = 0;
    }

    /**
     * Copy this list to the target.
     */
    void copyTo(ref LinkHead target, bool copyNodes=true)
    {
        if(copyNodes)
        {
            // copy fields besides the nodes and allocator
            target.count = this.count;

            // now, copy the nodes
            if(count)
            {
                end.dup(&target.allocate, target.end);
            }
        }
    }

    /**
     * Allocate a new node
     */
    private Node allocate()
    {
        return alloc.allocate();
    }

    /**
     * Allocate a new node, then set the value to v
     */
    private Node allocate(V v)
    {
        auto retval = allocate();
        retval.value = v;
        return retval;
    }
}

// TODO:  Bug 3051, when fixed should us to call sort in the LinkHead struct
// itself.
void mergesort(alias less, V)(ref LinkHead!V lh)
{
    if(lh.end.next.next is lh.end)
        //
        // no nodes to sort
        //
        return;

    //
    // detach the sentinel
    //
    lh.end.prev.next = null;

    //
    // use merge sort, don't update prev pointers until the sort is
    // finished.
    //
    int K = 1;
    while(K < lh.count)
    {
        //
        // end.next serves as the sorted list head
        //
        auto head = lh.end.next;
        lh.end.next = null;
        auto sortedtail = lh.end;
        int tmpcount = lh.count;

        while(head !is null)
        {

            if(tmpcount <= K)
            {
                //
                // the rest is alread sorted
                //
                sortedtail.next = head;
                break;
            }
            auto left = head;
            for(int k = 1; k < K && head.next !is null; k++)
                head = head.next;
            auto right = head.next;

            //
            // head now points to the last element in 'left', detach the
            // left side
            //
            head.next = null;
            int nright = K;
            while(true)
            {
                if(left is null)
                {
                    sortedtail.next = right;
                    while(nright != 0 && sortedtail.next !is null)
                    {
                        sortedtail = sortedtail.next;
                        nright--;
                    }
                    head = sortedtail.next;
                    sortedtail.next = null;
                    break;
                }
                else if(right is null || nright == 0)
                {
                    sortedtail.next = left;
                    sortedtail = head;
                    head = right;
                    sortedtail.next = null;
                    break;
                }
                else
                {
                    if(less(right.value, left.value))
                    {
                        sortedtail.next = right;
                        right = right.next;
                        nright--;
                    }
                    else
                    {
                        sortedtail.next = left;
                        left = left.next;
                    }
                    sortedtail = sortedtail.next;
                }
            }

            tmpcount -= 2 * K;
        }

        K *= 2;
    }

    //
    // now, attach all the prev nodes
    //
    lh.Node n;
    for(n = lh.end; n.next !is null; n = n.next)
        n.next.prev = n;
    lh.Node.attach(n, lh.end);
}
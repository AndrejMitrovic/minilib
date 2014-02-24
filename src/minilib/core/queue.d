/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.queue;

import dcollections.LinkList;

/**
    Keeps a list of items of type T sorted according to their priority.
    This type itself is not a range, it needs to be sliced to get a range.

    $(B Note:) Currently implemented with an inefficient O(n) algorithm.
*/
final class PriorityQueue(T)
{
    /** Instantiate the queue. */
    this()
    {
        list = new LinkList!PriorityItem;
    }

    /** Add an item with a priority to the priority queue. */
    void addItem(T item, int priority)
    {
        PriorityItem pi = PriorityItem(item, priority);

        if (!list.length)
            list.add(pi);  // nothing in queue
        else
        if (list.back.priority >= priority)
            list.add(pi);  // new lowest-priority item
        else
        {
            // find item with lower priority than target one,
            // and insert target before it.
            for (auto rng = list[]; !rng.empty; rng.popFront())
            {
                if (rng.front.priority < priority)
                {
                    list.insert(rng.begin(), pi);
                    break;
                }
            }
        }
    }

    /** Remove the item from the queue. */
    void removeItem(T item)
    {
        for (auto rng = list[]; !rng.empty; rng.popFront())
        {
            if (rng.front.item == item)
            {
                list.remove(rng.begin());
                break;
            }
        }
    }

    /** Return true if no more items are left in the queue. */
    bool empty()
    {
        return !list.length;
    }

    /** Clear out all items from the queue. */
    void clearQueue()
    {
        list.clear();
    }

    /**
        Fetch the next highest-priority item from the queue,
        remove it from the queue and return it.
    */
    PriorityItem takeFront()
    {
        return list.takeFront();
    }

    /** Return the range of queued items. */
    auto opSlice()
    {
        return list[];
    }

    /**
        The item and its priority are stored together in a struct.
        This type is implicitly convertible to the item type.
    */
    struct PriorityItem
    {
        T item; ///
        int priority; ///
        alias item this;
    }

private:
    /**
        The list is sorted according to priority. The front has the highest
        priority, the back the lowest.
    */
    LinkList!PriorityItem list;
}

unittest
{
    static class Foo { }
    alias PriorityQueue!Foo Queue;
    Queue queue = new Queue;

    auto foo1 = new Foo;
    auto foo2 = new Foo;
    auto foo3 = new Foo;
    auto foo4 = new Foo;
    queue.addItem(foo1, 1);
    queue.addItem(foo2, 2);
    queue.addItem(foo3, 3);
    queue.addItem(foo4, 3);

    queue.removeItem(foo2);

    size_t count;
    foreach (item; queue[])
    {
        count++;

        if (count == 1)  // foo3 is highest priority
            assert(item is foo3);
        else
        if (count == 2)
            assert(item is foo4);
        else  // foo1 is lowest priority
            assert(item is foo1);

        // foo2 does not exist
        assert(item !is foo2);
    }

    assert(count == 3);
}

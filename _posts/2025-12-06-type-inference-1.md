---
title: "Type inference with Zig — I: Types & Kinds"
author: Templin Konstantin
category: programming
layout: post
---

# Introduction

In this article, I want to examine how type inference works in programming languages and also write the simplest implementation in the Zig language. If you ask “Why Zig and not X?”, my answer is -- just for fun 🙂. And I would like to begin with the notion of programming language semantics. In simple terms, semantics is a concept that explains the meaning of programming language constructs and how they behave.

There are two kinds of semantics: **dynamic** and **static**.

- **Dynamic** properties of a given program can generally be determined only by executing the program.
- **Static** properties can be determined without executing the program. Unlike a dynamic property, a static property must be independent of the specific argument values with which a parameterized program is invoked.

A static property may be determined during analysis, i.e., when the program is analyzed before execution. In many implementations, program analysis is performed by the compiler, in which case it happens during compilation. However, a program may be analyzed without compiling it (i.e., translating it into another, usually lower-level language), so in general we distinguish these two time points.

For example, consider the following function written in pseudocode:

{% highlight zig linenos %}
pub fn fact(n) {
    if (n <= 1) {
        return 1;  
    }
    return n * fact(n - 1);
}
{% endhighlight %}


What can we say about this program? We assume that the input for this function is some number. The result of this program is a dynamic property because we do not know in advance what input the user will provide.

However, there are many static properties of this program that can be determined before execution. For example, we know that the function has some parameter `n`, on which we can perform operations `<=`, `*`, `-`. The result of executing this function will be some non-negative integer. Under additional assumptions (e.g. that n ranges over $\mathbb{N}$ and all primitive operations are total), we can statically establish that the program is guaranteed to terminate.

In general, static properties that help with verification, optimization, and documentation of programs are of interest. For example, we might want to ask the following questions about a program:

* does the program satisfy a given specification?
* can the program encounter a certain erroneous situation?
* is it guaranteed that during execution some variable will contain a value consistent with its declared type?
* can the program be optimized in some way without changing its meaning?

Of course, there exist questions that cannot be solved in the general case. “Does this program halt?” -- the most famous example of an undecidable problem. But undecidability does not mean that determining static properties is hopeless. In practice, two approaches are used to circumvent undecidability:

1. **Performing a conservative approximation** of the desired property.
   For example, when analyzing termination (determining whether a program halts), three answers are allowed:

   * (a) yes, the program is guaranteed to terminate;
   * (b) possibly does not terminate (I’m not sure);
   * (c) no, the program is guaranteed not to terminate.

   A termination analysis is considered **sound** if it outputs (a) or (b) for a program that terminates, and (b) or (c) for a program that does not terminate.

   Of course, a trivially sound analysis always answers (b). In practice, we’re interested in sound analyses that give (a) or (c) as often as possible.

2. **Restricting the language** to a level where the property can be determined unambiguously.
   Such restrictions allow computing static information exactly during analysis, but reduce expressiveness by forbidding some programs that would be valid in a more general language.

   For example, languages with static type systems forbid many expressions whose execution would not lead to dynamic type errors.

---

# What is a Type?

When working with code, expressions are usually described in terms of what values they can operate on. For example, we typically define the `>` operator as a procedure that takes two integers and returns a boolean value. However, we can infer a bit more about this operation.

{% highlight zig linenos %}
pub fn main() {
    if (f(1, 2)) {
        // ...
    }
}
{% endhighlight %}


In this example, we can say that the symbol `f` is, first of all, some function that takes two integer arguments and also returns a boolean value, since it is used in an `if` expression. In this case, `f` may be `>`, but more importantly -- it may be *any* other function that fits the definition “takes two integers and returns a boolean value”.

This example shows that to determine some properties of a program, it is not necessary to know exact values -- abstract descriptions of values are sufficient. In this case, such abstract descriptions are called **types**. Types differ in the contexts in which the described values may be used.

The primary goal of a type system is to detect type errors -- attempts to perform an incorrect operation on a value. Examples of type errors include: adding an integer and a string, calling a procedure with wrong argument count or types, trying to call an integer as a procedure, interpreting the bits of a floating-point number as an integer, address, or instruction. Some type systems detect errors at runtime; others detect them during analysis before execution. A language is considered **type-safe** if its type system prevents incorrect operations -- either by terminating program execution when an error is detected or by preventing compilation.

A type system has a **type loophole** if it allows a value of one type to masquerade as a value of another type. The C language is full of such loopholes, and Pascal has similar loopholes due to variant records.

**Example in C:**
Let `a` be a local array of two integers (`a[0]`, `a[1]`). C allows out-of-bounds access (`a[-1]`, `a[2]`), returning the contents of adjacent memory cells. A programmer who knows how the compiler lays out local variables may place values of other types (e.g., floating-point numbers) into those cells and then use `a[-1]` or `a[2]` to interpret their bits as integers. A language with such loopholes is obviously not type-safe.

Not all languages are truly untyped: if any value is allowed in any context, as in untyped lambda calculus or machine code with homogeneous bit patterns, the type system is absent. But as soon as some bit patterns are considered invalid, or the programmer begins to distinguish values by their role, a type system effectively emerges.

In general, types are not some monolithic “on/off” capability. Instead, there are many different manifestations in programming languages. For example, in Python this code:

{% highlight python %}
def f(x, y):
    return x + y
f("foo", 1)
{% endhighlight %}

will produce an error:

```
return x + y
       ~~^~~
TypeError: can only concatenate str (not "int") to str
```

Here, the error appears at runtime, which is an example of dynamic type checking. However, such checks incur time and memory overhead -- a type tag must be stored and checked when certain operations are performed.

Static typing proposes analyzing a program in advance, assigning types to language phrases. If the types are consistent, the program is considered correct and usually does not cause type errors at runtime. Statically typed languages (C, C++, Rust, Zig, Haskell, ML, Pascal) use types for program translation into executable code.

Dynamically typed languages (Erlang, Lisp, JavaScript, Python, Scheme, etc.) are often interpreted and therefore rely on runtime checks.

Some languages combine both approaches: Java performs static checks during compilation, additional checks when loading classes, and dynamic checks related to reflection and type conversions.

Statically typed languages traditionally require explicit type annotations (Ada, C, Java). However, ML-style languages provide static typing without annotations thanks to **type inference** (type reconstruction). Annotations serve more as documentation and hints for the compiler, but their volume may exceed the code itself. Implicit types make programs shorter but impose limitations: not everything can be inferred automatically, so annotations are sometimes necessary. ML and Haskell use a mixed approach.

Simple type systems are easier to check, but they restrict expressiveness (for example, fixed array length in early Pascal or the lack of a universal `reverse` in Java). More powerful systems support polymorphism and advanced mechanisms: subtyping, existential and dependent types, module types, effect systems. These capabilities make a language more expressive but complicate analysis and type inference.

---

# Polymorphism

In general, polymorphism can be described as the ability to define and use functions that support many different types. The simplest example is the identity function `id` in pseudo-code:

{% highlight zig %}
pub fn id[t](x: t) = x
{% endhighlight %}


and we can call it with any argument, for example:


{% highlight zig %}
Id(1)
Id("foo")
{% endhighlight %}


Most modern statically typed languages use various forms of polymorphism. You may encounter:

* **parametric polymorphism** ($$\forall a. …$$),
* **ad-hoc polymorphism** (type classes, interfaces, overloading),
* **subtyping polymorphism**,
* and more complex mechanisms (e.g., string polymorphism, structural polymorphism).

> In this article, the implementation uses the simplest and historically first variant -- parametric polymorphism with quantification only at the level of type schemes in the environment.
{: .prompt-info }

---

# Type inference

Before going into the implementation details, it's worth explaining why type inference is important in language development. The type system doesn't just prevent certain classes of errors -- it determines how expressive a language can be. When a compiler can infer types for you, programs tend to become cleaner, more ergonomic, and easier to refactor.

When building a type system, two fundamental questions inevitably arise:

* **Type checking:** is the term defined, does it really have the type $$T$$?
* **Type inference:** Is there a context and a type of $$T$$ so that the term $$M$$ can be assigned this type?

Type checking is a mechanical part: we already know the expected type and just check for compliance. Modern languages rely heavily on this to reduce noise in annotations, and thanks to a well-designed inference algorithm, even complex type systems seem natural, as if the compiler politely finishes your sentences.

Let's start with an illustrative example:

```zig
var x = "foo"; // x: string
```

Straightforward. The compiler sees the string literal and comes to the conclusion that `x` is a string. From now on, every use of `x` benefits from this inference. The place where we will save such statements is called the *typing context*.

Another example: suppose we have a function `foo` of type `Int -> Int`. Then:

```zig
y = ...?
foo(y) // foo(y): Int
```

Even if we don't know anything about `y`, we can conclude that `y` must be of type `Int`, otherwise the expression would not make sense. The rules simply do not allow otherwise.

Similarly, with abstractions:

```zig
pub fn bar(x: t) = expression
```

we know that `bar` must be of type `t -> T_expr', where `T_expr` is the type of the expression body.

Now let's add some abstractions and begin writing an implementation!

---

# Implementation

We begin with the notion of **kinds**. A kind is a “type of a type”. Still not clear, right? 😀
The thing is that there are types called **type constructors**, such as `List[t]`, `Array[t]`, and others from familiar programming languages. We can say that `List` is some type that takes another type as input, i.e., in a sense behaves like a function. For example, we can use a list of integers `List[Int]` or an array of strings `Array[String]`. Obviously, in this sense, `List` differs from primitive types such as `Int`/`String`, etc. To distinguish between these kinds of types, the concept of **kinds** was introduced.

In this article, we will use only two kinds: **Star** and **KFun**. Primitive types correspond to the **Star** kind. `KFun` is a bit more complicated. It can be recursively described as `KFun(Kind, Kind)` or `* -> *`. This means that this kind takes another kind as an argument. Examples will follow later. In general, the kind system is very powerful and expressive; it allows generalizing and unifying many type constructs.

Let’s proceed to implementing kinds. But first, a small disclaimer -- the presented implementation is far from the most optimal; here the emphasis is on simplicity. Later in the article I will talk about possible optimizations.

> Zig compiler version 0.15.2 is used
{: .prompt-info }


The implementation was largely inspired by the absolutely wonderful article *Typing Haskell in Haskell* by **Mark P. Jones**. I highly recommend it to anyone interested; for example, it also covers type class implementation.

Here is approximately how the definition of kinds will look in Zig. Later we will need the ability to compare kinds, so an `eql` function is also provided.

{% highlight zig linenos %}
pub const Kind = union(enum) {
    star: void, // simplest option
    kfun: struct { left: *Kind, right: *Kind },

    pub fn isStar(a: Kind) bool {
        return switch (a) {
            .star => true,
            else => false,
        };
    }

    pub fn eql(a: *const Kind, b: *const Kind) bool {
        return switch (a.*) {
            .star => b.isStar(),
            .kfun => |a_fun| {
                const b_fun = b.kfun;
                return a_fun.left.eql(b_fun.left) and
                    a_fun.right.eql(b_fun.right);
            },
        };
    }
};
{% endhighlight %}

Now let’s move on to defining types. In our article we will distinguish:

* **type constructors**,
* **type variables**,
* **type applications**,
* and auxiliary types **TGen**, whose use will be discussed later.

A **type constructor** is the basic building block for expressing types and is the most familiar. A type constructor represents a type name and its kind. For example, we can designate the type `Int` as `TyCon("Int", *)`, where `*` is the Star kind.

A **type variable** plays perhaps the most important role in type inference. You can think of it like a usual variable from school or university. For example, in the equation $$x + 10 = 0$$ there is some variable $$x$$. In some sense, we do not know its value when we see the equation. But we can solve the equation and obtain the value: $$x = -10$$. In our type system implementation, a variable is a unique numeric identifier and its kind. Example: `TyVar(0, *)`.

A **type application** can be thought of as some function that takes one type and returns another. For example, `TyApp(List, Int)` -- here we apply type `List` to type `Int`.

The **TGen** type which represent “generic” or quantified type variables, it also called de Bruijn indexing. `TGen` is represented as a numeric identifier. The only place where TGen values are used is in the representation of type schemes, which will be described later.

> We do not provide a representation for type synonyms, assuming instead that they have been fully expanded before typechecking. For example, the `String` type synonym for `[Char]`.
{: .prompt-info }

In implementation, this will look like:

{% highlight zig linenos %}
pub const Id = u32;
pub const TyVar = struct {
    id: Id,
    kind: Kind,

    pub fn getKind(self: TyVar) Kind {
        return self.kind;
    }

    pub fn eql(self: TyVar, other: TyVar) bool {
        if (self.id == other.id and Kind.eql(&self.kind, &other.kind)) {
            return true;
        }
        return false;
    }
};

pub const TyCon = struct {
    name: []const u8,
    kind: Kind,

    pub fn getKind(self: TyCon) Kind {
        return self.kind;
    }
};

pub const GenId = u32;

pub const Type = union(enum) {
    tvar: TyVar,
    tcon: TyCon,
    tapp: struct { left: *Type, right: *Type },
    tgen: GenId,

    pub fn typevar(id: Id, kind: Kind) Type {
        return .{ .tvar = TyVar{ .id = id, .kind = kind } };
    }

    pub fn typecon(name: []const u8, kind: Kind) Type {
        return .{ .tcon = TyCon{ .name = name, .kind = kind } };
    }

    pub fn typeapp(left: *Type, right: *Type) Type {
        return .{ .tapp = .{ .left = left, .right = right } };
    }

    pub fn typegen(id: GenId) Type {
        return .{ .tgen = id };
    }

    pub fn getKind(self: Type) Kind {
        return switch (self) {
            .tvar => |s| s.getKind(),
            .tcon => |c| c.getKind(),
            .tgen => unreachable, // will be described later
            .tapp => |a| blk: {
                const k = a.left.getKind();
                switch (k) {
                    .kfun => |f| break :blk f.right.*,
                    else => unreachable,
                }
            },
        };
    }
};
{% endhighlight %}

Let's write our final `main` function and define some types using `Kind` and `Type`.

We begin by creating the kinds:

{% highlight zig linenos %}
// ------------------------------------------------------------------
// KINDS
// ------------------------------------------------------------------
// Create the base kind star kind `*`.  
// This kind represents ordinary, fully applied types, for example:
//     Int : *
//     Char : *
//     ()   : *
var star = Kind{ .star = {} };
const kstar = &star;

// Create the kind `* -> *`.  
// This kind represents type constructors that take one type
// and return a new type:
//     []    : * -> *
//     List  : * -> *
//     Array : * -> *
// Any type with kind `* -> *` cannot be used as a value-level type
// until it is applied to an argument of kind `*`.
var kfun_star_star = Kind{
    .kfun = .{ .left = kstar, .right = kstar },
};
{% endhighlight %}

Once the kinds are ready, we introduce several primitive types (`Int`, `Char`, `()`), along with a type variable `a`. That variable is our first placeholder -- an unknown that will eventually be resolved through inference.

{% highlight zig linenos %}
var tUnit = Type.typecon("()", star);
var tChar = Type.typecon("Char", star);
var tInt  = Type.typecon("Int",  star);

// Create a type variable `a : *`.
// This represents an unknown type that must later unify
// with some concrete type during inference.
var tvA = Type.typevar(0, star);
{% endhighlight %}

Now we can define *higher-kinded* types using $$* \rightarrow *$$ kind:

{% highlight zig linenos %}
// List constructor: [] : * -> *
var tList = Type.typecon("[]", kfun_star_star);

// Arrow constructor for function types: (->) : * -> (* -> *)
// The left kind is `*`, and the right is again a constructor kind.
//
// When applied twice as:
//     (->) A B
// we obtain the function type A -> B.
var tArrow = Type.typecon("(->)", Kind{
    .kfun = .{ .left = kstar, .right = &kfun_star_star },
});

// Tuple constructor: (,) : * -> *  
// (for simplicity represented as binary tuple)
var tTuple2 = Type.typecon("(,)", kfun_star_star);
{% endhighlight %}

This types accept other type as argument and returns new type. Using application we can make fully applied types:

{% highlight zig linenos %}
// Build the type `[a]` by applying the List constructor to `a`:
//     TApp tList a
var listA = Type.typeapp(&tList, &tvA);

// Build `Int -> [a]`.
//
// Function types are expressed by applying the arrow constructor twice:
//     (->) Int [a]
//
// First application: (->) Int
var arrowInt = Type.typeapp(&tArrow, &tInt);

// Second application: ((->) Int) [a]
var fnType = Type.typeapp(&arrowInt, &listA);

// Build a concrete list type `[Char]`.
var listChar = Type.typeapp(&tList, &tChar);
{% endhighlight %}

Full `main` implementation with debug prints and format helpers:

<details>

{% highlight zig linenos %}
const std = @import("std");

fn printKind(k: Kind) void {
    switch (k) {
        .star => std.debug.print("*", .{}),
        .kfun => |f| {
            std.debug.print("(", .{});
            printKind(f.left.*);
            std.debug.print(" -> ", .{});
            printKind(f.right.*);
            std.debug.print(")", .{});
        },
    }
}

fn printType(t: *const Type) void {
    switch (t.*) {
        .tvar => |v| std.debug.print("TVar({d})", .{v.id}),
        .tcon => |c| std.debug.print("{s}", .{c.name}),
        .tgen => |g| std.debug.print("TGen({d})", .{g}),
        .tapp => |a| {
            std.debug.print("(", .{});
            printType(a.left);
            std.debug.print(" ", .{});
            printType(a.right);
            std.debug.print(")", .{});
        },
    }
}

pub fn main() !void {
    var star = Kind{ .star = {} };
    const kstar = &star;
    var kfun_star_star = Kind{
        .kfun = .{ .left = kstar, .right = kstar },
    };

    var tUnit = Type.typecon("()", star);
    var tChar = Type.typecon("Char", star);
    var tInt  = Type.typecon("Int",  star);
    
    var tvA = Type.typevar(0, star);
    
    var tList = Type.typecon("[]", kfun_star_star);
    var tArrow = Type.typecon("(->)", Kind{
        .kfun = .{ .left = kstar, .right = &kfun_star_star },
    });
    var tTuple2 = Type.typecon("(,)", kfun_star_star);
    
    var listA = Type.typeapp(&tList, &tvA);
    var arrowInt = Type.typeapp(&tArrow, &tInt);
    var fnType = Type.typeapp(&arrowInt, &listA);
    var listChar = Type.typeapp(&tList, &tChar);

    // ------------------------------------------------------------------
    // DEBUG PRINTING
    // ------------------------------------------------------------------
    std.debug.print("tUnit = ", .{});
    printType(&tUnit);
    std.debug.print("\n", .{});

    std.debug.print("tChar = ", .{});
    printType(&tChar);
    std.debug.print("\n", .{});

    std.debug.print("tInt = ", .{});
    printType(&tInt);
    std.debug.print("\n", .{});

    std.debug.print("tList = ", .{});
    printType(&tList);
    std.debug.print("\n", .{});

    std.debug.print("tArrow = ", .{});
    printType(&tArrow);
    std.debug.print("\n", .{});

    std.debug.print("tTuple2 = ", .{});
    printType(&tTuple2);
    std.debug.print("\n\n", .{});

    std.debug.print("Type Int -> [a] = ", .{});
    printType(&fnType);
    std.debug.print("\n\n", .{});

    std.debug.print("tString = ", .{});
    printType(&listChar);
    std.debug.print("\n", .{});
}
{% endhighlight %}

</details>

For compile and run we need to type:

```bash
zig run ty.zig
```

And then we will get the following debug output:

```
tUnit = ()
tChar = Char
tInt = Int
tList = []
tArrow = (->)
tTuple2 = (,)

Type Int -> [a] = (((->) Int) ([] TVar(0)))

tString = ([] Char)
```

In these examples, a system based on Kind and Type demonstrates how to represent the type structure in a fully universal compositional form. 

Using only the types ($$*$$ and $$* \rightarrow *$$) and a small set of type constructors (type variables, application constructors, and generalizations), we can create both specific types (`Int`, `Char`, `()`) and parameterized types (`[a]`, `(Int → [a])`).

This shows that the kinds and types that we have implemented is already capable of expressing polymorphic types, type constructor properties, and function types. This lays the foundation for substitutions, type schemes, and Hindley-Milner inference in subsequent steps.

This concludes the first part of the series of articles on type inference. In the following parts we will examine the notions of substitution, type schemes, and the W algorithm.

Thank you all for your attention 🙂

> **Full source code** of this part available at [gist](https://gist.github.com/qnbhd/db684ead24131990ba51bc6f2c3149b6)
{: .prompt-tip }

---

## Sources

1. **Franklyn A. Turbak, David K. Gifford, Mark A. Sheldon.**
   *Design Concepts in Programming Languages.* MIT Press.

2. **Mark P. Jones.**
   *Typing Haskell in Haskell.*
   [https://web.cecs.pdx.edu/~mpj/thih/thih.pdf](https://web.cecs.pdx.edu/~mpj/thih/thih.pdf)

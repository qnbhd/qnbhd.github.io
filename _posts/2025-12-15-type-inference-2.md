---
title: "Type inference with Zig — II: Substitution"
author: Templin Konstantin
category: programming
layout: post
---

This is the second part of a series of articles devoted to type inference and its implementation in the Zig programming language.
In the first part, we clarified why type inference is needed at all, introduced the basic concepts, and implemented `Kind` and `Type`.
In this part, we focus on the notion of **type substitution** and on the central algorithm of type inference -- **unification**.

**Substitution** is a fundamental operation that appears in many areas of theoretical computer science and mathematical logic. Its essence is simple: replacing variables with concrete values or expressions. However, behind this apparent simplicity lies a powerful tool for solving various problems.

If you have ever studied the lambda calculus, you have certainly encountered substitution at the core of **beta-reduction**, its main computational mechanism.
When a function $\lambda x. M$ is applied to $N$, substitution takes place: the term $N$ replaces all free occurrences of the variable $x$ in the body $M$. This is written as:

$$
M[x := N].
$$

In term rewriting systems, substitution enables the application of transformation rules: a rule $l \to r$ can be applied to a term if there exists a substitution that makes the left-hand side identical to a subterm.

In logic programming, substitution forms the basis of **unification** -- the mechanism for finding such replacements of variables that make two terms syntactically identical.
As we can see, substitution appears in many different domains and supports a wide range of tasks.

Let us now examine substitution in the context of **type theory**.

For technical development, it is convenient to conceptually separate substitution into two parts:

1. Describing a **mapping** from type variables to types, called a *type substitution*.
2. **Applying** this mapping to a particular type, context, or term.

This separation allows us to reason abstractly about substitutions themselves (independently of any particular type) and about how substitutions act on types and typing derivations.

For example, consider the substitution

$$
\sigma = \{ \; ?x \mapsto \mathrm{Bool} \; \}.
$$

Applying $\sigma$ to the type $?x \to ?x$ yields

$$
\sigma(?x \to ?x) = \mathrm{Bool} \to \mathrm{Bool}.
$$

---

## Formal Definition

Formally, a **type substitution** (or simply *substitution* when the context is clear) is a **finite mapping** from type variables to types:

$$
\sigma : \mathrm{TypeVar} \rightharpoonup \mathrm{Type}.
$$

We write

$$
\{ \; X \mapsto T, \; Y \mapsto U \; \}
$$

for the substitution that maps $X$ to $T$ and $Y$ to $U$.

* $\mathrm{dom}(\sigma)$ is the set of variables appearing on the left-hand side of $\sigma$.
* $\mathrm{range}(\sigma)$ is the set of types appearing on the right-hand side of $\sigma$.

A crucial point — often glossed over in informal explanations — is that **all mappings in a substitution are applied simultaneously**.

> In examples we assume that  $\to \;\equiv\; \mathrm{con}\, (\texttt{->})\;(* \to (* \to *))$ or in our implementation terms `tArrow = TCon (Tycon "(->)" (Kfun Star (Kfun Star Star)))`
{: .prompt-info }

For example, the substitution

$$
\{ \; X \mapsto \mathrm{Bool}, \; Y \mapsto X \to X \; \}
$$

maps

* $X \mapsto \mathrm{Bool}$
* $Y \mapsto X \to X$

and **not** $Y \mapsto \mathrm{Bool} \to \mathrm{Bool}$.

This simultaneity property is essential for defining substitution **composition** correctly.

## Free Variables

Before moving further, we must introduce the notion of **free variables**. This is crucial for understanding how substitution works and for defining the occurs check later.

### Definition

The set of free type variables of a type $t$, denoted as $FV(t)$, is defined recursively:

* For a type variable:

  $$
  FV(?x) = {?x}.
  $$

* For a constructor type:

  $$
  FV(\mathrm{int}) = \varnothing,\quad FV(\mathrm{bool}) = \varnothing.
  $$

* For a application type:

  $$
  FV(t_1 \; t_2) = FV(t_1) \cup FV(t_2).
  $$

### Examples

$$
\begin{aligned}
FV(?x) &= \{\; ?x \; \} \\
FV(\mathrm{int} \to \mathrm{bool}) &= \varnothing \\
FV(?x \to ?y) &= \{\; ?x, ?y \;\} \\
FV\bigl( (?x \to \mathrm{int}) \to ?y \bigr) &= \{\; ?x, ?y \;\} \\
\end{aligned}
$$

Intuitively, free variables are those type variables that have not yet been fixed and may later be replaced with concrete types via substitution.

---

## Applying a Substitution to a Type

Applying a substitution $\sigma$ to a type $T$ (written $\sigma(T)$) is defined **inductively**:

* For a type variable $X$:

  $$
  \sigma(X) =
  \begin{cases}
  T & \text{if } (X \mapsto T) \in \sigma, \\
  X & \text{if } X \notin \mathrm{dom}(\sigma).
  \end{cases}
  $$

* For base types:

  $$
  \sigma(\mathrm{int}) = \mathrm{int},\qquad
  \sigma(\mathrm{bool}) = \mathrm{bool}.
  $$

* For application types:

  $$
  \sigma(T_1 \; T_2) = \sigma(T_1) \; \sigma(T_2).
  $$

At this stage, the language of types contains **no binders for type variables**, so there is no notion of variable capture and no renaming is required.
(This will change once universal quantification over types is introduced.)

### Example

Let

$$
\sigma = \{ \; ?y \mapsto \mathrm{int} \to \mathrm{int} \; \},
\qquad
T = \{ \; ?y \to \mathrm{bool} \; \}.
$$

Then

$$
\sigma(T) = \{ \; (\mathrm{int} \to \mathrm{int}) \to \mathrm{bool} \; \}.
$$

## Composition of Substitutions

During type inference, substitutions are accumulated incrementally. This requires a precise notion of **composition**.

Given substitutions $\sigma$ and $\gamma$, their composition $\sigma \circ \gamma$ is defined so that applying the composed substitution to a type has the same effect as **first applying $\gamma$ and then $\sigma$**:

$$
(\sigma \circ \gamma)(S) = \sigma(\gamma(S)).
$$

Mathematically, composition of substitutions is defined through the union of mappings. However, in implementation we use **left-biased shadowing**: when both substitutions map the same variable, the left substitution takes precedence. This reflects the way unification works in practice — new constraints always refine or replace older ones.

Formally, the composed substitution is defined as:

$$
\sigma \circ \gamma = \{ X \mapsto \sigma(T) \mid (X \mapsto T) \in \gamma \} \cup \sigma
$$

where the union is **left-biased**: bindings in $\sigma$ shadow any conflicting bindings from the transformed $\gamma$.

Thus:

* For each $(X \mapsto T) \in \gamma$, we apply $\sigma$ to get $X \mapsto \sigma(T)$;
* We then add all bindings from $\sigma$;
* If $X$ appears in both, the binding from $\sigma$ takes precedence (left-biased override).

This definition crucially relies on the simultaneity of substitution application discussed earlier.

### Example 1

Let

$$
\gamma = \{ \; ?x \mapsto ?y \to ?y \; \},
\qquad
\sigma = \{ \; ?y \mapsto \mathrm{Bool} \; \}.
$$

Then

$$
\sigma \circ \gamma = \{ \; ?x \mapsto \mathrm{Bool} \to \mathrm{Bool}, \; ?y \mapsto \mathrm{Bool} \; \}.
$$

Indeed:

$$
(\sigma \circ \gamma)(?x) = \sigma(?y \to ?y) = \mathrm{Bool} \to \mathrm{Bool}.
$$

### Example 2 (Non-Commutativity)

With the same substitutions:

$$
\gamma \circ \sigma = \{ \; ?y \mapsto \mathrm{Bool},\; ?x \mapsto ?y \to ?y \; \}.
$$

Now:

$$
(\gamma \circ \sigma)(?x) = \gamma(?y \to ?y) = ?y \to ?y,
$$

which clearly differs from the previous result. Hence,

$$
\sigma \circ \gamma \neq \gamma \circ \sigma.
$$

Composition of substitutions is therefore **not commutative**, and the order of composition carries semantic meaning.

### Example 3 (Left-Biased Shadowing)

Consider:

$$
\sigma = \{ \; ?x \mapsto \mathrm{Int} \; \},
\qquad
\gamma = \{ \; ?x \mapsto \mathrm{Bool},\; ?y \mapsto ?x \; \}.
$$

Then

$$
\sigma \circ \gamma = \{ \; ?x \mapsto \mathrm{Int}, \; ?y \mapsto \mathrm{Int} \; \}.
$$

Here:
* From $\gamma$, we get $?y \mapsto \sigma(\gamma(?y)) = \sigma(?x) = \mathrm{Int}$
* From $\gamma$, we would also get $?x \mapsto \sigma(\mathrm{Bool}) = \mathrm{Bool}$
* But $\sigma$ contains $?x \mapsto \mathrm{Int}$, which **shadows** the transformed binding from $\gamma$

This demonstrates the left-biased nature: $\sigma$'s bindings take precedence.

## Occurs Check

Consider the substitution

$$
\{ \; ?x \mapsto (?x \to \mathrm{int}) \; \}.
$$

Here the variable $?x$ is mapped to a type that already contains $?x$. Applying such a substitution leads to infinite expansion:

$$
\begin{aligned}
\sigma(?x)
&= \sigma(?x \to \mathrm{int}) \\
&= \sigma(?x) \to \mathrm{int} \\
&= \dots
\end{aligned}
$$

Such substitutions are **cyclic** and must be rejected.


## Implementation

Let us now move on to implementing substitutions in Zig. We start with the core data structure:

{% highlight zig linenos %}
pub const Sub = struct {
    map: std.AutoArrayHashMapUnmanaged(TyVar, Type),

    pub fn empty() Sub {
        return .{ .map = .empty };
    }

    pub fn one(tv: TyVar, ty: Type, alloc: std.mem.Allocator) !Sub {
        var map: std.AutoArrayHashMapUnmanaged(TyVar, Type) = .empty;
        try map.put(alloc, tv, ty);
        return .{ .map = map };
    }
};
{% endhighlight %}

We use a hash map to store mappings from type variables to types.
The `empty()` method creates an empty substitution, while `one()` creates a singleton substitution.

Basic operations include inserting mappings and querying them:

{% highlight zig linenos %}
pub fn put(self: *Sub, tv: TyVar, ty: Type, alloc: std.mem.Allocator) !void {
    try self.map.put(alloc, tv, ty);
}

pub fn get(self: *const Sub, tv: TyVar) ?*const Type {
    return self.map.getPtr(tv);
}

pub fn contains(self: *const Sub, tv: TyVar) bool {
    return self.map.contains(tv);
}

pub fn deinit(self: *Sub, alloc: std.mem.Allocator) void {
    self.map.deinit(alloc);
}
{% endhighlight %}

Debug formatting:

{% highlight zig linenos %}
pub fn format(self: *const Sub, w: anytype) !void {
    var it = self.map.iterator();
    var first = true;
    try w.writeAll("{ ");
    while (it.next()) |entry| {
        if (!first) {
            try w.writeAll(", ");
        }
        first = false;

        try w.print("?{} ↦ ", .{entry.key_ptr.*.id});
        try entry.value_ptr.*.format(w);
    }
    try w.writeAll(" }");
}
{% endhighlight %}

## Applying a Substitution to Types

Next, we add a method to the `Type` structure to apply a substitution:

{% highlight zig linenos %}
// NOTE: With ArenaAllocator, allocations are batched and freed together
pub fn apply(
    ty: *const Type,
    subst: *const Sub,
    alloc: std.mem.Allocator,
) !Type {
    return switch (ty.*) {
        .tvar => |tv| {
            if (subst.get(tv)) |replacement| {
                return replacement.*;
            } else {
                return ty.*;
            }
        },
        .tcon => ty.*,
        .tgen => ty.*,
        .tapp => |app| {
            const l = try apply(app.left, subst, alloc);
            const r = try apply(app.right, subst, alloc);
            return Type.typeappAlloc(l, r, alloc);
        },
    };
}
{% endhighlight %}

The logic is straightforward:

* For a type variable, look up a replacement in the substitution
* For a type constructor, return it unchanged
* For a type application, recursively apply the substitution to both parts

## Composition of Substitutions

Composition is the key operation that allows multiple substitutions to be applied sequentially. The implementation closely follows the mathematical definition:

{% highlight zig linenos %}
var acc: Sub = .{ .map = .empty };
var it = other.map.iterator();
while (it.next()) |entry| {
    const tv = entry.key_ptr.*;
    const ty = entry.value_ptr.*;
    const new_ty = try ty.apply(self, allocator);
    try acc.map.put(allocator, tv, new_ty);
}
it = self.map.iterator();
while (it.next()) |entry| {
    try acc.map.put(
        allocator,
        entry.key_ptr.*,
        entry.value_ptr.*,
    );
}
return acc;
{% endhighlight %}

The algorithm works in two phases:

1. Apply the first substitution (`self`) to all types in the second substitution (`other`)
2. Add all mappings from the first substitution, overriding if necessary

---

## Example Usage

Let us consider a practical example demonstrating substitution composition.

This example uses `std.heap.ArenaAllocator`, a region-based allocator where all allocations are performed from a single arena and freed together. Individual objects are not deallocated separately; instead, the entire arena is released at once when it goes out of scope.

Arena allocation is appropriate here because kinds and types form immutable, tree-shaped structures with uniform, phase-bounded lifetimes. Operations such as type application and substitution produce many short-lived intermediate nodes and rely on stable pointers and structural sharing. Using an arena eliminates per-object deallocation, simplifies ownership concerns, and provides predictable performance and memory behavior aligned with compiler-style, functional designs.

{% highlight zig linenos %}
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();
const alloc = arena.allocator();

// --- Kind: * ---
const kstar: Kind = .star;

const kstar_ptr = try alloc.create(Kind);
kstar_ptr.* = Kind.star;
const kstarstar = Kind{ .kfun = .{ .left = kstar_ptr, .right = kstar_ptr } };

// --- Type variables ---
const a = TyVar{ .id = 0, .kind = kstarstar }; // a :: * -> *
const b = TyVar.star(1); // b :: *
const c = TyVar.star(2); // c :: *

// --- Type constructors ---
const tInt = Type.typecon("Int", kstar);
const tBool = Type.typecon("Bool", kstar);

// --- Build type: (a b)
const a_ty = Type.typevar(a.id, a.kind);
const b_ty = Type.typevar(b.id, b.kind);

var app = try Type.typeappAlloc(a_ty, b_ty, alloc);

std.debug.print("Original type: ", .{});
std.debug.print("{f}\n", .{app});

// --- Substitution s1 = [ a ↦ Int ]
var s1 = try Sub.one(a, tInt, alloc);

// --- Apply s1 to type
const app1 = try Type.apply(&app, &s1, alloc);

std.debug.print("After applying s1 (a ↦ Int): {f}\n", .{app1});

// --- Substitution s2 = [ b ↦ Bool ]
var s2 = try Sub.one(b, tBool, alloc);

// --- Compose substitutions: s = s2 ∘ s1
// Meaning: first apply s1, then s2
var s = try s2.compose(&s1, alloc);

std.debug.print("Composed substitution:\n", .{});
s.print();

// --- Apply composed substitution to original type
const app2 = try Type.apply(&app, &s, alloc);

std.debug.print("After applying composed substitution: {f}\n", .{app2});

// --- Sanity check: unused variable
std.debug.print(
    "Contains c? {any}\n",
    .{s.contains(c)},
);
{% endhighlight %}

Running the program produces the expected output:

```
Original type: (TVar(0) TVar(1))
After applying s1 (a ↦ Int): (Int TVar(1))
Composed substitution { ?0 ↦ Int, ?1 ↦ Bool }:
After applying composed substitution: (Int Bool)
Contains c? false
```

As we can see, composition correctly applies both substitutions in sequence, transforming the abstract type `(a b)` into the concrete type `(Int Bool)`.

---

## Conclusion

In this part, we examined the fundamental concept of **type substitution** and implemented it in Zig. Substitution is not merely a technical detail -- it is the central mechanism that allows a type inference system to accumulate and apply knowledge about expression types.

We covered:

* The formal definition of substitution as a mapping from type variables to types
* Composition of substitutions and its role in type inference algorithms
* The problem of cyclic substitutions and the necessity of the occurs check

In the next part, we will move on to the **unification algorithm** -- the mechanism that uses substitutions to solve type equations and forms the core of the **Hindley–Milner** type inference system.

Thank you all for your attention 🙂

> **Full source code** of this part available at [gist](https://gist.github.com/qnbhd/84b624d5f84dc260bba47bb458eb47aa)
{: .prompt-tip }

---
title: Type inference
author: Templin Konstantin
category: programming
layout: post
---


# Introduction

In this article, I want to write how type inference works in programming languages, as well as write the simplest implementation. And I want to start with the concept of semantics of programming languages. In simple terms, semantics is a concept that explains the semantic meaning of programming language constructs and how they behave.

There are two types of semantics: **dynamic** and **static**.

- The dynamic properties of a program can generally be determined only by executing the program.  
- Static properties can be determined without executing the program. Unlike a dynamic property, a static property must be independent of the specific values of the arguments with which the parameterized program is invoked.

A static property can be determined during analysis, i.e. when a program is analyzed before execution. In many implementations, program analysis is performed by the compiler, and in this case it occurs during compilation. However, a program can be analyzed without compiling it (i.e., translating it into another, usually lower-level language), so we generally distinguish between these two points in time.

For example, consider the following pseudocode function:

```zig
pub fn fact(n) {
    if (n <= 1) {
        return 1;
    }
    return n * fact(n - 1);
}
```
  
What can we say about this program? We assume that the input for this function is a certain number. The result of this program is a dynamic property, since we do not know in advance what input the user will provide.

However, there are many static properties of this program that can be determined before launching. For example, we know that the function has some parameter `n` on which operations `<=`, `*`, `-` can be performed. The result of executing this function will be some non-negative integer. Also, by analyzing it, you can determine that the program is guaranteed to end.

In general, we are interested in static properties that help with program verification, optimization, and documentation. For example, I would like to ask the following questions about the program:

* does the program comply with the specified specification?
* can a program encounter a certain erroneous situation?
* is it guaranteed during the execution of the program that some variable will contain a value consistent with the declared type?
* is it possible to optimize the program in one way or another without changing its meaning?

Of course, there are issues that cannot be solved in a general way. **"Does this program stop?"** — the most famous example of an unsolvable problem. However, unsolvability does not mean that the task of determining static properties is hopeless. 


# Type inference

In the context of programming language design, as a rule, the following tasks are:

1. **Type checking:** is it true that a given term is of type $$T$$?
2. **Type inference:** is there some type environment and type $$T$$ such that the term $$M$$ has type $$T$$?


### **... to be done ...**

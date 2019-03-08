# Introduction

## Overview

*Miletus* is a financial contract definition, modeling language, and valuation framework written in Julia.  The implementation of the contract definition language is based on papers by Peyton Jones and Eber [[PJ&E2000]](http://research.microsoft.com/en-us/um/people/simonpj/Papers/financial-contracts/contracts-icfp.htm),[[PJ&E2003]](http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.14.7885).

As originally conceived in the referenced papers, complex financial contracts can often be deconstructed into combinations of a few simple primitive components and operations.   When viewed through the lens of functional programming, this basic set of primitive objects and operations form a set of "combinators" that can be used in the construction of more complex financial constructs.

Miletus provides both basic the primitives for the construction of financial contract payoffs as well as a decoupled set of valuation model routines that can be applied to various combinations of contract primitives.  In Miletus, these "combinators" are implemented through the use of Julia's *user-defined types*, *generic programming*, and *multiple dispatch* capabilities.

Unlike some existing implementations of financial contract modeling environments (created in languages such as Haskell or OCaml) that rely heavily on pure functional programming for the contract definition language, but may then switch to a second language (e.g. C++, Java, APL) for implementation of valuation processes, Miletus leverages Julia's strong type system and multiple dispatch capabilities to both express these contract primitive constructs and provide for generation of efficient valuation code.  As seen in other parts of the Julia ecosystem, Miletus solves the two language problem with regards to defining and modeling financial contracts.

Miletus provides functionality for teams across an organization, both front office and back office, to use a common language for structuring, valuing and managing complex financial instruments.  Whether a sales team needs to structure new products, an operations team deploying infrastructure for batch processing, a risk management team must determine exposure of a firm's portfolio, or regulators are evaluating capital requirements for solvency, Miletus allows for everyone to use the same language effectively and efficiently.

## Installation

Installation of Miletus can be performed by obtaining an installer from Julia Computing as part of your JuliaFin purchase.

Once installed, to load the Miletus package in your current Julia session, use the following command:

```@example
using Miletus
```

At this point you can use any of the primitive Miletus types for defining new contracts, constructing and manipulating either your own contracts or a set of pre-existing option contracts included with Miletus, as well as executing valuation operations against any combination of built-in and user-defined primitives that comprise your contract.

# ctfs
compile-time function synthesis in D

# introduction

This project is a partial implementation of the functional program synthesis algorithm in [Chaudhuri et al. 2015][1] in the D programming language.

The implementation presented is a template library which uses D's static type system to synthesize functions out of input/output examples during compilation. This demonstrates a library-based synthesizer in a commercial programming language. In practice, the reference compiler (dmd) is not well-suited to the task, and can only solve rudimentary problems before exhausting the computer's resources and failing.

The use of an in-language solution is appealing for a number of reasons, such as: Much of the labor involved (type deduction, symbol lookup, ...) can be offloaded to the compiler. The functions that are synthesized can be used immediately at their point of declaration. The solver is able to make uninhibited use of the reflective capabilities of the target language.

# the algorithm

From a high level, the solver takes a set of input/output examples along with a set of functions (the basis) and a set of typed arguments, and builds expression trees linked by function application. Many of the trees are incomplete, and contain typed holes in place of expressions. The solver attempts to complete the trees by substituting type-consistent elements of the basis in for the hole.

A complete tree with no holes is evaluated against the input/output examples. If it is consistent (i.e. if it satisfies the examples) then it is declared the solution. The candidate trees are prioritized according to a cost function whose weights have significant impact on the performance of the solver.

The algorithm is given in further detail in [the paper][1]. This implementation performs the enumerative, type-driven search and hypothesis generation, but does not include the application of combinators and the inference of new synthesis subproblems.

# an example

A synthesis problem is given by

```d
Synthesis!(
	MList!(AMap!(Func,
		zero, one,
		neg, add
	)),
	MList!(AMap!(MValue,
		t_(0,0, 0),
		t_(5,4, 1),
		t_(1,3, -2),
	))
);
```

where `zero() = 0`, `one() = 1`, `neg(x) = -x` and `add(x,y) = x+y` is the basis, and the triples `t_(a,b, c)` represent examples with input `(a,b)` and output `c`.

The basis is constructed by turning the basis functions into expression trees by placing holes for each of a function's arguments, and adding placeholder tokens representing the arguments of the function to be synthesized (in this case, two `int`s).
The solver maintains a priority queue of candidate trees which initially contains a single tree with a single hole of codomain `int` and domain unknown. The queue is sorted according to a cost function which assigns numerical costs to candidate trees.
Then, until the problem is found or all possible programs have been exhausted, the solver proceeds like so:

The lowest-cost candidate in the queue is selected. If it is complete (i.e. has no holes) then it is evaluated against the examples. If it contains a hole, then that first hole will be filled in by each element of the basis with a matching codomain, each corresponding to a new candidate expression tree which is placed into the queue.
Since the first candidate in this example is just a hole of type `int`, the solver adds the entire basis to the queue and completes this step.

The next step looks at the lowest-cost candidate tree on the queue, which will be either the `zero` or `one` constant functions by themselves. Since they are complete, they will be tested against the input/output examples. Specifically, if `zero` is selected, then the function `(a,b) => 0` is constructed and tested for consistency. It fails, and the solver continues.
On the other hand, the next tree may consist of one of the argument tokens. In this case, without loss of generality, the resulting function has the form `(a,b) => a`. This is also inconsistent with the input/output examples, and is discarded.

Eventually the solver will encounter the `add(?,?)` expression tree. From this, the candidates `add(0,?)`, `add(1,?)`, `add(neg(?),?)` and so forth. This leads to the eventual evaluation of `(a,b) => add(neg(b), a)`, which passes the consistency checks and is selected as the solution.

# results and remarks

The solver is able to synthesize only basic functions before exhausting the operating system's resources. This is due to the heavy memory consumption of compile-time computations in dmd, and the lack of control the programmer has over the way the compiler uses those resources. Because the solver is implemented within the D type system, the results of most computations are expressed as parameterized type definitions. The algorithm, including the priority queue and the hole substitution,  must be implemented in a stateless, purely functional way. While dmd memoizes the results of compile-time calculations, it is certainly not optimized for the synthesis solver.

The synthesis of subtraction as detailed in the example takes anywhere between 4 seconds and 45 seconds to complete, depending on the weights assigned in the cost function. The synthesis of a more complicated function, `(a,b,c) => b+c-a`, overwhelms a system with 12GB of RAM and does not complete.

The performance of such an algorithm in general is determined by the cost function, which defines a strategy for the traversal of the program search space. The vastness of the space makes exhaustive searches infeasible, and any practical algorithm must cull as much of the space as early as possible, while intelligently prioritizing the rest.

The best performing weight assignment for this algorithm penalized deep trees heavily, while assigning a small cost to holes and no cost to constant functions and argument application. This cut the runtime for subtraction down from about 45 seconds for a cost function which did not especially penalize tree depth to about 4 seconds. That an order of magnitude improvement is possible with a small modification to numerical weights is promising, and suggests that performant methods of traversing the space can be found.

Because the expression trees are compositional by nature, it is possible to break the synthesis problem down into subproblems as in [the paper][1]. This can further reduce the size of the candidate search space by decomposing the original problem. Search techniques intended for decomposable problems, such as dynamic programming and genetic recombination, may be effective as well.

Despite the appeal of a compile-time library-based solution, a synthesizer that co-opts the dmd compiler is practically useless at the time of this report due to the extreme memory consumption of template instantiation and compile-time function evaluation. Perhaps this will change over time with further compiler development, or a more metaprogramming-oriented language will emerge to support this kind of algorithm more directly. Until then, a custom language or runtime source-code generator is likely the only feasible method for synthesizing programs within reasonable resource constraints.

[1]: http://www.cs.rice.edu/~sc40/pubs/pldi15.pdf

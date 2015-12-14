import metastruct;
import aliastuple;

import std.typecons:
	Tuple,
	t_ = tuple;

import exprtree;

// utility functions for computing cost
enum Sum() = 0;
enum Sum(Xs...) = Xs[0] + Sum!(Xs[1..$]);

enum argCost = 0.0;
enum funcBaseCost = 1.0;
enum funcArgScale = 0.7;
enum holeCost = 1.05;

// the cost function
template cost(X)
if(isMTree!X)
{
	static if(isArg!(X.Root))
	{
		enum cost = argCost;
	}
	else static if(isFunc!(X.Root))
	{
		enum cost = funcBaseCost
			+ funcArgScale * Sum!(
				AMap!(.cost,
					X.Branches
						.Expand
				)
			);
	}
	else static if(isHole!(X.Root))
	{
		enum cost = holeCost;
	}
	else static assert(0);
}
// cost comparison predicate
enum lessOrEqualCost(A,B) = cost!A <= cost!B;

// a cost-sorted priority queue
alias HypQueue = MHeap!lessOrEqualCost;

/*
	HYPOTHESIS GENERATION
*/
template Hypos(Prog, L)
if(
	isMTree!Prog
	&& isMList!L
)
{
	/*
		begin the search with a base case
		of no searched exprs
		and one unsearched expr
		consisting of the entire program
	*/
	alias Hypos
	= Map!(Flat, Search!(
		Nil, MList!(Prog)
	));

	alias Flat(L) = L.Expand;

	alias Search(_,
		Unsearched : Nil
	) = Nil;
	template Search(
		Searched,
		Unsearched
	)
	{
		alias Expr = Unsearched.Head;
		alias Rem = Unsearched.Tail;

		alias Op = Expr.Root;
		alias Args = Expr.Branches;

		alias RebuildFrom(
			NewArgs
		)
		= Substitute!(
			MTree!(
				Op,
				NewArgs
			)
		);

		alias Substitute(
			NewExpr
		) 
		= MConcat!(
			Searched,
			Cons!(
				NewExpr,
				Rem
			)
		);

		template nilArgsAssert()
		{
			static assert(is(Args == Nil),
				"cannot have "
				~ Op.stringof ~ 
				" with args "
				~ Args.stringof
			);
		}

		static if(isFunc!Op)
		{
			/*
				DFS on the arg exprs
			*/
			alias SubResult 
			= Search!(
				Nil, Args
			);

			static if(is(SubResult == Nil))
				/*
					no hole, search the next expr
					so if its nil, we will be nil too
					and together signal a negative result
					if we are out of exprs at this level,
					this call will return nil
				*/
				alias Search = Search!(
					MAppend!(
						Expr,
						Searched
					),
					Rem
				);
			else 
				/*
					we found a hole
					subresult is a list of lists of subexpr
					the outermost list can be through of as
						containing the threads of construction
						of the candidate programs
						(i.e. either lists of args,
							or one-element lists of bound ops
						)
					each innermost list contains 
						subexpr for the current expr
						one of which was or contained the filled hole
						but is now occupied by a codomain-consistent guess

					so for each innermost list of hypothesis subexprs,
						we will bind them to the current op
						to produce a list of one-element lists
							of exprs
				*/
				alias Search 
				= Map!(RebuildFrom,
					SubResult
				);
		}
		else static if(isHole!Op)
		{
			alias verify = nilArgsAssert!();

			/*
				this is a hole
				signal a positive result by returning
					a list of copies of the arg list 
					with the first hole replaced
					with each codomain-matching
					language primitive
			*/
			alias Search 
			= Map!(Substitute,
				Filter!(codMatch, L)
			);

			enum codMatch(Candidate) = is(
				Candidate.Root.Codomain 
				== Op.Codomain
			);
		}
		else static if(isArg!Op)
		{
			alias verify = nilArgsAssert!();

			alias Search = Nil;
		}
		else static assert(0);
	}
}

// a synthesis problem, parameterized by a language La and evidence Ev.
template Synthesis(
	Lang,
	Examples
)
if(
	isMList!Lang
	&& isMList!Examples
)
{
	alias solution() = soln!(
		HypQueue.Push!(
			TrivHyp!(
				Codomain
			)
		)
	);

	alias toFunction() 
	= compile!(
		solution!(), Domain
	);

	alias TrivHyp(
		Cod
	) 
	= MTree!(
		Hole!(Cod),
		Nil
	);

	template soln(Q : HypQueue)
	{}
	template soln(Q)
	{
		alias H = Q.Top;

		static if(isClosed!H)
		{
			alias h = compile!(H, Domain);

			static if(isConsistent!h)
				alias soln = H;
			else
			{
				static if(is(Q == MHeap!(f,L),
					alias f, L
				)){}

				alias soln = soln!(
					Q.Pop!()
				);
			}
		}
		else
		{
			alias Hyps
			= Hypos!(
				H,
				Prim
			); 
			// BUG we never seem to try hypothesis with arguments and yet we just did this in some other file....
			
			static if(is(
				Hyps == Nil
			))
				alias soln = soln!(
					Q.Pop!()
				);
			else
				alias soln = soln!(
					Foldr!(
						Insert,
						Q.Pop!(),
						Hyps
					)
				);

			alias Insert(
				Hyp,
				Queue
			) = Queue.Push!Hyp;
		}
	}

	template isConsistent(alias f)
	{
		enum check(E) 
			= f(E.value[0..$-1])
				== E.value[$-1];

		enum isConsistent
			= All!(check, Examples);
	}

	alias Prim = MConcat!(
		Map!(argExprAt,
			Iota!(
				Domain.length
			)
		),
		Map!(toPrimitive,
			Lang
		)
	);

	alias argExprAt(Index) 
	= MTree!(
		Arg!(
			Index.value,
			Domain[Index.value]
		),
		Nil
	);

	alias toPrimitive(Term)
	= MTree!(
		Term,
		Map!(TrivHyp, MList!(
			Term.Domain
		))
	);

	alias Domain  
	= Examples.Head.Type
		.Types[0..$-1];

	alias Codomain
	= Examples.Head.Type
		.Types[$-1];
}

template isClosed(X)
if(isMTree!X)
{
	static if(isHole!(X.Root))
		enum isClosed = false;
	else static if(isArg!(X.Root))
		enum isClosed = true;
	else static if(isFunc!(X.Root))
		enum isClosed = All!(
			.isClosed,
			X.Branches
		);
	else static assert(0);
}

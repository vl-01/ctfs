module exprtree;

import aliastuple;
import metastruct;

import std.conv: to;
import std.traits:
	DomainOf = ParameterTypeTuple,
	CodomainOf = ReturnType,
	isFunction = isSomeFunction;
import std.typetuple:
	Uniq = NoDuplicates;

alias max = Alias!(
	(a,b) => a > b? a : b
);

/*
	PRIMITIVES
*/
struct Func(alias f)
{
	alias op = f;
	alias Domain = DomainOf!f;
	alias Codomain = CodomainOf!f;
}
struct Hole(Cod)
{
	alias Codomain = Cod;
}
struct Arg(uint idx, Cod)
{
	alias Domain = Unit;
	alias Codomain = Cod;
	alias index = idx;
}
enum isFunc(F) = is(F == Func!f, alias f);
enum isHole(H) = is(H == Hole!T, T);
enum isArg(A) = is(A == Arg!(i,T), uint i, T);

/*
	PRINTING
*/
template toSource(T)
if(isMTree!T)
{
	static if(isFunc!(T.Root))
	{
		enum toSource
			= __traits(identifier,
				T.Root.op
			) 
			~ toSource!(T.Branches);
	}
	else static if(isHole!(T.Root))
	{
		enum toSource
			= "?";
	}
	else static if(isArg!(T.Root))
	{
		enum toSource
		= `_` ~ T.Root.index.to!string;
	}
	else static assert(0);
}
template toSource(L)
if(isMList!L)
{
	enum toSource
		= "(" 
		~ Foldr!(MConcat,
			MString!"",
			Map!(
				withDelim,
				L,
			)
		).stringof[
			0..max(
				long($)-2,
				0
			)
		] ~ ")";

	alias withDelim(U)
		= MConcat!(
			toMSource!(U),
			MString!", "
		);
}
alias toMSource(T) 
	= MString!(toSource!T);

/*
	COMPILATION
*/
template compile(X, Domain...)
{
	static assert(isMTree!X);

	alias Cod = X.Root.Codomain;

	Cod compile(Domain args)
	{
		Domain[i] arg(uint i)()
		{
			return args[i];
		}

		Y.Root.Codomain reduce(Y)()
		{
			static if(isFunc!(Y.Root))
			{
				alias f = Y.Root.op;
				alias Sub = Y.Branches;

				static if(isFunction!f)
					return f(
						AMap!(reduce, 
							Sub.Expand
						)
					);
				else return f;
			}
			else static if(isArg!(Y.Root))
			{
				return arg!(Y.Root.index);
			}
			else static assert(0);
		}

		return reduce!X;
	}
}
template Args(X)
if(isMTree!X)
{
	enum leastIndex(A,B) 
	= A.index < B.index;

	alias Expr = X.Root;
	alias Sub = X.Branches;

	static if(isArg!(Expr))
	{
		alias Args = Expr;
	}
	else static if(isFunc!(Expr))
	{
		alias Args = Uniq!(
			SortBy!(leastIndex,
				AMap!(.Args, Sub.Expand)
			)
		);

		alias index(A) = A.index;
		alias ns = AMap!(index, Args);

		static assert([Uniq!ns] == [ns],
			`contradictory argument declarations: ` ~ Args.stringof
		);
	}
	else static assert(0);
}

/*
	EXAMPLES
*/
//////////////////////////////
int f()
{
	return 42;
}
int g(int a, int b)
{
	return a + b;
}

unittest
{
	alias L = MList!(
		MTree!(Func!f, Nil),
		MTree!(Func!g, MList!(
			MTree!(Hole!(int), Nil),
			MTree!(Hole!(int), Nil),
		))
	);

	alias X1 = MTree!(Hole!(int), Nil);
	alias H1 = Hypos!(X1,L);

	alias H2 = Hypos!(H1.Head,L);

	alias H3 = Hypos!(H1.Tail.Head,L);

	alias H4 = Hypos!(H3.Head,L);

	alias H5 = Hypos!(H4.Tail.Head,L);

	alias F = MTree!(
		Func!g, MList!(
			MTree!(
				Arg!(0,int),
				Nil
			),
			MTree!(
				Func!(() => 1),
				Nil
			)
		)
	);

	pragma(msg, "\n");
	pragma(msg, toSource!F);

	pragma(msg, compile!F(6));
}

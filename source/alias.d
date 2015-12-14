module aliastuple;

/*
	This module contains "A templates"; i.e.
	templates for operating on bare aliases.
	Aliases can be types, values, or symbols.
	Tuples of aliases automatically flatten.
	In other words, lots of power, very little structure.
	Use sparingly and wrap in M templates when possible.
*/

alias Alias(A...) = A[0];
alias ATuple(A...) = A;

alias Empty = ATuple!();
alias Unit = Empty;

alias AMap(alias F) = Empty;
alias AMap(alias F, A...)
= ATuple!(
	F!(A[0]),
	AMap!(F, A[1..$])
);

alias AFilter(alias F) = Empty;
template AFilter(alias F, A...)
{
	static if(F!(A[0]))
		alias AFilter 
		= ATuple!(
			A[0], AFilter!(F, A[1..$])
		);
	else
		alias AFilter 
		= AFilter!(F, A[1..$]);
}
	
template Not(alias pred)
{
	enum Not(T...) = !(pred!T);
}
template SortBy(alias compare, T...)
{
	static if(T.length > 1)
	{
		alias Remaining = ATuple!(
			T[0..$/2],
			T[$/2 +1..$]
		);

		enum is_before(U...) 
		= compare!(U[0], T[$/2]);

		alias SortBy = ATuple!(
			SortBy!(
				compare,
				AFilter!(is_before,
					Remaining
				)
			),
			T[$/2],
			SortBy!(
				compare, 
				AFilter!(Not!is_before,
					Remaining
				)
			),
		);
	}
	else alias SortBy = T;
}

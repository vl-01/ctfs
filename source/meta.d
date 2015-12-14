module metastruct;

import aliastuple;

/*
	This module contains M templates,
	which operate on meta data structures
	parameterized by types.

	Non-type information (numbers, strings)
	can be wrapped in M templates to make them
	elegible to be operated on by M templates.
*/

public {//value
	struct MValue(V...)
	if(V.length == 1)
	{
		enum value = V[0];
		alias Type = typeof(value);
	}
}
public {//list
	struct Cons(H,T)
	{
		static assert(isMList!T);

		alias Head = H;
		alias Tail = T;

		alias Expand 
			= ATuple!(H, T.Expand);

		enum stringof
			= H.stringof ~ ", "
				~T.stringof;
	}
	struct Nil
	{
		alias Expand 
			= ATuple!();
		
		enum stringof 
			= Expand.stringof;
	}
	alias MList(A...) = Cons!(A[0], MList!(A[1..$]));
	alias MList() = Nil;
	enum isMList(L) 
		= is(L == Nil)
		|| is(L == Cons!(H,T), H,T);

	template MConcat(L0,L1)
	if(isMList!L0 && isMList!L1)
	{
		alias MConcat
			= MList!(
				L0.Expand,
				L1.Expand
			);
	}
	template MAppend(A,L)
	if(isMList!L)
	{
		alias MAppend = MConcat!(
			L, MList!A
		);
	}
	alias Foldl(alias F, E, L : Nil) = E;
	template Foldl(alias F, E, L)
	{
		static assert(isMList!L);

		alias X = L.Head;
		alias Y = L.Tail;

		alias Foldl = Foldl!(
			F, F!(E,X), Y
		);
	}
	alias Foldr(alias F, E, L : Nil) = E;
	template Foldr(alias F, E, L)
	{
		static assert(isMList!L);

		alias X = L.Head;
		alias Y = L.Tail;

		alias Foldr = F!(
			X, Foldr!(F,E,Y)
		);
	}
	template Map(alias F, L)
	{
		alias Map = Foldr!(
			G, Nil, L 
		);

		alias G(A,Bs) = Cons!(F!A,Bs);
	}
	template Filter(alias P, L)
	{
		alias Filter = Foldr!(
			F, Nil, L 
		);

		template F(A,As)
		{
			static if (P!A)
				alias F = Cons!(A,As);
			else
				alias F = As;
		}
	}
	enum All(alias P, L) = is(Filter!(P,L) == L);

	alias Iota(uint n : 0) = Nil;
	alias Iota(uint n) 
	= MAppend!(
		MValue!(n-1),
		Iota!(n-1)
	);
}
public {//string
	struct MString(string str)
	{
		enum stringof = str;
	}
	enum isMString(S)
		= is(S == MString!str,
			string str
		);
	template MConcat(S0,S1)
	if(
		isMString!S0
		&& isMString!S1
	)
	{
		alias MConcat
			= MString!(
				S0.stringof
				~ S1.stringof
			);
	}
}
public {//tree
	struct MTree(R,B) 
	{
		static assert(isMList!B);
		static assert(All!(isMTree, B));

		alias Root = R;
		alias Branches = B;

		enum stringof
			= R.stringof ~ ` <- [`
			~ B.stringof ~ `]`;
	}
	enum isMTree(T) = is(T == MTree!(R,B), R,B);
}
public {//heap
	alias MHeap(alias comp) 
	= MHeap!(comp, Nil);

	template MHeap(alias comp, List)
	if(isMList!List)
	{
		struct MHeap
		{
			static if(is(List == Nil))
				struct Empty {}
			else
				alias Top = List.Head;

			template Pop()
			{
				alias Pop
				= .MHeap!(comp,
					heapify!(comp,
						List.Tail
					)
				);
			}

			template Push(Item)
			{
				alias Push 
				= .MHeap!(comp,
					heapify!(comp,
						MAppend!(
							Item,
							List,
						)
					)
				);
			}
		}

		// TEMP BUG we are violating heapness somewhere
		//static assert(isHeap!(comp, List));
	}
			
	private
	{
		enum left(int k) = 2*k;
		enum right(int k) = 2*k+1;
		enum back(int k) = k/2;

		struct Root{}

		template Swap(int i, int j, L)
		if(isMList!L)
		{
			alias M = L.Expand;

			alias Swap = MList!(
				M[0..i], 
				M[j],
				M[i+1..j],
				M[i],
				M[j+1..$],
			);
		}

		template isHeap(alias comp, L)
		if(isMList!L)
		{
			// we will use 1-based indexing due to various conveniences we gain from making 0 a special element
			alias H = Cons!(Root, L).Expand;

			// value of each node is less than or equal to the value of its parent with min at root
			template hasHeapProperty(int i)
			{
				template check(alias child)
				{
					static if(child!i < H.length)
						enum check
							= comp!(H[i], H[child!i])
							&& hasHeapProperty!(child!i);
					else
						enum check = true;
				}

				enum hasHeapProperty
					= check!left && check!right;
			}

			alias isHeap = hasHeapProperty!1;
		}

		template heapify(alias comp, L : Nil)
		{
			alias heapify = Nil;
		}
		template heapify(alias comp, L)
		if(isMList!L)
		{
			alias heapify 
				= heapifyFrom!(
					comp,
					L.Expand.length-1,
					L
				);
		}
		template heapifyFrom(alias comp, int i, L)
		if(isMList!L)
		{
			alias L1 = Cons!(Root, L).Expand;

			enum j = i+1;
			enum k = back!j;

			static if(
				i > 0 && back!j > 0
			)
			{
				static if(
					!(comp!(L1[k], L1[j]))
				)
				{
					alias heapifyFrom 
						= heapifyFrom!(comp,
							k - 1,
							Swap!(k,j, MList!L1)
								.Tail
						);
				}
				else
				{
					alias heapifyFrom = L;
				}
			}
			else
			{
				alias heapifyFrom = L;
			}
		}
	}
	unittest
	{
		enum lte(A, B) = A.value <= B.value;
		alias H = MHeap!lte;

		alias one = MValue!1;
		alias two = MValue!2;
		alias three = MValue!3;
		alias four = MValue!4;

		alias H1 = H.Push!(three);
		alias H2 = H1.Push!(one);
		alias H3 = H2.Push!(two);
		alias H4 = H3.Push!(one);
		alias H5 = H4.Push!(four);
		alias H6 = H5.Push!(two);

		static assert(is(H1.Top == three));
		static assert(is(H2.Top == one));
		static assert(is(H3.Top == one));
		static assert(is(H4.Top == one));
		static assert(is(H5.Top == one));
		static assert(is(H6.Top == one));

		alias H7 = H6.Pop!();
		alias H8 = H7.Pop!();
		static assert(is(H8.Top == two));

		alias H9 = H8.Pop!();
		static assert(is(H9.Top == two));

		alias H10 = H9.Pop!();
		static assert(is(H10.Top == three));
	}
}

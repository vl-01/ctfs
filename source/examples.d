import aliastuple;
import metastruct;
import exprtree;
import synth;

/*
	Examples of synthesis problems
*/

/*
	We compose simple integer functions out of this basis
*/
int neg(int a){ return -a; }
int add(int a, int b){ return a+b; }
int zero(){ return 0; }
int one(){ return 1; }

/*
	This is a synthesis problem using zero and one as its basis 
	and the example f() = 0 to synthesize the constant function 0
*/
alias S0 = Synthesis!(
	MList!(AMap!(Func,
		zero, one
	)),
	MList!(AMap!(MValue,
		t_(0)
	))
);
static assert(is(S0.solution!()));
static assert(S0.toFunction!() == 0);

/*
	Using the same basis but with contradictory examples,
	the synthesis solver declares it impossible.
*/
alias S1 = Synthesis!(
	MList!(AMap!(Func,
		zero, one
	)),
	MList!(AMap!(MValue,
		t_(0),
		t_(1),
	))
);
static assert(!is(S1.solution!()));

/*
	The next example uses addition and unary negation
	to synthesize binary subtraction.
*/
alias S2 = Synthesis!(
	MList!(AMap!(Func,
		zero, one,
		neg, add
	)),
	MList!(AMap!(MValue,
		t_(0,0,	0),
		t_(5,4,	1),
		t_(1,3,	-2),
	))
);

/*
	The examples are consistent with the following reference function
*/
int sub(int a, int b){ return a - b; }
static assert(!(S2.isConsistent!(add)));
static assert(S2.isConsistent!(sub));

static assert(is(S2.solution!()));
static assert(S2.toFunction!()(6,8) == -2);

/*
	This problem cannot compile using DMD within 12Gb of memory 
	and does not complete.
*/
alias S3 = Synthesis!(
	MList!(AMap!(Func,
		zero, one,
		neg, add
	)),
	MList!(AMap!(MValue,
		t_(2,3,4, 5),
		t_(6,2,9, 5),
		t_(3,4,1, 2),
		t_(1,1,1, 1),
	))
);
int s3ref(int a, int b, int c){ return b + c - a; }
static assert(S3.isConsistent!(s3ref));

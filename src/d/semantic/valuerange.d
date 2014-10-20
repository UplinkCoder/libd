/**
* Copyright 2014 Stefan Koch
* This file is part of SDC.
* See LICENCE or sdc.d for more details.
*/
module d.semantic.valuerange;

import d.ast.expression;
import d.ir.expression;
import d.ir.type;
import d.semantic.semantic;

alias BinaryExpression = d.ir.expression.BinaryExpression;
alias UnaryExpression = d.ir.expression.UnaryExpression;

struct ValueRange {
	long _min = long.max;
	long _max = long.min;
	bool isSigned = true;

	this (long min, long max, bool isSigned) {
		this._min = min;
		this._max = max;
		this.isSigned = isSigned;
	}
	
	bool isInRangeOf(ValueRange that) {
		if ((!isSigned && that.isSigned) && (that._max != _max && that._min !=  _min)) {
			return false;
		} else {
			return that._max >= _max && that._min <= _min;
		}
	
	}
	
	ValueRange opBinary(string op)(ValueRange rhs) if (op == "+" || op == "-") {
		static if (op == "+") {
			return ValueRange(_min + rhs._min, _max + rhs._max, rhs._min < _min);
		} else static if (op == "-") {
			return  ValueRange(_min - rhs._max, _max - rhs._min, rhs._max > _min);
		}
	}

	unittest {
		assert(ValueRange(0, 255, false) - ValueRange(128, 128, false) == ValueRange(-128, 127,true));
		assert(ValueRange(255, 255, false) - ValueRange(128, 128, false) == ValueRange(127, 127,false));
		assert(ValueRange(0, 0, false) - ValueRange(128, 128, false) == ValueRange(-128, -128,true));
		assert(ValueRange(3, 3, false) + ValueRange(-5, 2, true) == ValueRange(-2, 5, true));
	}
	
}

struct ValueRangeVisitor {
	import std.conv:to;
	
	SemanticPass pass;
	
	this(SemanticPass pass) {
		this.pass = pass;
	}

	ValueRange visit(BuiltinType bt) in {
		assert(bt == BuiltinType.Bool || isIntegral(bt));
		// Overflow of ValueRanges is tricky, so for now it is disallowed
		assert(bt != BuiltinType.Ulong && bt != BuiltinType.Long,"VRP for longs and ulongs is not supported right now");
	} body {
		if (bt == BuiltinType.Bool) {
			return ValueRange(0, 1, false);
		}

		return ValueRange(getMin(bt), getMax(bt), isSigned(bt));
	}
	
	ValueRange visit(Expression e) {
		return this.dispatch(e);

	}
	
	ValueRange visit(VariableExpression e) {
		return visit(e.type.builtin);
	}
	
	ValueRange visit(UnaryExpression e) {
		ValueRange rhs = visit(e.expr);

		switch (e.op) with (UnaryOp) {
			import d.semantic.expression;
			case Minus :
				if (auto bt = e.expr.type.builtin) {
					import d.ir.type;
					if (isSigned(bt)) {
						return ValueRange(-rhs._max, -rhs._min, true);
					} else {
						return ValueRange(getMax(bt) - rhs._min, getMax(bt) - rhs._max, false);
					}
				}

				return ValueRange(0, 0, false) - rhs;
			default : 
				assert(0, "Operator " ~ to!string(e.op) ~ " is not supported by VRP right now");
		}
		assert(0);
	}
	
	ValueRange visit(BinaryExpression e) {
		ValueRange lhs = visit(e.lhs);
		ValueRange rhs = visit(e.rhs);
		switch (e.op) with (BinaryOp) {
			case Add :
				return lhs + rhs;
			case Sub :
				return lhs - rhs;
			default :
				assert(0, "Operator " ~ to!string(e.op) ~ " is not supported by VRP right now");

		}
		assert(0);
	}
	
	ValueRange visit(CastExpression e) {
		assert(e.type.builtin && e.expr.type.builtin);
		if (unsigned(e.type.builtin) > unsigned(e.expr.type.builtin)) {
			return visit(e.expr);
		} else {
			return visit(unsigned(e.type.builtin));
		}

	}
	
	ValueRange visit(BooleanLiteral e) {
		return ValueRange(e.value, e.value, false);
	}
	
	ValueRange visit(IntegerLiteral!false e) {
		if (e.value>getMax(BuiltinType.Long)) {
			return ValueRange(e.value, e.value, false);
		} else {
			return ValueRange(e.value, e.value, true);
		}
	}
	
	ValueRange visit(IntegerLiteral!true e) {
		return ValueRange(e.value, e.value, true);
	}

}

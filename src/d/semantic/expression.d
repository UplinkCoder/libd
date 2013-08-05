module d.semantic.expression;

import d.semantic.identifiable;
import d.semantic.semantic;
import d.semantic.typepromotion;

import d.ast.base;
import d.ast.declaration;
import d.ast.dfunction;
import d.ast.expression;
import d.ast.type;

import d.ir.expression;
import d.ir.symbol;
import d.ir.type;

import d.exception;

import std.algorithm;
import std.array;
import std.range;

alias BinaryExpression = d.ir.expression.BinaryExpression;
alias UnaryExpression = d.ir.expression.UnaryExpression;
alias CallExpression = d.ir.expression.CallExpression;
alias IndexExpression = d.ir.expression.IndexExpression;

alias PointerType = d.ir.type.PointerType;
alias SliceType = d.ir.type.SliceType;
alias ArrayType = d.ir.type.ArrayType;
alias FunctionType = d.ir.type.FunctionType;
alias DelegateType = d.ir.type.DelegateType;

final class ExpressionVisitor {
	private SemanticPass pass;
	alias pass this;
	
	this(SemanticPass pass) {
		this.pass = pass;
	}
	
	Expression visit(AstExpression e) {
		return this.dispatch(e);
	}
	
	Expression visit(ParenExpression e) {
		return visit(e.expr);
	}
	
	Expression visit(BooleanLiteral e) {
		return e;
	}
	
	Expression visit(IntegerLiteral!true e) {
		return e;
	}
	
	Expression visit(IntegerLiteral!false e) {
		return e;
	}
	
	Expression visit(FloatLiteral e) {
		return e;
	}
	
	Expression visit(CharacterLiteral e) {
		return e;
	}
	
	Expression visit(StringLiteral e) {
		return e;
	}
	
	Expression visit(AstBinaryExpression e) {
		auto lhs = visit(e.lhs);
		auto rhs = visit(e.rhs);
		auto op = e.op;
		
		QualType type;
		final switch(op) with(BinaryOp) {
			case Comma:
				type = rhs.type;
				break;
			
			case Assign :
				type = lhs.type;
				rhs = buildImplicitCast(rhs.location, type, rhs);
				break;
			
			case Add :
			case Sub :
				// TODO: pointer arythmetic here.
			
			case Mul :
			case Div :
			case Mod :
			case Pow :
				type = getPromotedType(e.location, lhs.type.type, rhs.type.type);
				
				lhs = buildImplicitCast(lhs.location, type, lhs);
				rhs = buildImplicitCast(rhs.location, type, rhs);
				
				break;
			
			case Concat :
			case AddAssign :
			case SubAssign :
			case ConcatAssign :
			case MulAssign :
			case DivAssign :
			case ModAssign :
			case PowAssign :
				assert(0, "Not implemented.");
			
			case LogicalOr :
			case LogicalAnd :
				type = getBuiltin(TypeKind.Bool);
				
				lhs = buildExplicitCast(lhs.location, type, lhs);
				rhs = buildExplicitCast(rhs.location, type, rhs);
				
				break;
			
			case LogicalOrAssign :
			case LogicalAndAssign :
			case BitwiseOr :
			case BitwiseAnd :
			case BitwiseXor :
			case BitwiseOrAssign :
			case BitwiseAndAssign :
			case BitwiseXorAssign :
				assert(0, "Not implemented.");
			
			case Equal :
			case NotEqual :
			case Identical :
			case NotIdentical :
				type = getPromotedType(e.location, lhs.type.type, rhs.type.type);
				
				lhs = buildImplicitCast(lhs.location, type, lhs);
				rhs = buildImplicitCast(rhs.location, type, rhs);
				
				type = getBuiltin(TypeKind.Bool);
				
				break;
			
			case In :
			case NotIn :
			case LeftShift :
			case SignedRightShift :
			case UnsignedRightShift :
			case LeftShiftAssign :
			case SignedRightShiftAssign :
			case UnsignedRightShiftAssign :
				assert(0, "Not implemented.");
			
			case Greater :
			case GreaterEqual :
			case Less :
			case LessEqual :
				type = getPromotedType(e.location, lhs.type.type, rhs.type.type);
				
				lhs = buildImplicitCast(lhs.location, type, lhs);
				rhs = buildImplicitCast(rhs.location, type, rhs);
				
				type = getBuiltin(TypeKind.Bool);
				
				break;
			
			case LessGreater :
			case LessEqualGreater :
			case UnorderedLess :
			case UnorderedLessEqual :
			case UnorderedGreater :
			case UnorderedGreaterEqual :
			case Unordered :
			case UnorderedEqual :
				assert(0, "Not implemented.");
		}
		
		return new BinaryExpression(e.location, type, op, lhs, rhs);
	}
	
	Expression visit(AstUnaryExpression e) {
		auto expr = visit(e.expr);
		auto op = e.op;
		
		QualType type;
		final switch(op) with(UnaryOp) {
			case AddressOf :
				// For fucked up reasons, &funcname is a special case.
				if(auto se = cast(SymbolExpression) expr) {
					if(cast(Function) se.symbol) {
						return expr;
					}
				}
				
				type = QualType(new PointerType(expr.type));
				break;
			
			case Dereference :
				assert(0, "Not implemented.");
			
			case PreInc :
			case PreDec :
			case PostInc :
			case PostDec :
				// FIXME: check that type is integer or pointer.
				type = expr.type;
				break;
			
			case Plus :
			case Minus :
				// FIXME: check that type is integer.
				type = expr.type;
				break;
			
			case Not :
				type = getBuiltin(TypeKind.Bool);
				expr = buildExplicitCast(expr.location, type, expr);
				break;
			
			case Complement :
				assert(0, "Not implemented.");
		}
		
		return new UnaryExpression(e.location, type, op, expr);
	}
	
	/+ /+
	private Expression handleArithmeticExpression(string operation)(BinaryExpression!operation e) if(find(["+", "+=", "-", "-="], operation)) {
		enum isOpAssign = operation.length == 2;
		
		e.lhs = visit(e.lhs);
		e.rhs = visit(e.rhs);
		
		if(auto pointerType = cast(PointerType) e.lhs.type) {
			if(typeid({ return e.rhs.type; }()) !is typeid(IntegerType)) {
				return pass.raiseCondition!Expression(e.rhs.location, "Pointer +/- interger only.");
			}
			
			// FIXME: introduce temporary.
			static if(operation[0] == '+') {
				auto value = new AddressOfExpression(e.location, new IndexExpression(e.location, e.lhs, [e.rhs]));
			} else {
				auto value = new AddressOfExpression(e.location, new IndexExpression(e.location, e.lhs, [visit(new UnaryMinusExpression(e.location, e.rhs))]));
			}
			
			static if(isOpAssign) {
				auto ret = new AssignExpression(e.location, e.lhs, value);
			} else {
				alias value ret;
			}
			
			return visit(ret);
		}
		
		static if(isOpAssign) {
			e.type = e.lhs.type;
		} else {
			e.type = getPromotedType(e.location, e.lhs.type, e.rhs.type);
			
			e.lhs = buildImplicitCast(e.lhs.location, e.type, e.lhs);
		}
		
		e.rhs = buildImplicitCast(e.rhs.location, e.type, e.rhs);
		
		return e;
	}
	
	private auto handleBinaryExpression(string operation)(BinaryExpression!operation e) {
		e.lhs = visit(e.lhs);
		e.rhs = visit(e.rhs);
		
		import std.algorithm;
		static if(find(["&&", "||"], operation)) {
			e.type = new BooleanType();
			
			e.lhs = buildExplicitCast(e.lhs.location, e.type, e.lhs);
			e.rhs = buildExplicitCast(e.rhs.location, e.type, e.rhs);
		} else static if(find(["==", "!=", ">", ">=", "<", "<="], operation)) {
			auto type = getPromotedType(e.location, e.lhs.type, e.rhs.type);
			
			e.lhs = buildImplicitCast(e.lhs.location, type, e.lhs);
			e.rhs = buildImplicitCast(e.rhs.location, type, e.rhs);
			
			e.type = new BooleanType();
		} else static if(find(["&", "|", "^", "*", "/", "%"], operation)) {
			e.type = getPromotedType(e.location, e.lhs.type, e.rhs.type);
			
			e.lhs = buildImplicitCast(e.lhs.location, e.type, e.lhs);
			e.rhs = buildImplicitCast(e.rhs.location, e.type, e.rhs);
		} else static if(find([","], operation)) {
			e.type = e.rhs.type;
		} else {
			static assert(0);
		}
		
		return e;
	}
	
	Expression visit(UnaryPlusExpression e) {
		// DMD don't understand that it has all infos already :(
		static SemanticPass workaround;
		auto oldWA = workaround;
		scope(exit) workaround = oldWA;
		
		return handleUnaryExpression!((UnaryPlusExpression e) {
			if(typeid({ return e.expression.type; }()) !is typeid(IntegerType)) {
				return workaround.raiseCondition!Expression(e.location, "unary plus only apply to integers.");
			}
			
			return e.expression;
		})(e);
	}
	
	Expression visit(DereferenceExpression e) {
		// DMD don't understand that it has all infos already :(
		static SemanticPass workaround;
		auto oldWA = workaround;
		scope(exit) workaround = oldWA;
		
		workaround = pass;
		
		return handleUnaryExpression!(function Expression(DereferenceExpression e) {
			if(auto pt = cast(PointerType) e.expression.type) {
				e.type = pt.type;
				
				return e;
			}
			
			return workaround.raiseCondition!Expression(e.location, typeid({ return e.expression.type; }()).toString() ~ " is not a pointer type.");
		})(e);
	}
	+/
	Expression visit(AstCastExpression e) {
		auto to = pass.visit(e.type);
		return buildExplicitCast(e.location, to, visit(e.expr));
	}
	
	private auto buildArgument(Expression arg, ParamType pt) {
		if(pt.isRef && !canConvert(arg.type.qualifier, pt.qualifier)) {
			return pass.raiseCondition!Expression(arg.location, "Can't pass argument by ref.");
		}
		
		arg = pass.buildImplicitCast(arg.location, QualType(pt.type, pt.qualifier), arg);
		
		// test if we can pass by ref.
		if(pt.isRef && !arg.isLvalue) {
			return pass.raiseCondition!Expression(arg.location, "Argument isn't a lvalue.");
		}
		
		return arg;
	}
	
	enum MatchLevel {
		Not,
		TypeConvert,
		QualifierConvert,
		Exact,
	}
	/+
	// TODO: deduplicate.
	private auto matchArgument(Expression arg, Parameter param) {
		if(param.isReference && !canConvert(arg.type.qualifier, param.type.qualifier)) {
			return MatchLevel.Not;
		}
		
		auto flavor = pass.implicitCastFrom(arg.type, param.type);
		
		// test if we can pass by ref.
		if(param.isReference && !(flavor >= CastKind.Bit && arg.isLvalue)) {
			return MatchLevel.Not;
		}
		
		return matchLevel(flavor);
	}
	
	// TODO: deduplicate.
	private auto matchArgument(Type type, bool lvalue, Parameter param) {
		if(param.isReference && !canConvert(type.qualifier, param.type.qualifier)) {
			return MatchLevel.Not;
		}
		
		auto flavor = pass.implicitCastFrom(type, param.type);
		
		// test if we can pass by ref.
		if(param.isReference && !(flavor >= CastKind.Bit && lvalue)) {
			return MatchLevel.Not;
		}
		
		return matchLevel(flavor);
	}
	+/
	private auto matchLevel(CastKind flavor) {
		final switch(flavor) with(CastKind) {
			case Invalid :
				return MatchLevel.Not;
			
			case IntegralToBool :
			case Trunc :
			case Pad :
			case Bit :
				return MatchLevel.TypeConvert;
			
			case Qual :
				return MatchLevel.QualifierConvert;
			
			case Exact :
				return MatchLevel.Exact;
		}
	}
	
	Expression visit(AstCallExpression c) {
		auto callee = visit(c.callee);
		auto args = c.arguments.map!(a => visit(a)).array();
		/+
		if(auto asPolysemous = cast(PolysemousExpression) c.callee) {
			auto candidates = asPolysemous.expressions.filter!((e) {
				if(auto asFunType = cast(FunctionType) e.type) {
					if(asFunType.isVariadic) {
						return c.arguments.length >= asFunType.parameters.length;
					} else {
						return c.arguments.length == asFunType.parameters.length;
					}
				}
				
				assert(0, "type is not a function type");
			}).map!(c => visit(c));
			
			auto level = MatchLevel.Not;
			Expression match;
			CandidateLoop: foreach(candidate; candidates) {
				auto type = cast(FunctionType) candidate.type;
				assert(type, "We should have filtered function at this point.");
				
				auto candidateLevel = MatchLevel.Exact;
				foreach(arg, param; lockstep(c.arguments, type.parameters)) {
					auto argLevel = matchArgument(arg, param);
					
					// If we don't match high enough.
					if(argLevel < level) {
						continue CandidateLoop;
					}
					
					final switch(argLevel) with(MatchLevel) {
						case Not :
							// This function don't match, go to next one.
							continue CandidateLoop;
						
						case TypeConvert :
						case QualifierConvert :
							candidateLevel = min(candidateLevel, argLevel);
							continue;
						
						case Exact :
							// Go to next argument
							continue;
					}
				}
				
				if(candidateLevel > level) {
					level = candidateLevel;
					match = candidate;
				} else if(candidateLevel == level) {
					// Check for specialisation.
					auto matchType = cast(FunctionType) match.type;
					assert(matchType, "We should have filtered function at this point.");
					
					bool candidateFail;
					bool matchFail;
					foreach(param, matchParam; lockstep(type.parameters, matchType.parameters)) {
						if(matchArgument(param.type, param.isReference, matchParam) == MatchLevel.Not) {
							candidateFail = true;
						}
						
						if(matchArgument(matchParam.type, matchParam.isReference, param) == MatchLevel.Not) {
							matchFail = true;
						}
					}
					
					if(matchFail == candidateFail) {
						return pass.raiseCondition!Expression(c.location, "ambigusous function call.");
					}
					
					if(matchFail) {
						match = candidate;
					}
				}
			}
			
			if(!match) {
				return pass.raiseCondition!Expression(c.location, "No candidate for function call.");
			}
			
			c.callee = match;
		}
		+/
		
		auto type = callee.type.type;
		ParamType[] paramTypes;
		ParamType returnType;
		if(auto f = cast(FunctionType) type) {
			paramTypes = f.paramTypes;
			returnType = f.returnType;
		} else if(auto d = cast(DelegateType) type) {
			paramTypes = d.paramTypes;
			returnType = d.returnType;
		} else {
			return pass.raiseCondition!Expression(c.location, "You must call function or delegates, not " ~ callee.type.toString());
		}
		
		assert(args.length >= paramTypes.length);
		
		foreach(ref arg, pt; lockstep(args, paramTypes)) {
			arg = buildArgument(arg, pt);
		}
		
		return new CallExpression(c.location, QualType(returnType.type, returnType.qualifier), callee, args);
	}
	
	/+
	Expression visit(FieldExpression e) {
		e.expression = visit(e.expression);
		
		auto f = e.field;
		scheduler.require(f, Step.Signed);
		
		e.type = e.field.type;
		return e;
	}
	
	// TODO: handle overload sets.
	Expression visit(DelegateExpression e) {
		e.funptr = visit(e.funptr);
		
		if(auto funType = cast(FunctionType) e.funptr.type) {
			if(typeid(funType) !is typeid(FunctionType)) {
				return pass.raiseCondition!Expression(e.location, "Can't create delegate.");
			}
			
			if(funType.isVariadic || funType.parameters.length > 0) {
				auto contextParam = funType.parameters[0];
				
				e.context = buildArgument(e.context, contextParam);
				e.type = new DelegateType(funType.linkage, funType.returnType, contextParam, funType.parameters[1 .. $], funType.isVariadic);
				
				return e;
			}
		}
		
		return pass.raiseCondition!Expression(e.location, "Can't create delegate.");
	}
	
	Expression visit(MethodExpression e) {
		auto m = e.method;
		scheduler.require(e.method, Step.Signed);
		
		if(auto dgType = cast(DelegateType) m.type) {
			e.expression = buildArgument(e.expression, dgType.context);
			e.type = dgType;
			
			return e;
		}
		
		return pass.raiseCondition!Expression(e.location, "Can't create delegate.");
	}
	
	Expression visit(NewExpression e) {
		assert(e.arguments.length == 0, "constructor not supported");
		
		e.type = pass.visit(e.type);
		
		return e;
	}
	+/
	Expression visit(ThisExpression e) {
		e.type = QualType(thisType.type, thisType.qualifier);
		
		return e;
	}
	
	Expression visit(AstIndexExpression e) {
		auto indexed = visit(e.indexed);
		
		auto qt = peelAlias(indexed.type);
		auto type = qt.type;
		if(auto asSlice = cast(SliceType) type) {
			qt.type = asSlice.sliced.type;
		} else if(auto asPointer = cast(PointerType) type) {
			qt.type = asPointer.pointed.type;
		} else if(auto asArray = cast(ArrayType) type) {
			qt.type = asArray.elementType.type;
		} else {
			return pass.raiseCondition!Expression(e.location, "Can't index " ~ qt.toString());
		}
		
		auto arguments = e.arguments.map!(e => visit(e)).array();
		
		return new IndexExpression(e.location, qt, indexed, arguments);
	}
	/+
	Expression visit(SliceExpression e) {
		// TODO: check if it is valid.
		e.indexed = visit(e.indexed);
		
		if(auto asSlice = cast(SliceType) e.indexed.type) {
			e.type = asSlice.type;
		} else if(auto asPointer = cast(PointerType) e.indexed.type) {
			e.type = asPointer.type;
		} else if(auto asStaticArray = cast(StaticArrayType) e.indexed.type) {
			e.type = asStaticArray.type;
		} else {
			return pass.raiseCondition!Expression(e.location, "Can't slice " ~ typeid({ return e.indexed; }()).toString());
		}
		
		e.type = pass.visit(new SliceType(e.type));
		
		e.first = e.first.map!(e => visit(e)).array();
		e.second = e.second.map!(e => visit(e)).array();
		
		return e;
	}
	
	Expression visit(SizeofExpression e) {
		return makeLiteral(e.location, sizeofCalculator.visit(e.argument));
	}
	
	Expression visit(AssertExpression e) {
		auto c = visit(e.condition);
		e.condition = buildExplicitCast(c.location, new BooleanType(), c);
		
		if(e.message) {
			// FIXME: cast to string.
			e.message = evaluate(visit(e.message));
		}
		
		e.type = new VoidType();
		
		return e;
	}
	+/
	Expression visit(IdentifierExpression e) {
		return pass.visit(e.identifier).apply!((identified) {
			static if(is(typeof(identified) : Expression)) {
				return identified;
			} else {
				return pass.raiseCondition!Expression(e.location, e.identifier.name ~ " isn't an expression.");
			}
		})();
	}
}


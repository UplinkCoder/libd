module d.ast.type;

import d.ast.ambiguous;
import d.ast.base;
import d.ast.declaration;
import d.ast.dscope;
import d.ast.expression;
import d.ast.identifier;

import std.traits;

abstract class Type : Identifiable {
	this(Location location) {
		super(location);
	}
	
	abstract Type makeMutable();
	abstract Type makeImmutable();
	abstract Type makeConst();
	abstract Type makeInout();
	
	bool opEqual(const Type t) const {
		return false;
	}
	
	uint getSize() {
		return 0;
	}
	
	Expression initExpression(Location location) {
		assert(0, "init expression isn't implemented for " ~ typeid(this).toString());
	}
}

class SimpleStorageClassType : Type {
	private uint storageClass = 0;
	
	enum MUTABLE = 0x00;
	enum IMMUTABLE = 0x01;
	enum CONST = 0x02;
	enum INOUT = 0x03;
	
	enum MASK = ~0x03;
	
	this(Location location) {
		super(location);
	}
	
final:	// Check whenever these operation make sense.
	override Type makeMutable() {
		storageClass &= MASK;
		return this;
	}
	
	override Type makeImmutable() {
		makeMutable();
		storageClass |= IMMUTABLE;
		return this;
	}
	
	override Type makeConst() {
		makeMutable();
		storageClass |= CONST;
		return this;
	}
	
	override Type makeInout() {
		makeMutable();
		storageClass |= INOUT;
		return this;
	}
}

/**
 * Auto types
 */
class AutoType : SimpleStorageClassType {
	this(Location location) {
		super(location);
	}
}

/**
 * All basics types and qualified basic types.
 */
class BasicType : SimpleStorageClassType {
	this(Location location) {
		super(location);
	}
}

/**
 * Boolean type.
 */
class BooleanType : BasicType {
	this(Location location) {
		super(location);
	}
	
	override bool opEqual(const Type t) const {
		return typeid(t) is typeid(typeof(this));
	}
	
	bool opEqual(BooleanType t) const {
		return true;
	}
	
	override Expression initExpression(Location location) {
		return makeLiteral(location, false);
	}
	
	override uint getSize() {
		return 1;
	}
}

/**
 * Built in integer types.
 */
enum Integer {
	Byte,
	Ubyte,
	Short,
	Ushort,
	Int,
	Uint,
	Long,
	Ulong,
}

template IntegerOf(T) {
	static if(!is(T == Unqual!T)) {
		enum IntegerOf = IntegerOf!(Unqual!T);
	} else static if(is(T == byte)) {
		enum IntegerOf = Integer.Byte;
	} else static if(is(T == ubyte)) {
		enum IntegerOf = Integer.Ubyte;
	} else static if(is(T == short)) {
		enum IntegerOf = Integer.Short;
	} else static if(is(T == ushort)) {
		enum IntegerOf = Integer.Ushort;
	} else static if(is(T == int)) {
		enum IntegerOf = Integer.Int;
	} else static if(is(T == uint)) {
		enum IntegerOf = Integer.Uint;
	} else static if(is(T == long)) {
		enum IntegerOf = Integer.Long;
	} else static if(is(T == ulong)) {
		enum IntegerOf = Integer.Ulong;
	} else {
		static assert(0, T.stringof ~ " isn't a valid integer type.");
	}
}

class IntegerType : BasicType {
	Integer type;
	
	this(Location location, Integer type) {
		super(location);
		
		this.type = type;
	}
	
	override Expression initExpression(Location location) {
		if(type % 2) {
			return new IntegerLiteral!true(location, 0, this);
		} else {
			return new IntegerLiteral!false(location, 0, this);
		}
	}
	
	override bool opEqual(const Type t) const {
		if(auto i = cast(IntegerType) t) {
			return this.opEqual(i);
		}
		
		return false;
	}
	
	bool opEqual(const IntegerType t) const {
		return type == t.type;
	}
	
	override uint getSize() {
		final switch(type) {
			case Integer.Byte, Integer.Ubyte :
				return 1;
			
			case Integer.Short, Integer.Ushort :
				return 2;
			
			case Integer.Int, Integer.Uint :
				return 4;
			
			case Integer.Long, Integer.Ulong :
				return 8;
		}
	}
}

/**
 * Built in float types.
 */
enum Float {
	Float,
	Double,
	Real,
}

template FloatOf(T) {
	static if(!is(T == Unqual!T)) {
		enum FloatOf = FloatOf!(Unqual!T);
	} else static if(is(T == float)) {
		enum FloatOf = Float.Float;
	} else static if(is(T == double)) {
		enum FloatOf = Float.Double;
	} else static if(is(T == real)) {
		enum FloatOf = Float.Real;
	} else {
		static assert(0, T.stringof ~ " isn't a valid float type.");
	}
}

class FloatType : BasicType {
	Float type;
	
	this(Location location, Float type) {
		super(location);
		
		this.type = type;
	}
	
	override bool opEqual(const Type t) const {
		if(auto f = cast(IntegerType) t) {
			return this.opEqual(f);
		}
		
		return false;
	}
	
	bool opEqual(const FloatType t) const {
		return type == t.type;
	}
	
	override Expression initExpression(Location location) {
		return new FloatLiteral(location, float.nan, this);
	}
	
	override uint getSize() {
		final switch(type) {
			case Float.Float :
				return 4;
			
			case Float.Double :
				return 8;
			
			case Float.Real :
				return 10;
		}
	}
}

/**
 * Built in char types.
 */
enum Character {
	Char,
	Wchar,
	Dchar,
}

template CharacterOf(T) {
	static if(!is(T == Unqual!T)) {
		enum CharacterOf = CharacterOf!(Unqual!T);
	} else static if(is(T == char)) {
		enum CharacterOf = Character.Char;
	} else static if(is(T == wchar)) {
		enum CharacterOf = Character.Wchar;
	} else static if(is(T == dchar)) {
		enum CharacterOf = Character.Dchar;
	} else {
		static assert(0, T.stringof ~ " isn't a valid character type.");
	}
}

class CharacterType : BasicType {
	Character type;
	
	this(Location location, Character type) {
		super(location);
		
		this.type = type;
	}
	
	override bool opEqual(const Type t) const {
		if(auto c = cast(CharacterType) t) {
			return this.opEqual(c);
		}
		
		return false;
	}
	
	bool opEqual(const CharacterType t) const {
		return type == t.type;
	}
	
	override Expression initExpression(Location location) {
		return new CharacterLiteral(location, [char.init], this);
	}
}

/**
 * Void
 */
class VoidType : BasicType {
	this(Location location) {
		super(location);
	}
}

/**
 * Type defined by an identifier
 */
class IdentifierType : BasicType {
	Identifier identifier;
	
	this(Identifier identifier) {
		super(identifier.location);
		
		this.identifier = identifier;
	}
}

/**
 * Symbol type.
 * IdentifierType that as been resolved.
 */
class SymbolType : BasicType {
	TypeSymbol symbol;
	
	this(Location location, TypeSymbol symbol) {
		super(location);
		
		this.symbol = symbol;
	}
	
	override bool opEqual(const Type t) const {
		if(auto s = cast(SymbolType) t) {
			return this.opEqual(s);
		}
		
		return false;
	}
	
	bool opEqual(const SymbolType t) const {
		return symbol is t.symbol;
	}
	
	// FIXME: get the right initializer.
	override Expression initExpression(Location location) {
		return new VoidInitializer(location, this);
	}
}

/**
 * Type defined by typeof(Expression)
 */
class TypeofType : BasicType {
	Expression expression;
	
	this(Location location, Expression expression) {
		super(location);
		
		this.expression = expression;
	}
	
	override Expression initExpression(Location location) {
		// TODO: remove in the future.
		scope(failure) {
			import std.stdio;
			writeln(typeid({ return expression.type; }()).toString() ~ " have no .init");
		}
		
		return expression.type.initExpression(location);
	}
}

/**
 * Type defined by typeof(return)
 */
class ReturnType : BasicType {
	this(Location location) {
		super(location);
	}
}

class SuffixType : SimpleStorageClassType {
	Type type;
	
	this(Location location, Type type) {
		super(location);
		
		this.type = type;
	}
}

/**
 * Pointer types
 */
class PointerType : SuffixType {
	this(Location location, Type type) {
		super(location, type);
	}
	
	override bool opEqual(const Type t) const {
		if(auto p = cast(PointerType) t) {
			return this.opEqual(p);
		}
		
		return false;
	}
	
	bool opEqual(const PointerType t) const {
		return type == t.type;
	}
}

/**
 * Slice types
 */
class SliceType : SuffixType {
	this(Location location, Type type) {
		super(location, type);
	}
}

/**
 * Static array types
 */
class StaticArrayType : SuffixType {
	Expression size;
	
	this(Location location, Type type, Expression size) {
		super(location, type);
		
		this.size = size;
	}
}

/**
 * Associative array types
 */
class AssociativeArrayType : SuffixType {
	Type keyType;
	
	this(Location location, Type type, Type keyType) {
		super(location, type);
		
		this.keyType = keyType;
	}
}

/**
 * Associative array types
 */
class AmbiguousArrayType : SuffixType {
	TypeOrExpression key;
	
	this(Location location, Type type, TypeOrExpression key) {
		super(location, type);
		
		this.key = key;
	}
}


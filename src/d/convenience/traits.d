module d.convenience.traits;

//import d.ast.type;
import d.ir.expression;
import d.ir.type;

QualType elementType(QualType qt)  {
	qt = peelAlias(qt);
	if(auto asSlice = cast(SliceType) qt.type) {
		return asSlice.sliced;
	} else if(auto asPointer = cast(PointerType) qt.type) {
		return asPointer.pointed;
	} else if(auto asArray = cast(ArrayType) qt.type) {
		return asArray.elementType;
	} else {
		return QualType.init;
	}
}

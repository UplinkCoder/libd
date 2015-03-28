module util.hex;

char[2] byte2hex(const ubyte b) pure {
	static immutable char[16] hexDigits = "0123456789abcdef";
	ubyte hi = (b >> 4);
	ubyte lo = (b & 0x0F);
	return [hexDigits[hi], hexDigits[lo]];
}

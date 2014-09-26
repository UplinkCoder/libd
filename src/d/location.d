module d.location;

import util.utf8;

/**
 * Struct representing a location in a source file.
 */
struct Location {
	Source source;
	
	uint line = 1;
	uint index = 1;
	uint length = 0;
	
	string toString() const {
		return source.format(this);
	}
	
	void spanTo(ref const Location end) in {
		assert(source is end.source, "locations must have the same source !");
		
		assert(line <= end.line);
		assert(index <= end.index);
		assert(index + length <= end.index + end.length);
	} body {
		length = end.index - index + end.length;
	}
}

abstract class Source {
	string content;
	
	this(string content) {
		this.content = content;
	}
	
	abstract string format(const Location location) const;
	
	@property
	abstract string filename() const;
}

final class FileSource : Source {
	string _filename;
	
	this(string filename) {
		_filename = filename;

		import std.file;
		auto data = cast(const(ubyte)[]) read(filename);
		super(convertToUTF8(data) ~ '\0');
	}
	
	override string format(const Location location) const {
		import std.conv;
		return _filename ~ ':' ~ to!string(location.line);
	}

	@property
	override string filename() const {
		return _filename;
	}
}

final class MixinSource : Source {
	Location location;
	
	this(Location location, string content) {
		this.location = location;
		super(content);
	}
	
	override string format(const Location dummy) const {
		return location.toString();
	}
	
	@property
	override string filename() const {
		return location.source.filename;
	}
}

/**
* This class is mostly ment for Unittests and such but could also be used by REPL and stuff.
*/
final class StringSource : Source {
	string _name;
	immutable string[] _packages;

	this(in string content,in string name, immutable string[] _packages=[]) {
		_name = name;
		this._packages = _packages;
		assert(name[$-2 .. $] != ".d","stringSources don't get the .d extention");
		super(content ~ '\0');
	}

	override string format(const Location location) const {
		import std.conv;
		return _name ~ ':' ~ to!string(location.line);
	}

	@property
	override string filename() const {
		return _name;
	}

	@property
	const(string[]) packages() const {
		return _packages;
	}
}
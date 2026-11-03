class_name FileHelper
extends RefCounted

# Community song folders are not guaranteed to be UTF-8: song.ini and .chart
# files come from many Windows tools and are often Windows-1252/Latin-1, and
# some editors save UTF-16. Godot's get_string_from_utf8() replaces every invalid
# byte with U+FFFD and logs a parsing error, which is exactly the "Volc�n"
# corruption the menu used to show. All text therefore enters the game through
# decode_text(), which recognizes the byte order marks and falls back to a
# lossless Windows-1252 decode when the file is not valid UTF-8. Writes always
# use UTF-8.

static var UTF8_BOM: PackedByteArray = PackedByteArray([0xEF, 0xBB, 0xBF])
# Windows-1252 differs from Latin-1 only in 0x80-0x9F. Bytes that CP1252 leaves
# undefined keep their control value instead of becoming U+FFFD.
const _CP1252_0X80_TO_0X9F: Dictionary = {
	0x80: 0x20AC,  # €
	0x82: 0x201A,  # ‚
	0x83: 0x0192,  # ƒ
	0x84: 0x201E,  # „
	0x85: 0x2026,  # …
	0x86: 0x2020,  # †
	0x87: 0x2021,  # ‡
	0x88: 0x02C6,  # ˆ
	0x89: 0x2030,  # ‰
	0x8A: 0x0160,  # Š
	0x8B: 0x2039,  # ‹
	0x8C: 0x0152,  # Œ
	0x8E: 0x017D,  # Ž
	0x91: 0x2018,  # ‘
	0x92: 0x2019,  # ’
	0x93: 0x201C,  # “
	0x94: 0x201D,  # ”
	0x95: 0x2022,  # •
	0x96: 0x2013,  # –
	0x97: 0x2014,  # —
	0x98: 0x02DC,  # ˜
	0x99: 0x2122,  # ™
	0x9A: 0x0161,  # š
	0x9B: 0x203A,  # ›
	0x9C: 0x0153,  # œ
	0x9E: 0x017E,  # ž
	0x9F: 0x0178,  # Ÿ
}


static func read_file(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var data: PackedByteArray = file.get_buffer(file.get_length())
		file.close()
		return data
	if OS.has_feature("android"):
		var uri := _to_content_uri(path)
		if not uri.is_empty():
			file = FileAccess.open(uri, FileAccess.READ)
			if file:
				var data: PackedByteArray = file.get_buffer(file.get_length())
				file.close()
				return data
	return PackedByteArray()


static func file_exists(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		file.close()
		return true
	if OS.has_feature("android"):
		var uri := _to_content_uri(path)
		if not uri.is_empty():
			file = FileAccess.open(uri, FileAccess.READ)
			if file:
				file.close()
				return true
	return false


static func read_text(path: String) -> String:
	return decode_text(read_file(path))


static func write_text(path: String, text: String, with_bom: bool = false) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	if with_bom:
		file.store_buffer(UTF8_BOM)
	file.store_buffer(text.to_utf8_buffer())
	file.close()
	return true


static func decode_text(data: PackedByteArray) -> String:
	if data.is_empty():
		return ""
	var n: int = data.size()
	# UTF-32 BOMs must be checked before UTF-16 LE, whose BOM is their prefix.
	if n >= 4 and data[0] == 0xFF and data[1] == 0xFE and data[2] == 0x00 and data[3] == 0x00:
		return _strip_bom(_decode_utf32(data, true))
	if n >= 4 and data[0] == 0x00 and data[1] == 0x00 and data[2] == 0xFE and data[3] == 0xFF:
		return _strip_bom(_decode_utf32(data, false))
	if n >= 2 and data[0] == 0xFF and data[1] == 0xFE:
		return _strip_bom(_decode_utf16(data, true))
	if n >= 2 and data[0] == 0xFE and data[1] == 0xFF:
		return _strip_bom(_decode_utf16(data, false))
	if n >= 3 and data[0] == 0xEF and data[1] == 0xBB and data[2] == 0xBF:
		data = data.slice(3)
	if is_valid_utf8(data):
		return _strip_bom(data.get_string_from_utf8())
	# The file is not UTF-8. Decode it as a whole with Windows-1252 (the common
	# encoding of community chart tools); decoding only the invalid bytes would
	# misread valid-looking pairs such as "Ñ»" as a Cyrillic character.
	return _strip_bom(_decode_cp1252(data))


static func is_valid_utf8(data: PackedByteArray) -> bool:
	var i: int = 0
	var n: int = data.size()
	while i < n:
		var length: int = _utf8_sequence_length(data, i)
		if length == 0:
			return false
		i += length
	return true


# Length in bytes of the valid UTF-8 sequence starting at `i`, or 0 if the
# bytes there are not a valid sequence. Rejects overlong forms, surrogates and
# code points above U+10FFFF.
static func _utf8_sequence_length(data: PackedByteArray, i: int) -> int:
	var n: int = data.size()
	var b: int = data[i]
	if b < 0x80:
		return 1
	if b >= 0xC2 and b <= 0xDF:
		if i + 1 >= n or not _is_continuation(data[i + 1]):
			return 0
		return 2
	if b >= 0xE0 and b <= 0xEF:
		if i + 2 >= n:
			return 0
		var b1: int = data[i + 1]
		var b2: int = data[i + 2]
		if not _is_continuation(b2):
			return 0
		if b == 0xE0:
			if b1 < 0xA0 or b1 > 0xBF:
				return 0
		elif b == 0xED:
			# U+D800..U+DFFF are not valid scalar values.
			if b1 < 0x80 or b1 > 0x9F:
				return 0
		elif not _is_continuation(b1):
			return 0
		return 3
	if b >= 0xF0 and b <= 0xF4:
		if i + 3 >= n:
			return 0
		var b1: int = data[i + 1]
		var b2: int = data[i + 2]
		var b3: int = data[i + 3]
		if not _is_continuation(b2) or not _is_continuation(b3):
			return 0
		if b == 0xF0:
			if b1 < 0x90 or b1 > 0xBF:
				return 0
		elif b == 0xF4:
			if b1 < 0x80 or b1 > 0x8F:
				return 0
		elif not _is_continuation(b1):
			return 0
		return 4
	return 0


static func _is_continuation(b: int) -> bool:
	return (b & 0xC0) == 0x80


static func _decode_cp1252(data: PackedByteArray) -> String:
	var n: int = data.size()
	var out := PackedByteArray()
	out.resize(n * 3)
	var write: int = 0
	for i in n:
		var code: int = data[i]
		if code >= 0x80 and code <= 0x9F:
			code = int(_CP1252_0X80_TO_0X9F.get(code, code))
		write = _write_utf8(out, write, code)
	return out.slice(0, write).get_string_from_utf8()


static func _decode_utf16(data: PackedByteArray, little_endian: bool) -> String:
	var n: int = data.size()
	var out := PackedByteArray()
	out.resize(n * 3)
	var i: int = 2  # skip BOM
	var write: int = 0
	while i + 1 < n:
		var unit: int
		if little_endian:
			unit = data[i] | (data[i + 1] << 8)
		else:
			unit = (data[i] << 8) | data[i + 1]
		i += 2
		var code: int = unit
		if unit >= 0xD800 and unit <= 0xDBFF:
			if i + 1 < n:
				var low: int
				if little_endian:
					low = data[i] | (data[i + 1] << 8)
				else:
					low = (data[i] << 8) | data[i + 1]
				if low >= 0xDC00 and low <= 0xDFFF:
					i += 2
					code = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
				else:
					code = 0xFFFD
			else:
				code = 0xFFFD
		elif unit >= 0xDC00 and unit <= 0xDFFF:
			code = 0xFFFD
		write = _write_utf8(out, write, code)
	return out.slice(0, write).get_string_from_utf8()


static func _decode_utf32(data: PackedByteArray, little_endian: bool) -> String:
	var n: int = data.size()
	var out := PackedByteArray()
	out.resize(n * 3)
	var i: int = 4  # skip BOM
	var write: int = 0
	while i + 3 < n:
		var code: int
		if little_endian:
			code = data[i] | (data[i + 1] << 8) | (data[i + 2] << 16) | (data[i + 3] << 24)
		else:
			code = (data[i] << 24) | (data[i + 1] << 16) | (data[i + 2] << 8) | data[i + 3]
		i += 4
		if code < 0 or code > 0x10FFFF or (code >= 0xD800 and code <= 0xDFFF):
			code = 0xFFFD
		write = _write_utf8(out, write, code)
	return out.slice(0, write).get_string_from_utf8()


# Writes `code` as UTF-8 at `index` and returns the next index.
static func _write_utf8(out: PackedByteArray, index: int, code: int) -> int:
	if code < 0x80:
		out[index] = code
		return index + 1
	if code < 0x800:
		out[index] = 0xC0 | (code >> 6)
		out[index + 1] = 0x80 | (code & 0x3F)
		return index + 2
	if code < 0x10000:
		out[index] = 0xE0 | (code >> 12)
		out[index + 1] = 0x80 | ((code >> 6) & 0x3F)
		out[index + 2] = 0x80 | (code & 0x3F)
		return index + 3
	out[index] = 0xF0 | (code >> 18)
	out[index + 1] = 0x80 | ((code >> 12) & 0x3F)
	out[index + 2] = 0x80 | ((code >> 6) & 0x3F)
	out[index + 3] = 0x80 | (code & 0x3F)
	return index + 4


static func _strip_bom(text: String) -> String:
	var bom: String = String.chr(0xFEFF)
	while text.begins_with(bom):
		text = text.substr(1)
	return text


static func _to_content_uri(path: String) -> String:
	if not path.begins_with("/storage/emulated/"):
		return ""
	var rel: String = path.trim_prefix("/storage/emulated/")
	var parts := rel.split("/")
	if parts.size() < 2:
		return ""
	var encoded: String = ""
	for i in range(1, parts.size()):
		if i > 1:
			encoded += "%2F"
		encoded += parts[i].uri_encode()
	return "content://com.android.externalstorage.documents/document/primary%3A" + encoded

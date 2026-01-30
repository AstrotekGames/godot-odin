package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:unicode"

// JSON Schema Types

Deprecated_Info :: struct {
    since:        string,
    message:      string,
    replace_with: string,
}

Enum_Value :: struct {
    name:        string,
    value:       i64,
    description: []string,
}

Struct_Member :: struct {
    name:        string,
    type:        string,
    description: []string,
}

Function_Argument :: struct {
    name:        string,
    type:        string,
    description: []string,
}

Return_Value :: struct {
    type:        string,
    description: []string,
}

Type_Def :: struct {
    name:             string,
    kind:             string,
    description:      []string,
    deprecated:       Maybe(Deprecated_Info),
    is_bitfield:      Maybe(bool),
    values:           []Enum_Value,
    parent:           Maybe(string),
    is_const:         Maybe(bool),
    is_uninitialized: Maybe(bool),
    type:             Maybe(string),
    members:          []Struct_Member,
    return_value:     Maybe(Return_Value),
    arguments:        []Function_Argument,
}

Interface_Func :: struct {
    name:             string,
    return_value:     Maybe(Return_Value),
    arguments:        []Function_Argument,
    description:      []string,
    since:            string,
    deprecated:       Maybe(Deprecated_Info),
    see:              []string,
    legacy_type_name: Maybe(string),
}

GDExtension_Interface :: struct {
    _copyright:     []string `json:"_copyright"`,
    schema:         string `json:"$schema"`,
    format_version: i64,
    types:          []Type_Def,
    interface:      []Interface_Func,
}

// Extension API Types

API_Header :: struct {
    version_major:     i64,
    version_minor:     i64,
    version_patch:     i64,
    version_status:    string,
    version_build:     string,
    version_full_name: string,
    precision:         string,
}

API_Size :: struct {
    name: string,
    size: i64,
}

API_BuildConfig :: struct {
    build_configuration: string,
    sizes:               []API_Size,
}

API_MemberOffset :: struct {
    member: string,
    offset: i64,
    meta:   string,
}

API_ClassMemberOffsets :: struct {
    name:    string,
    members: []API_MemberOffset,
}

API_BuildConfigOffsets :: struct {
    build_configuration: string,
    classes:             []API_ClassMemberOffsets,
}

API_MethodArg :: struct {
    name:          string,
    type:          string,
    meta:          Maybe(string),
    default_value: Maybe(string),
}

API_MethodReturn :: struct {
    type: string,
    meta: Maybe(string),
}

API_Method :: struct {
    name:         string,
    is_const:     bool,
    is_vararg:    bool,
    is_static:    bool,
    is_virtual:   bool,
    hash:         i64,
    arguments:    []API_MethodArg,
    return_value: Maybe(API_MethodReturn),
}

API_BuiltinMethodArg :: struct {
    name:          string,
    type:          string,
    default_value: Maybe(string),
}

API_BuiltinMethod :: struct {
    name:        string,
    return_type: Maybe(string),
    is_vararg:   bool,
    is_const:    bool,
    is_static:   bool,
    hash:        i64,
    arguments:   []API_BuiltinMethodArg,
}

API_BuiltinConstructorArg :: struct {
    name: string,
    type: string,
}

API_BuiltinConstructor :: struct {
    index:     i32,
    arguments: []API_BuiltinConstructorArg,
}

API_BuiltinClassConstant :: struct {
    name:  string,
    type:  string,
    value: string,
}

API_BuiltinClass :: struct {
    name:                string,
    indexing_return_type: Maybe(string),
    is_keyed:            bool,
    members:             []API_BuiltinMethodArg,
    constants:           []API_BuiltinClassConstant,
    enums:               []API_Enum,
    operators:           json.Value,
    methods:             []API_BuiltinMethod,
    constructors:        []API_BuiltinConstructor,
    has_destructor:      bool,
}

API_ClassConstant :: struct {
    name:  string,
    value: i64,
}

API_EnumValue :: struct {
    name:  string,
    value: i64,
}

API_Enum :: struct {
    name:        string,
    is_bitfield: bool,
    values:      []API_EnumValue,
}

API_SignalArg :: struct {
    name: string,
    type: string,
}

API_Signal :: struct {
    name:      string,
    arguments: []API_SignalArg,
}

API_Class :: struct {
    name:           string,
    is_refcounted:  bool,
    is_instantiable: bool,
    inherits:       Maybe(string),
    api_type:       string,
    constants:      []API_ClassConstant,
    enums:          []API_Enum,
    methods:        []API_Method,
    signals:        []API_Signal,
}

API_Singleton :: struct {
    name: string,
    type: string,
}

API_UtilityFunction :: struct {
    name:        string,
    return_type: Maybe(string),
    category:    string,
    is_vararg:   bool,
    hash:        i64,
    arguments:   []API_BuiltinMethodArg,
}

Extension_API :: struct {
    header:                        API_Header,
    builtin_class_sizes:           []API_BuildConfig,
    builtin_class_member_offsets:  []API_BuildConfigOffsets,
    global_enums:                  []API_Enum,
    builtin_classes:               []API_BuiltinClass,
    classes:                       []API_Class,
    singletons:                    []API_Singleton,
    utility_functions:             []API_UtilityFunction,
}

// Generator State

Generator :: struct {
    output:        strings.Builder,
    indent:        int,
    type_map:      map[string]string,
    handle_types:  map[string]bool,
    enum_types:    map[string]bool,
    struct_types:  map[string]bool,
    func_types:    map[string]Type_Def,
    singleton_set: map[string]bool,
}

// Type Conversion

init_type_map :: proc(g: ^Generator) {
    g.type_map["void"] = "void"
    g.type_map["void*"] = "rawptr"
    g.type_map["const void*"] = "rawptr"
    g.type_map["char*"] = "cstring"
    g.type_map["const char*"] = "cstring"
    g.type_map["char16_t"] = "u16"
    g.type_map["char16_t*"] = "[^]u16"
    g.type_map["const char16_t*"] = "[^]u16"
    g.type_map["char32_t"] = "u32"
    g.type_map["char32_t*"] = "[^]u32"
    g.type_map["const char32_t*"] = "[^]u32"
    g.type_map["wchar_t"] = "u32"
    g.type_map["wchar_t*"] = "[^]u32"
    g.type_map["const wchar_t*"] = "[^]u32"
    g.type_map["uint8_t"] = "u8"
    g.type_map["uint8_t*"] = "[^]u8"
    g.type_map["const uint8_t*"] = "[^]u8"
    g.type_map["int8_t"] = "i8"
    g.type_map["uint16_t"] = "u16"
    g.type_map["int16_t"] = "i16"
    g.type_map["uint32_t"] = "u32"
    g.type_map["uint32_t*"] = "^u32"
    g.type_map["int32_t"] = "i32"
    g.type_map["int32_t*"] = "^i32"
    g.type_map["uint64_t"] = "u64"
    g.type_map["uint64_t*"] = "^u64"
    g.type_map["int64_t"] = "i64"
    g.type_map["int64_t*"] = "^i64"
    g.type_map["float"] = "f64"  // ptrcall wire type: PtrToArg<float> uses double
    g.type_map["double"] = "f64"
    g.type_map["size_t"] = "uint"
    g.type_map["bool"] = "bool"
    g.type_map["int"] = "i64"
    g.type_map["String"] = "GodotString"
    g.type_map["Vector2"] = "Vector2"
    g.type_map["Vector2i"] = "Vector2i"
    g.type_map["Vector3"] = "Vector3"
    g.type_map["Vector3i"] = "Vector3i"
    g.type_map["Vector4"] = "Vector4"
    g.type_map["Vector4i"] = "Vector4i"
    g.type_map["Rect2"] = "Rect2"
    g.type_map["Rect2i"] = "Rect2i"
    g.type_map["Color"] = "Color"
    g.type_map["Transform2D"] = "Transform2D"
    g.type_map["StringName"] = "StringName"
    g.type_map["NodePath"] = "NodePath"
    g.type_map["RID"] = "RID"
    g.type_map["Array"] = "Array"
    g.type_map["Dictionary"] = "Dictionary"
    g.type_map["Variant"] = "Variant"
    g.type_map["Callable"] = "Callable"
    g.type_map["Signal"] = "Signal"
    g.type_map["AABB"] = "AABB"
    g.type_map["Basis"] = "Basis"
    g.type_map["Quaternion"] = "Quaternion"
    g.type_map["Transform2D"] = "Transform2D"
    g.type_map["Transform3D"] = "Transform3D"
    g.type_map["Plane"] = "Plane"
    g.type_map["Projection"] = "Projection"
    g.type_map["PackedByteArray"] = "PackedByteArray"
    g.type_map["PackedInt32Array"] = "PackedInt32Array"
    g.type_map["PackedInt64Array"] = "PackedInt64Array"
    g.type_map["PackedFloat32Array"] = "PackedFloat32Array"
    g.type_map["PackedFloat64Array"] = "PackedFloat64Array"
    g.type_map["PackedStringArray"] = "PackedStringArray"
    g.type_map["PackedVector2Array"] = "PackedVector2Array"
    g.type_map["PackedVector3Array"] = "PackedVector3Array"
    g.type_map["PackedColorArray"] = "PackedColorArray"
    g.type_map["PackedVector4Array"] = "PackedVector4Array"
}

convert_type :: proc(g: ^Generator, c_type: string) -> string {
    if mapped, ok := g.type_map[c_type]; ok {
        return mapped
    }

    type_str := c_type
    if strings.has_prefix(type_str, "const ") {
        type_str = type_str[6:]
    }

    if strings.has_suffix(type_str, "**") {
        base := strings.trim_space(strings.trim_suffix(type_str, "**"))
        return fmt.tprintf("[^]^%s", convert_type(g, base))
    }

    if strings.has_suffix(type_str, "*") {
        base := strings.trim_space(strings.trim_suffix(type_str, "*"))
        base_odin := convert_type(g, base)
        if base_odin == "void" {
            return "rawptr"
        }
        return fmt.tprintf("^%s", base_odin)
    }

    if g.handle_types[type_str] || g.enum_types[type_str] || g.struct_types[type_str] || type_str in g.func_types {
        return type_str
    }
    if strings.has_prefix(type_str, "GDObject") {
        return type_str
    }
    if strings.has_prefix(type_str, "typedarray::") {
        return "Array"
    }
    if strings.has_prefix(type_str, "enum::") || strings.has_prefix(type_str, "bitfield::") {
        return "i64"
    }

    return "ObjectPtr"
}

// Godot ptrcall wire types: PtrToArg widens primitives for the pointer-based calling convention.
// float -> double, all integer types smaller than 64-bit -> int64_t, bool -> uint8_t.
// See godot/core/variant/method_ptrcall.h PtrToArg specializations.
convert_meta_type :: proc(meta: string) -> string {
    switch meta {
    case "int8", "int16", "int32", "int64":   return "i64"
    case "uint8", "uint16", "uint32":         return "i64"
    case "uint64":                            return "u64"
    case "float", "double":                   return "f64"
    }
    return ""
}

ODIN_KEYWORDS :: []string{
    "align_of", "auto_cast", "bit_set", "break", "case", "cast", "context",
    "continue", "defer", "distinct", "do", "dynamic", "else", "enum", "fallthrough",
    "false", "for", "foreign", "if", "import", "in", "map", "matrix", "nil",
    "not_in", "offset_of", "or_else", "or_return", "package", "proc", "return",
    "size_of", "struct", "switch", "transmute", "true", "type_info_of", "type_of",
    "typeid", "union", "using", "when", "where",
    "obj", "args", "ret", "singleton",
}

sanitize_identifier :: proc(name: string) -> string {
    for kw in ODIN_KEYWORDS {
        if name == kw {
            return fmt.tprintf("%s_", name)
        }
    }
    return name
}

PASS_BY_VALUE_TYPES :: []string{
    "bool", "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64",
    "f32", "f64", "ObjectPtr", "MethodBindPtr", "rawptr",
    "StringName", "GodotString", "NodePath", "RID",
    "Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i",
    "Rect2", "Rect2i", "Color", "Transform2D", "Plane", "Quaternion",
    "AABB", "Basis", "Transform3D", "Projection",
    "Callable", "Signal", "Array", "Dictionary", "Variant",
    "PackedByteArray", "PackedInt32Array", "PackedInt64Array",
    "PackedFloat32Array", "PackedFloat64Array", "PackedStringArray",
    "PackedVector2Array", "PackedVector3Array", "PackedColorArray",
    "PackedVector4Array",
}

is_pass_by_value_type :: proc(type_name: string) -> bool {
    for t in PASS_BY_VALUE_TYPES {
        if type_name == t {
            return true
        }
    }
    return strings.has_prefix(type_name, "^")
}

// Default Value Conversion (Godot JSON -> Odin literal)
// is_builtin controls bool wire type: builtin methods use u8 (0/1), class methods use bool (true/false).

split_csv :: proc(csv: string) -> [dynamic]string {
    parts: [dynamic]string
    rest := csv
    for len(rest) > 0 {
        if comma := strings.index_byte(rest, ','); comma >= 0 {
            append(&parts, strings.trim_space(rest[:comma]))
            rest = rest[comma+1:]
        } else {
            append(&parts, strings.trim_space(rest))
            break
        }
    }
    return parts
}

// Groups CSV values into brace-wrapped sub-groups of specified sizes.
// e.g. regroup_csv("0, 0, 0, 0", {2, 2}) -> "{0, 0}, {0, 0}"
regroup_csv :: proc(csv: string, group_sizes: []int) -> string {
    parts := split_csv(csv)
    result := strings.builder_make()
    idx := 0
    for gs, gi in group_sizes {
        if gi > 0 { strings.write_string(&result, ", ") }
        if gs > 1 { strings.write_byte(&result, '{') }
        for j in 0..<gs {
            if j > 0 { strings.write_string(&result, ", ") }
            if idx < len(parts) {
                strings.write_string(&result, parts[idx])
                idx += 1
            }
        }
        if gs > 1 { strings.write_byte(&result, '}') }
    }
    return strings.to_string(result)
}

// Transform3D = Basis{{Vec3, Vec3, Vec3}} + origin Vec3 -> {{3,3,3}, 3}
regroup_transform3d :: proc(csv: string) -> string {
    parts := split_csv(csv)
    basis_csv := strings.join(parts[:min(9, len(parts))], ", ")
    origin_csv := strings.join(parts[min(9, len(parts)):min(12, len(parts))], ", ")
    return fmt.tprintf("{{%s}}, {{%s}}", regroup_csv(basis_csv, []int{3, 3, 3}), origin_csv)
}

convert_default_value :: proc(godot_default: string, odin_type: string, is_builtin: bool) -> Maybe(string) {
    dv := godot_default

    // Variant is an opaque type — defaults require construction, skip
    if odin_type == "Variant" { return nil }

    // Booleans
    if dv == "true"  { return "1" if is_builtin else "true" }
    if dv == "false" { return "0" if is_builtin else "false" }

    // null -> nil for pointers, zero-value for structs
    if dv == "null" {
        if odin_type == "ObjectPtr" || strings.has_prefix(odin_type, "^") {
            return "nil"
        }
        return fmt.tprintf("%s{{}}", odin_type)
    }

    // Numeric literals (ints, floats, negative signs, scientific notation) — pass through
    if len(dv) > 0 && (dv[0] == '-' || dv[0] >= '0' && dv[0] <= '9') {
        return dv
    }

    // Empty string / empty StringName / empty NodePath -> zero-value struct
    if dv == "\"\"" && (odin_type == "GodotString" || odin_type == "String") {
        return "GodotString{}"
    }
    if dv == "&\"\"" {
        return "StringName{}"
    }
    if dv == "NodePath(\"\")" {
        return "NodePath{}"
    }

    // Non-empty strings/StringNames require allocation — skip default
    if dv[0] == '"' || strings.has_prefix(dv, "&\"") {
        return nil
    }

    // Zero-value constructors: Callable(), RID(), PackedByteArray(), etc.
    if strings.has_suffix(dv, "()") {
        name := dv[:len(dv)-2]
        if name == "String" { name = "GodotString" }
        return fmt.tprintf("%s{{}}", name)
    }

    // Empty array/dict literals
    if dv == "[]" { return "Array{}" }
    if dv == "{}" { return "Dictionary{}" }

    // Typed arrays: Array[RID]([]) etc. -> Array{}
    if strings.has_prefix(dv, "Array[") {
        return "Array{}"
    }

    // Struct constructors: Vector2(0, 0) -> Vector2{0, 0}
    // Composite structs regroup flat CSV values into nested brace groups.
    if paren := strings.index_byte(dv, '('); paren >= 0 && strings.has_suffix(dv, ")") {
        type_name := dv[:paren]
        inner := dv[paren+1:len(dv)-1]
        odin_name := type_name
        if type_name == "String" { odin_name = "GodotString" }

        grouped: string
        switch type_name {
        case "Rect2", "Rect2i": grouped = regroup_csv(inner, []int{2, 2})
        case "AABB":            grouped = regroup_csv(inner, []int{3, 3})
        case "Transform2D":     grouped = regroup_csv(inner, []int{2, 2, 2})
        case "Basis":           grouped = regroup_csv(inner, []int{3, 3, 3})
        case "Transform3D":     grouped = regroup_transform3d(inner)
        case "Projection":      grouped = regroup_csv(inner, []int{4, 4, 4, 4})
        case "Plane":           grouped = regroup_csv(inner, []int{3, 1})
        case:                   grouped = inner
        }

        return fmt.tprintf("%s{{%s}}", odin_name, grouped)
    }

    return nil
}

// Code Writing Helpers

writeln :: proc(g: ^Generator, s: string = "") {
    for _ in 0..<g.indent {
        strings.write_string(&g.output, "    ")
    }
    strings.write_string(&g.output, s)
    strings.write_string(&g.output, "\n")
}

writef :: proc(g: ^Generator, format: string, args: ..any) {
    for _ in 0..<g.indent {
        strings.write_string(&g.output, "    ")
    }
    strings.write_string(&g.output, fmt.tprintf(format, ..args))
}

write_comment :: proc(g: ^Generator, lines: []string) {
    if len(lines) == 0 do return
    for line in lines {
        writef(g, "// %s\n", line)
    }
}

// Type Generation

strip_gdext_prefix :: proc(name: string) -> string {
    if strings.has_prefix(name, "GDEXTENSION_") {
        return name[12:]
    }
    return name
}

generate_enum :: proc(g: ^Generator, t: ^Type_Def) {
    write_comment(g, t.description)
    is_bitfield := t.is_bitfield.? or_else false

    if is_bitfield {
        writef(g, "%s :: distinct i32\n", t.name)
        writeln(g)
        for v in t.values {
            write_comment(g, v.description)
            writef(g, "%s_%s :: %s(%d)\n", t.name, strip_gdext_prefix(v.name), t.name, v.value)
        }
        writeln(g)
    } else {
        writef(g, "%s :: enum i32 {{\n", t.name)
        g.indent += 1
        for v in t.values {
            write_comment(g, v.description)
            writef(g, "%s = %d,\n", strip_gdext_prefix(v.name), v.value)
        }
        g.indent -= 1
        writeln(g, "}")
        writeln(g)
    }
}

generate_handle :: proc(g: ^Generator, t: ^Type_Def) {
    write_comment(g, t.description)
    writef(g, "%s :: distinct rawptr\n", t.name)
    writeln(g)
}

generate_alias :: proc(g: ^Generator, t: ^Type_Def) {
    write_comment(g, t.description)
    aliased_type := t.type.? or_else "rawptr"
    odin_type := convert_type(g, aliased_type)
    writef(g, "%s :: distinct %s\n", t.name, odin_type)
    writeln(g)
}

generate_struct :: proc(g: ^Generator, t: ^Type_Def) {
    write_comment(g, t.description)
    writef(g, "%s :: struct {{\n", t.name)
    g.indent += 1

    for m in t.members {
        write_comment(g, m.description)
        odin_type := m.type if m.type in g.func_types else convert_type(g, m.type)
        writef(g, "%s: %s,\n", m.name, odin_type)
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
}

generate_function_type :: proc(g: ^Generator, t: ^Type_Def) {
    write_comment(g, t.description)
    args := build_args_list(g, t.arguments)
    ret_type := get_return_type(g, t.return_value)

    if len(ret_type) > 0 && ret_type != "void" {
        writef(g, "%s :: #type proc \"c\" (%s) -> %s\n", t.name, args, ret_type)
    } else {
        writef(g, "%s :: #type proc \"c\" (%s)\n", t.name, args)
    }
    writeln(g)
}

build_args_list :: proc(g: ^Generator, arguments: []Function_Argument) -> string {
    args := strings.builder_make()
    for arg, i in arguments {
        if i > 0 {
            strings.write_string(&args, ", ")
        }
        arg_name := arg.name if len(arg.name) > 0 else fmt.tprintf("arg%d", i)
        arg_type := arg.type if arg.type in g.func_types else convert_type(g, arg.type)
        strings.write_string(&args, fmt.tprintf("%s: %s", arg_name, arg_type))
    }
    return strings.to_string(args)
}

get_return_type :: proc(g: ^Generator, return_value: Maybe(Return_Value)) -> string {
    if rv, ok := return_value.?; ok {
        return convert_type(g, rv.type)
    }
    return ""
}

// Interface Function Generation

generate_interface_function :: proc(g: ^Generator, f: ^Interface_Func) {
    if _, ok := f.deprecated.?; ok {
        return
    }

    write_comment(g, f.description)
    args := build_args_list(g, f.arguments)
    ret_type := get_return_type(g, f.return_value)

    if len(ret_type) > 0 && ret_type != "void" {
        writef(g, "%s: proc \"c\" (%s) -> %s,\n", f.name, args, ret_type)
    } else {
        writef(g, "%s: proc \"c\" (%s),\n", f.name, args)
    }
}

// Engine Class Method Generation

is_bindable_method :: proc(m: ^API_Method) -> bool {
    return !m.is_virtual && !m.is_vararg
}

is_vararg_class_method :: proc(m: ^API_Method) -> bool {
    return m.is_vararg && !m.is_virtual
}

has_bindable_methods :: proc(cls: ^API_Class) -> bool {
    for &m in cls.methods {
        if is_bindable_method(&m) do return true
    }
    return false
}

// True if the class has any non-virtual methods (bindable or vararg).
has_any_non_virtual_methods :: proc(cls: ^API_Class) -> bool {
    for &m in cls.methods {
        if !m.is_virtual do return true
    }
    return false
}

// Convert SCREAMING_SNAKE to PascalCase: "TOP_LEFT" -> "TopLeft", "STOP" -> "Stop"
screaming_to_pascal :: proc(name: string) -> string {
    result := strings.builder_make()
    parts := strings.split(name, "_")
    for part in parts {
        if len(part) == 0 do continue
        for r, i in part {
            if i == 0 {
                strings.write_rune(&result, unicode.to_upper(r))
            } else {
                strings.write_rune(&result, unicode.to_lower(r))
            }
        }
    }
    return strings.to_string(result)
}

// Find the common SCREAMING_SNAKE prefix segments shared by all enum values.
// Returns the number of underscore-separated segments that are common.
enum_common_prefix_len :: proc(e: ^API_Enum) -> int {
    if len(e.values) < 2 do return 0

    first_parts := strings.split(e.values[0].name, "_")
    prefix_len := 0

    for i in 0..<len(first_parts) {
        all_match := true
        for &v in e.values[1:] {
            v_parts := strings.split(v.name, "_")
            if i >= len(v_parts) || v_parts[i] != first_parts[i] {
                all_match = false
                break
            }
        }
        if all_match {
            prefix_len = i + 1
        } else {
            break
        }
    }
    return prefix_len
}

// Strip the common prefix segments from an enum value name and convert to PascalCase.
// Prepends '_' if the result starts with a digit (invalid Odin identifier).
strip_enum_prefix :: proc(name: string, prefix_seg_count: int) -> string {
    parts := strings.split(name, "_")
    start := min(prefix_seg_count, len(parts) - 1)
    remaining := strings.join(parts[start:], "_")
    pascal := screaming_to_pascal(remaining)

    if len(pascal) > 0 && pascal[0] >= '0' && pascal[0] <= '9' {
        return fmt.tprintf("_%s", pascal)
    }
    return pascal
}

// Check if an enum has duplicate values (which prevents using Odin enum)
enum_has_duplicate_values :: proc(e: ^API_Enum) -> bool {
    for i in 0..<len(e.values) {
        for j in (i + 1)..<len(e.values) {
            if e.values[i].value == e.values[j].value {
                return true
            }
        }
    }
    return false
}

generate_enum_type :: proc(g: ^Generator, e: ^API_Enum, type_name: string) {
    if e.is_bitfield || enum_has_duplicate_values(e) {
        // Flat constants
        writef(g, "%s :: distinct i64\n", type_name)
        for &v in e.values {
            writef(g, "%s_%s :: %s(%d)\n", type_name, screaming_to_pascal(v.name), type_name, v.value)
        }
    } else {
        // Proper enum
        prefix_len := enum_common_prefix_len(e)
        writef(g, "%s :: enum i64 {{\n", type_name)
        g.indent += 1
        for &v in e.values {
            pascal := strip_enum_prefix(v.name, prefix_len)
            writef(g, "%s = %d,\n", pascal, v.value)
        }
        g.indent -= 1
        writeln(g, "}")
    }
    writeln(g)
}

generate_global_enums :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "GLOBAL ENUMS")

    for &e in api.global_enums {
        // Replace dots with underscores (e.g. "Variant.Type" -> "Variant_Type")
        type_name := e.name
        if strings.contains(type_name, ".") {
            type_name, _ = strings.replace_all(type_name, ".", "_")
        }
        generate_enum_type(g, &e, type_name)
    }
}

generate_class_constants :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "ENGINE CLASS CONSTANTS & ENUMS")

    for &cls in api.classes {
        if len(cls.constants) == 0 && len(cls.enums) == 0 do continue

        writef(g, "// %s\n", cls.name)
        for &c in cls.constants {
            writef(g, "%s_%s :: %d\n", cls.name, screaming_to_pascal(c.name), c.value)
        }
        for &e in cls.enums {
            type_name := fmt.tprintf("%s_%s", cls.name, e.name)
            generate_enum_type(g, &e, type_name)
        }
        writeln(g)
    }
}

generate_class_name_strings :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "CLASS NAME CONSTANTS (cstring, compile-time)")

    for &cls in api.classes {
        writef(g, "type_%s_cstr :: \"%s\"\n", cls.name, cls.name)
    }
    writeln(g)

    write_section_header(g, "CLASS NAME STRINGS (GodotString, cached at init_class_names)")

    for &cls in api.classes {
        writef(g, "type_%s_gstr: GodotString\n", cls.name)
    }
    writeln(g)

    writeln(g, "init_class_names :: proc() {")
    g.indent += 1
    for &cls in api.classes {
        writef(g, "type_%s_gstr = godot_string_from_cstring(\"%s\")\n", cls.name, cls.name)
    }
    g.indent -= 1
    writeln(g, "}")
    writeln(g)
}

generate_method_binds_struct :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "METHOD BINDS (cached at init_scene)")
    writeln(g, "@(private)")
    writeln(g, "MethodBinds :: struct {")
    g.indent += 1

    for &cls in api.classes {
        if !has_any_non_virtual_methods(&cls) do continue

        writef(g, "// %s\n", cls.name)
        for &m in cls.methods {
            if m.is_virtual do continue
            writef(g, "%s_%s: MethodBindPtr,\n", cls.name, m.name)
        }
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
    writeln(g, "@(private)")
    writeln(g, "method_binds: MethodBinds")
    writeln(g)
}

generate_init_scene :: proc(g: ^Generator, api: ^Extension_API) {
    writeln(g, "init_scene :: proc() {")
    g.indent += 1

    for &cls in api.classes {
        if !has_any_non_virtual_methods(&cls) do continue

        for &m in cls.methods {
            if m.is_virtual do continue
            writef(g, "method_binds.%s_%s = get_method_bind(\"%s\", \"%s\", %d)\n",
                   cls.name, m.name, cls.name, m.name, m.hash)
        }
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
}

generate_init_bindings :: proc(g: ^Generator) {
    writeln(g, "init_scene_bindings :: proc() {")
    g.indent += 1
    writeln(g, "init_scene()")
    writeln(g, "init_class_names()")
    writeln(g, "init_builtin_methods()")
    writeln(g, "init_builtin_lifecycle()")
    writeln(g, "init_builtin_constructors()")
    writeln(g, "init_utility_functions()")
    writeln(g, "init_vararg_utility_functions()")
    writeln(g, "init_variant_converters()")
    g.indent -= 1
    writeln(g, "}")
    writeln(g)
}

generate_method_wrappers :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "ENGINE CLASS METHOD WRAPPERS")

    for &cls in api.classes {
        if !has_bindable_methods(&cls) do continue

        is_singleton := g.singleton_set[cls.name]
        writef(g, "// %s\n", cls.name)

        for &m in cls.methods {
            if !is_bindable_method(&m) do continue
            generate_method_wrapper(g, &cls, &m, is_singleton)
        }
        writeln(g)
    }
}

get_arg_type_with_meta :: proc(g: ^Generator, arg: API_MethodArg) -> string {
    arg_type := convert_type(g, arg.type)
    if meta, ok := arg.meta.?; ok {
        if meta_type := convert_meta_type(meta); len(meta_type) > 0 {
            return meta_type
        }
    }
    return arg_type
}

get_return_type_with_meta :: proc(g: ^Generator, return_value: Maybe(API_MethodReturn)) -> string {
    if rv, ok := return_value.?; ok {
        ret_type := convert_type(g, rv.type)
        if meta, ok := rv.meta.?; ok {
            if meta_type := convert_meta_type(meta); len(meta_type) > 0 {
                return meta_type
            }
        }
        return ret_type
    }
    return ""
}

generate_method_wrapper :: proc(g: ^Generator, cls: ^API_Class, m: ^API_Method, is_singleton: bool) {
    method_name := fmt.tprintf("%s_%s", cls.name, m.name)

    args := strings.builder_make()
    if !m.is_static && !is_singleton {
        strings.write_string(&args, "obj: ObjectPtr")
    }

    for arg in m.arguments {
        if strings.builder_len(args) > 0 {
            strings.write_string(&args, ", ")
        }
        arg_type := get_arg_type_with_meta(g, arg)
        safe_name := sanitize_identifier(arg.name)
        if dv_str, has_dv := arg.default_value.?; has_dv {
            if odin_dv, ok := convert_default_value(dv_str, arg_type, false).?; ok {
                strings.write_string(&args, fmt.tprintf("%s: %s = %s", safe_name, arg_type, odin_dv))
                continue
            }
        }
        strings.write_string(&args, fmt.tprintf("%s: %s", safe_name, arg_type))
    }

    ret_type := get_return_type_with_meta(g, m.return_value)

    if len(ret_type) > 0 {
        writef(g, "%s :: proc(%s) -> %s {{\n", method_name, strings.to_string(args), ret_type)
    } else {
        writef(g, "%s :: proc(%s) {{\n", method_name, strings.to_string(args))
    }
    g.indent += 1

    if is_singleton {
        writef(g, "singleton := get_singleton(\"%s\")\n", cls.name)
    }

    num_args := len(m.arguments)
    if num_args > 0 {
        for arg, i in m.arguments {
            arg_type := get_arg_type_with_meta(g, arg)
            safe_name := sanitize_identifier(arg.name)
            if is_pass_by_value_type(arg_type) {
                writef(g, "arg%d := %s\n", i, safe_name)
            }
        }

        writef(g, "call_args: [%d]ConstTypePtr\n", num_args)
        for arg, i in m.arguments {
            arg_type := get_arg_type_with_meta(g, arg)
            safe_name := sanitize_identifier(arg.name)
            if is_pass_by_value_type(arg_type) {
                writef(g, "call_args[%d] = cast(ConstTypePtr)&arg%d\n", i, i)
            } else {
                writef(g, "call_args[%d] = cast(ConstTypePtr)&%s\n", i, safe_name)
            }
        }
    }

    obj_ref: string
    if m.is_static {
        obj_ref = "nil"
    } else if is_singleton {
        obj_ref = "singleton"
    } else {
        obj_ref = "obj"
    }
    args_ref := "&call_args[0]" if num_args > 0 else "nil"

    if len(ret_type) > 0 {
        writef(g, "ret: %s\n", ret_type)
        writef(g, "ptrcall(method_binds.%s, %s, %s, cast(TypePtr)&ret)\n", method_name, obj_ref, args_ref)
        writeln(g, "return ret")
    } else {
        writef(g, "ptrcall(method_binds.%s, %s, %s, nil)\n", method_name, obj_ref, args_ref)
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
}

// Builtin Type Generation

meta_to_odin_type :: proc(meta: string) -> string {
    switch meta {
    case "float":  return "f32"
    case "double": return "f64"
    case "int32":  return "i32"
    case "int64":  return "i64"
    case "uint32": return "u32"
    case "uint64": return "u64"
    }
    return meta
}

PRIMITIVE_TYPES :: []string{"Nil", "bool", "int", "float", "Object"}

is_primitive_type :: proc(name: string) -> bool {
    for t in PRIMITIVE_TYPES {
        if name == t do return true
    }
    return false
}

generate_builtin_types :: proc(g: ^Generator, api: ^Extension_API) {
    sizes: ^[]API_Size
    offsets: ^[]API_ClassMemberOffsets

    for &cfg in api.builtin_class_sizes {
        if cfg.build_configuration == "float_64" {
            sizes = &cfg.sizes
            break
        }
    }
    for &cfg in api.builtin_class_member_offsets {
        if cfg.build_configuration == "float_64" {
            offsets = &cfg.classes
            break
        }
    }

    assert(sizes != nil, "float_64 build configuration not found in builtin_class_sizes — is this the right extension_api.json?")
    assert(offsets != nil, "float_64 build configuration not found in builtin_class_member_offsets — is this the right extension_api.json?")

    offset_map := make(map[string]^API_ClassMemberOffsets)
    if offsets != nil {
        for &cls in offsets^ {
            offset_map[cls.name] = &cls
        }
    }

    for &s in sizes^ {
        if is_primitive_type(s.name) do continue

        odin_name := "GodotString" if s.name == "String" else s.name

        writef(g, "%s :: struct {{\n", odin_name)
        g.indent += 1
        if cls, ok := offset_map[s.name]; ok {
            for &m in cls.members {
                writef(g, "%s: %s,\n", m.member, meta_to_odin_type(m.meta))
            }
        } else {
            writef(g, "data: [%d]u8,\n", s.size)
        }
        g.indent -= 1
        writeln(g, "}")
        writeln(g)
    }
}

// Builtin Class Method & Lifecycle Generation

builtin_name_to_variant_type :: proc(name: string) -> string {
    switch name {
    case "bool":             return "VARIANT_TYPE_BOOL"
    case "int":              return "VARIANT_TYPE_INT"
    case "float":            return "VARIANT_TYPE_FLOAT"
    case "String":           return "VARIANT_TYPE_STRING"
    case "Vector2":          return "VARIANT_TYPE_VECTOR2"
    case "Vector2i":         return "VARIANT_TYPE_VECTOR2I"
    case "Rect2":            return "VARIANT_TYPE_RECT2"
    case "Rect2i":           return "VARIANT_TYPE_RECT2I"
    case "Vector3":          return "VARIANT_TYPE_VECTOR3"
    case "Vector3i":         return "VARIANT_TYPE_VECTOR3I"
    case "Transform2D":      return "VARIANT_TYPE_TRANSFORM2D"
    case "Vector4":          return "VARIANT_TYPE_VECTOR4"
    case "Vector4i":         return "VARIANT_TYPE_VECTOR4I"
    case "Plane":            return "VARIANT_TYPE_PLANE"
    case "Quaternion":       return "VARIANT_TYPE_QUATERNION"
    case "AABB":             return "VARIANT_TYPE_AABB"
    case "Basis":            return "VARIANT_TYPE_BASIS"
    case "Transform3D":      return "VARIANT_TYPE_TRANSFORM3D"
    case "Projection":       return "VARIANT_TYPE_PROJECTION"
    case "Color":            return "VARIANT_TYPE_COLOR"
    case "StringName":       return "VARIANT_TYPE_STRING_NAME"
    case "NodePath":         return "VARIANT_TYPE_NODE_PATH"
    case "RID":              return "VARIANT_TYPE_RID"
    case "Object":           return "VARIANT_TYPE_OBJECT"
    case "Callable":         return "VARIANT_TYPE_CALLABLE"
    case "Signal":           return "VARIANT_TYPE_SIGNAL"
    case "Dictionary":       return "VARIANT_TYPE_DICTIONARY"
    case "Array":            return "VARIANT_TYPE_ARRAY"
    case "PackedByteArray":  return "VARIANT_TYPE_PACKED_BYTE_ARRAY"
    case "PackedInt32Array":  return "VARIANT_TYPE_PACKED_INT32_ARRAY"
    case "PackedInt64Array":  return "VARIANT_TYPE_PACKED_INT64_ARRAY"
    case "PackedFloat32Array": return "VARIANT_TYPE_PACKED_FLOAT32_ARRAY"
    case "PackedFloat64Array": return "VARIANT_TYPE_PACKED_FLOAT64_ARRAY"
    case "PackedStringArray":  return "VARIANT_TYPE_PACKED_STRING_ARRAY"
    case "PackedVector2Array": return "VARIANT_TYPE_PACKED_VECTOR2_ARRAY"
    case "PackedVector3Array": return "VARIANT_TYPE_PACKED_VECTOR3_ARRAY"
    case "PackedColorArray":   return "VARIANT_TYPE_PACKED_COLOR_ARRAY"
    case "PackedVector4Array": return "VARIANT_TYPE_PACKED_VECTOR4_ARRAY"
    }
    return ""
}

builtin_odin_type_name :: proc(name: string) -> string {
    if name == "String" do return "GodotString"
    return name
}

// Convert a builtin method arg/return type to the Odin wire type.
// Builtin methods use the same widening as engine ptrcalls: float->f64, int->i64, bool->u8.
convert_builtin_type :: proc(g: ^Generator, type_name: string) -> string {
    switch type_name {
    case "float":  return "f64"
    case "int":    return "i64"
    case "bool":   return "u8"
    case "String": return "GodotString"
    case "Object": return "ObjectPtr"
    }
    if mapped, ok := g.type_map[type_name]; ok {
        return mapped
    }
    if strings.has_prefix(type_name, "enum::") || strings.has_prefix(type_name, "bitfield::") {
        return "i64"
    }
    if strings.has_prefix(type_name, "typedarray::") {
        return "Array"
    }
    return type_name
}

is_bindable_builtin_method :: proc(m: ^API_BuiltinMethod) -> bool {
    return !m.is_vararg
}

has_bindable_builtin_methods :: proc(cls: ^API_BuiltinClass) -> bool {
    if is_primitive_type(cls.name) do return false
    for &m in cls.methods {
        if is_bindable_builtin_method(&m) do return true
    }
    return false
}

generate_builtin_method_binds_struct :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "BUILTIN METHOD BINDS (cached at init_builtin_methods)")
    writeln(g, "@(private)")
    writeln(g, "BuiltinMethodBinds :: struct {")
    g.indent += 1

    for &cls in api.builtin_classes {
        if !has_bindable_builtin_methods(&cls) do continue

        writef(g, "// %s\n", cls.name)
        for &m in cls.methods {
            if !is_bindable_builtin_method(&m) do continue
            writef(g, "%s_%s: BuiltinMethodBindPtr,\n", builtin_odin_type_name(cls.name), m.name)
        }
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
    writeln(g, "@(private)")
    writeln(g, "builtin_method_binds: BuiltinMethodBinds")
    writeln(g)
}

generate_init_builtin_methods :: proc(g: ^Generator, api: ^Extension_API) {
    writeln(g, "init_builtin_methods :: proc() {")
    g.indent += 1

    for &cls in api.builtin_classes {
        if !has_bindable_builtin_methods(&cls) do continue

        variant_type := builtin_name_to_variant_type(cls.name)
        if len(variant_type) == 0 do continue

        for &m in cls.methods {
            if !is_bindable_builtin_method(&m) do continue
            odin_cls := builtin_odin_type_name(cls.name)
            writef(g, "{{\n")
            g.indent += 1
            writef(g, "sn := string_name_from_cstring(\"%s\")\n", m.name)
            writef(g, "builtin_method_binds.%s_%s = cast(BuiltinMethodBindPtr)gde_interface.variant_get_ptr_builtin_method(.%s, cast(GDExtensionConstStringNamePtr)&sn, %d)\n",
                   odin_cls, m.name, variant_type, m.hash)
            writeln(g, "destroy_string_name(&sn)")
            g.indent -= 1
            writef(g, "}}\n")
        }
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
}

generate_builtin_method_wrappers :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "BUILTIN CLASS METHOD WRAPPERS")

    for &cls in api.builtin_classes {
        if !has_bindable_builtin_methods(&cls) do continue

        odin_cls := builtin_odin_type_name(cls.name)
        writef(g, "// %s\n", cls.name)

        for &m in cls.methods {
            if !is_bindable_builtin_method(&m) do continue
            generate_builtin_method_wrapper(g, &cls, &m, odin_cls)
        }
        writeln(g)
    }
}

generate_builtin_method_wrapper :: proc(g: ^Generator, cls: ^API_BuiltinClass, m: ^API_BuiltinMethod, odin_cls: string) {
    method_name := fmt.tprintf("%s_%s", odin_cls, m.name)

    args := strings.builder_make()
    if !m.is_static {
        strings.write_string(&args, fmt.tprintf("self: ^%s", odin_cls))
    }

    for arg in m.arguments {
        if strings.builder_len(args) > 0 {
            strings.write_string(&args, ", ")
        }
        arg_type := convert_builtin_type(g, arg.type)
        safe_name := sanitize_identifier(arg.name)
        if dv_str, has_dv := arg.default_value.?; has_dv {
            if odin_dv, ok := convert_default_value(dv_str, arg_type, true).?; ok {
                strings.write_string(&args, fmt.tprintf("%s: %s = %s", safe_name, arg_type, odin_dv))
                continue
            }
        }
        strings.write_string(&args, fmt.tprintf("%s: %s", safe_name, arg_type))
    }

    ret_type := ""
    if rt, ok := m.return_type.?; ok {
        ret_type = convert_builtin_type(g, rt)
    }

    // Signature
    if len(ret_type) > 0 {
        writef(g, "%s :: proc(%s) -> %s {{\n", method_name, strings.to_string(args), ret_type)
    } else {
        writef(g, "%s :: proc(%s) {{\n", method_name, strings.to_string(args))
    }
    g.indent += 1

    num_args := len(m.arguments)

    // Copy pass-by-value args to locals
    if num_args > 0 {
        for arg, i in m.arguments {
            arg_type := convert_builtin_type(g, arg.type)
            safe_name := sanitize_identifier(arg.name)
            if is_pass_by_value_type(arg_type) {
                writef(g, "arg%d := %s\n", i, safe_name)
            }
        }

        writef(g, "call_args: [%d]GDExtensionConstTypePtr\n", num_args)
        for arg, i in m.arguments {
            arg_type := convert_builtin_type(g, arg.type)
            safe_name := sanitize_identifier(arg.name)
            if is_pass_by_value_type(arg_type) {
                writef(g, "call_args[%d] = cast(GDExtensionConstTypePtr)&arg%d\n", i, i)
            } else {
                writef(g, "call_args[%d] = cast(GDExtensionConstTypePtr)&%s\n", i, safe_name)
            }
        }
    }

    base_ref: string
    if m.is_static {
        base_ref = "nil"
    } else {
        base_ref = "cast(GDExtensionTypePtr)self"
    }
    args_ref := "&call_args[0]" if num_args > 0 else "nil"

    if len(ret_type) > 0 {
        writef(g, "ret: %s\n", ret_type)
        writef(g, "builtin_method_binds.%s(%s, %s, cast(GDExtensionTypePtr)&ret, %d)\n",
               method_name, base_ref, args_ref, num_args)
        writeln(g, "return ret")
    } else {
        writef(g, "builtin_method_binds.%s(%s, %s, nil, %d)\n",
               method_name, base_ref, args_ref, num_args)
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
}

// Lifecycle: constructors/destructors for heap-backed builtin types

has_lifecycle :: proc(cls: ^API_BuiltinClass) -> bool {
    return cls.has_destructor
}

generate_builtin_lifecycle_struct :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "BUILTIN LIFECYCLE (cached at init_builtin_lifecycle)")
    writeln(g, "@(private)")
    writeln(g, "BuiltinLifecycle :: struct {")
    g.indent += 1

    for &cls in api.builtin_classes {
        if !has_lifecycle(&cls) do continue
        odin_cls := builtin_odin_type_name(cls.name)

        // Default constructor (index 0)
        writef(g, "%s_constructor_0: GDExtensionPtrConstructor,\n", odin_cls)
        // For Callable, also cache constructor 2 (Object, StringName)
        if cls.name == "Callable" {
            writef(g, "%s_constructor_2: GDExtensionPtrConstructor,\n", odin_cls)
        }
        // Destructor
        writef(g, "%s_destructor: GDExtensionPtrDestructor,\n", odin_cls)
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
    writeln(g, "@(private)")
    writeln(g, "builtin_lifecycle: BuiltinLifecycle")
    writeln(g)
}

generate_init_builtin_lifecycle :: proc(g: ^Generator, api: ^Extension_API) {
    writeln(g, "init_builtin_lifecycle :: proc() {")
    g.indent += 1

    for &cls in api.builtin_classes {
        if !has_lifecycle(&cls) do continue
        odin_cls := builtin_odin_type_name(cls.name)
        variant_type := builtin_name_to_variant_type(cls.name)
        if len(variant_type) == 0 do continue

        writef(g, "builtin_lifecycle.%s_constructor_0 = gde_interface.variant_get_ptr_constructor(.%s, 0)\n",
               odin_cls, variant_type)
        if cls.name == "Callable" {
            writef(g, "builtin_lifecycle.%s_constructor_2 = gde_interface.variant_get_ptr_constructor(.%s, 2)\n",
                   odin_cls, variant_type)
        }
        writef(g, "builtin_lifecycle.%s_destructor = gde_interface.variant_get_ptr_destructor(.%s)\n",
               odin_cls, variant_type)
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
}

generate_builtin_lifecycle_wrappers :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "BUILTIN CREATE/DESTROY WRAPPERS")

    for &cls in api.builtin_classes {
        if !has_lifecycle(&cls) do continue
        odin_cls := builtin_odin_type_name(cls.name)

        // Create (default constructor)
        writef(g, "%s_default :: proc() -> %s {{\n", odin_cls, odin_cls)
        g.indent += 1
        writef(g, "val: %s\n", odin_cls)
        writef(g, "builtin_lifecycle.%s_constructor_0(cast(GDExtensionUninitializedTypePtr)&val, nil)\n", odin_cls)
        writeln(g, "return val")
        g.indent -= 1
        writeln(g, "}")
        writeln(g)

        // Destroy
        writef(g, "%s_destroy :: proc(val: ^%s) {{\n", odin_cls, odin_cls)
        g.indent += 1
        writef(g, "builtin_lifecycle.%s_destructor(cast(GDExtensionTypePtr)val)\n", odin_cls)
        g.indent -= 1
        writeln(g, "}")
        writeln(g)
    }
}

// Signal Name Constants

generate_signal_constants :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "SIGNAL NAME CONSTANTS")

    for &cls in api.classes {
        if len(cls.signals) == 0 do continue

        writef(g, "// %s\n", cls.name)
        for &sig in cls.signals {
            writef(g, "%s_Signal_%s :: \"%s\"\n", cls.name, screaming_to_pascal(sig.name), sig.name)
        }
        writeln(g)
    }
}

// Builtin Class Constants (Vector2_Zero, Color_Alice_Blue, etc.)

// Replace "inf" with Odin's float infinity literal
fix_inf :: proc(val: string) -> string {
    trimmed := strings.trim_space(val)
    if trimmed == "inf" do return "0h7F800000"
    if trimmed == "-inf" do return "-0h7F800000"
    return trimmed
}

// Split a comma-separated value string, respecting that values are just numbers/inf
split_values :: proc(inner: string) -> [dynamic]string {
    parts: [dynamic]string
    for part in strings.split(inner, ",") {
        append(&parts, fix_inf(part))
    }
    return parts
}

parse_builtin_constant_value :: proc(type_name: string, value_str: string) -> string {
    odin_type := builtin_odin_type_name(type_name)

    paren_idx := strings.index_byte(value_str, '(')
    if paren_idx < 0 {
        return value_str
    }
    inner := value_str[paren_idx+1:len(value_str)-1]
    vals := split_values(inner)

    // Flat struct types: just wrap values directly
    switch type_name {
    case "Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i",
         "Color", "Quaternion":
        b := strings.builder_make()
        fmt.sbprintf(&b, "%s{{", odin_type)
        for v, i in vals {
            if i > 0 do strings.write_string(&b, ", ")
            strings.write_string(&b, v)
        }
        strings.write_string(&b, "}")
        return strings.to_string(b)

    case "Transform2D":
        // 6 floats -> x: Vector2, y: Vector2, origin: Vector2
        if len(vals) == 6 {
            return fmt.tprintf("Transform2D{{x = {{%s, %s}}, y = {{%s, %s}}, origin = {{%s, %s}}}}",
                vals[0], vals[1], vals[2], vals[3], vals[4], vals[5])
        }

    case "Plane":
        // 4 values -> normal: Vector3, d: f32
        if len(vals) == 4 {
            return fmt.tprintf("Plane{{normal = {{%s, %s, %s}}, d = %s}}",
                vals[0], vals[1], vals[2], vals[3])
        }

    case "Basis":
        // 9 floats -> x: Vector3, y: Vector3, z: Vector3
        if len(vals) == 9 {
            return fmt.tprintf("Basis{{x = {{%s, %s, %s}}, y = {{%s, %s, %s}}, z = {{%s, %s, %s}}}}",
                vals[0], vals[1], vals[2], vals[3], vals[4], vals[5], vals[6], vals[7], vals[8])
        }

    case "Transform3D":
        // 12 floats -> basis: Basis(9), origin: Vector3(3)
        if len(vals) == 12 {
            return fmt.tprintf("Transform3D{{basis = {{x = {{%s, %s, %s}}, y = {{%s, %s, %s}}, z = {{%s, %s, %s}}}}, origin = {{%s, %s, %s}}}}",
                vals[0], vals[1], vals[2], vals[3], vals[4], vals[5], vals[6], vals[7], vals[8],
                vals[9], vals[10], vals[11])
        }

    case "Projection":
        // 16 floats -> x: Vector4, y: Vector4, z: Vector4, w: Vector4
        if len(vals) == 16 {
            return fmt.tprintf("Projection{{x = {{%s, %s, %s, %s}}, y = {{%s, %s, %s, %s}}, z = {{%s, %s, %s, %s}}, w = {{%s, %s, %s, %s}}}}",
                vals[0], vals[1], vals[2], vals[3], vals[4], vals[5], vals[6], vals[7],
                vals[8], vals[9], vals[10], vals[11], vals[12], vals[13], vals[14], vals[15])
        }
    }

    // Fallback: skip this constant (shouldn't get here)
    return ""
}

generate_builtin_constants :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "BUILTIN CLASS CONSTANTS")

    for &cls in api.builtin_classes {
        if len(cls.constants) == 0 do continue

        odin_cls := builtin_odin_type_name(cls.name)
        writef(g, "// %s\n", cls.name)

        for &c in cls.constants {
            const_name := screaming_to_pascal(c.name)
            val := parse_builtin_constant_value(c.type, c.value)
            if len(val) == 0 do continue
            writef(g, "%s_%s :: %s\n", odin_cls, const_name, val)
        }
        writeln(g)
    }
}

// Non-default Builtin Constructors

generate_builtin_constructor_binds :: proc(g: ^Generator, api: ^Extension_API) {
    // Add non-default constructor function pointers to the lifecycle struct
    // These are added separately because the lifecycle struct already exists
    // We need a new struct for these
    write_section_header(g, "BUILTIN CONSTRUCTOR BINDS (cached at init_builtin_constructors)")
    writeln(g, "@(private)")
    writeln(g, "BuiltinConstructorBinds :: struct {")
    g.indent += 1

    for &cls in api.builtin_classes {
        if !has_lifecycle(&cls) do continue
        odin_cls := builtin_odin_type_name(cls.name)

        for &ctor in cls.constructors {
            if len(ctor.arguments) == 0 do continue
            // Skip copy constructors (same type as class)
            if len(ctor.arguments) == 1 && ctor.arguments[0].type == cls.name do continue
            writef(g, "%s_constructor_%d: GDExtensionPtrConstructor,\n", odin_cls, ctor.index)
        }
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
    writeln(g, "@(private)")
    writeln(g, "builtin_constructor_binds: BuiltinConstructorBinds")
    writeln(g)
}

generate_init_builtin_constructors :: proc(g: ^Generator, api: ^Extension_API) {
    writeln(g, "init_builtin_constructors :: proc() {")
    g.indent += 1

    for &cls in api.builtin_classes {
        if !has_lifecycle(&cls) do continue
        odin_cls := builtin_odin_type_name(cls.name)
        variant_type := builtin_name_to_variant_type(cls.name)
        if len(variant_type) == 0 do continue

        for &ctor in cls.constructors {
            if len(ctor.arguments) == 0 do continue
            if len(ctor.arguments) == 1 && ctor.arguments[0].type == cls.name do continue
            writef(g, "builtin_constructor_binds.%s_constructor_%d = gde_interface.variant_get_ptr_constructor(.%s, %d)\n",
                   odin_cls, ctor.index, variant_type, ctor.index)
        }
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
}

generate_builtin_constructor_wrappers :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "BUILTIN CONSTRUCTOR WRAPPERS")

    for &cls in api.builtin_classes {
        if !has_lifecycle(&cls) do continue
        odin_cls := builtin_odin_type_name(cls.name)

        for &ctor in cls.constructors {
            if len(ctor.arguments) == 0 do continue
            if len(ctor.arguments) == 1 && ctor.arguments[0].type == cls.name do continue

            // Build the "from" name: String_from_StringName, Array_from_PackedByteArray
            // For multi-arg constructors: just use the index
            wrapper_name: string
            if len(ctor.arguments) == 1 {
                from_type := builtin_odin_type_name(ctor.arguments[0].type)
                wrapper_name = fmt.tprintf("%s_from_%s", odin_cls, from_type)
            } else {
                wrapper_name = fmt.tprintf("%s_construct_%d", odin_cls, ctor.index)
            }

            // Build arg list
            args := strings.builder_make()
            for arg, i in ctor.arguments {
                if i > 0 do strings.write_string(&args, ", ")
                arg_type := convert_builtin_type(g, arg.type)
                safe_name := sanitize_identifier(arg.name)
                strings.write_string(&args, fmt.tprintf("%s: %s", safe_name, arg_type))
            }

            writef(g, "%s :: proc(%s) -> %s {{\n", wrapper_name, strings.to_string(args), odin_cls)
            g.indent += 1
            writef(g, "val: %s\n", odin_cls)

            num_args := len(ctor.arguments)
            // Copy args to locals for address-taking
            for arg, i in ctor.arguments {
                safe_name := sanitize_identifier(arg.name)
                writef(g, "arg%d := %s\n", i, safe_name)
            }
            writef(g, "call_args: [%d]GDExtensionConstTypePtr\n", num_args)
            for _, i in ctor.arguments {
                writef(g, "call_args[%d] = cast(GDExtensionConstTypePtr)&arg%d\n", i, i)
            }
            writef(g, "builtin_constructor_binds.%s_constructor_%d(cast(GDExtensionUninitializedTypePtr)&val, &call_args[0])\n",
                   odin_cls, ctor.index)
            writeln(g, "return val")
            g.indent -= 1
            writeln(g, "}")
            writeln(g)
        }
    }
}

// Utility Function Binds & Wrappers

is_bindable_utility :: proc(f: ^API_UtilityFunction) -> bool {
    return !f.is_vararg
}

generate_utility_binds_struct :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "UTILITY FUNCTION BINDS (cached at init_utility_functions)")
    writeln(g, "@(private)")
    writeln(g, "UtilityBindPtr :: #type proc \"c\" (ret: GDExtensionTypePtr, args: [^]GDExtensionConstTypePtr, arg_count: i32)")
    writeln(g)
    writeln(g, "@(private)")
    writeln(g, "UtilityBinds :: struct {")
    g.indent += 1

    for &f in api.utility_functions {
        if !is_bindable_utility(&f) do continue
        writef(g, "%s: UtilityBindPtr,\n", f.name)
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
    writeln(g, "@(private)")
    writeln(g, "utility_binds: UtilityBinds")
    writeln(g)
}

generate_init_utility_functions :: proc(g: ^Generator, api: ^Extension_API) {
    writeln(g, "init_utility_functions :: proc() {")
    g.indent += 1

    for &f in api.utility_functions {
        if !is_bindable_utility(&f) do continue
        writeln(g, "{")
        g.indent += 1
        writef(g, "sn := string_name_from_cstring(\"%s\")\n", f.name)
        writef(g, "utility_binds.%s = cast(UtilityBindPtr)gde_interface.variant_get_ptr_utility_function(cast(GDExtensionConstStringNamePtr)&sn, %d)\n",
               f.name, f.hash)
        writeln(g, "destroy_string_name(&sn)")
        g.indent -= 1
        writeln(g, "}")
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
}

generate_utility_wrappers :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "UTILITY FUNCTION WRAPPERS")

    for &f in api.utility_functions {
        if !is_bindable_utility(&f) do continue
        generate_utility_wrapper(g, &f)
    }
}

generate_utility_wrapper :: proc(g: ^Generator, f: ^API_UtilityFunction) {
    // Build args
    args := strings.builder_make()
    for arg in f.arguments {
        if strings.builder_len(args) > 0 do strings.write_string(&args, ", ")
        arg_type := convert_builtin_type(g, arg.type)
        safe_name := sanitize_identifier(arg.name)
        strings.write_string(&args, fmt.tprintf("%s: %s", safe_name, arg_type))
    }

    ret_type := ""
    if rt, ok := f.return_type.?; ok {
        ret_type = convert_builtin_type(g, rt)
    }

    // Signature
    if len(ret_type) > 0 {
        writef(g, "%s :: proc(%s) -> %s {{\n", f.name, strings.to_string(args), ret_type)
    } else {
        writef(g, "%s :: proc(%s) {{\n", f.name, strings.to_string(args))
    }
    g.indent += 1

    num_args := len(f.arguments)

    if num_args > 0 {
        for arg, i in f.arguments {
            arg_type := convert_builtin_type(g, arg.type)
            safe_name := sanitize_identifier(arg.name)
            if is_pass_by_value_type(arg_type) {
                writef(g, "arg%d := %s\n", i, safe_name)
            }
        }

        writef(g, "call_args: [%d]GDExtensionConstTypePtr\n", num_args)
        for arg, i in f.arguments {
            arg_type := convert_builtin_type(g, arg.type)
            safe_name := sanitize_identifier(arg.name)
            if is_pass_by_value_type(arg_type) {
                writef(g, "call_args[%d] = cast(GDExtensionConstTypePtr)&arg%d\n", i, i)
            } else {
                writef(g, "call_args[%d] = cast(GDExtensionConstTypePtr)&%s\n", i, safe_name)
            }
        }
    }

    args_ref := "&call_args[0]" if num_args > 0 else "nil"

    if len(ret_type) > 0 {
        writef(g, "ret: %s\n", ret_type)
        writef(g, "utility_binds.%s(cast(GDExtensionTypePtr)&ret, %s, %d)\n", f.name, args_ref, num_args)
        writeln(g, "return ret")
    } else {
        writef(g, "utility_binds.%s(nil, %s, %d)\n", f.name, args_ref, num_args)
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
}

// Vararg Utility Functions

generate_vararg_utility_binds :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "VARARG UTILITY FUNCTION BINDS (cached at init_vararg_utility_functions)")
    writeln(g, "@(private)")
    writeln(g, "VarargUtilityBinds :: struct {")
    g.indent += 1

    for &f in api.utility_functions {
        if !f.is_vararg do continue
        writef(g, "%s: UtilityBindPtr,\n", f.name)
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
    writeln(g, "@(private)")
    writeln(g, "vararg_utility_binds: VarargUtilityBinds")
    writeln(g)
}

generate_init_vararg_utility_functions :: proc(g: ^Generator, api: ^Extension_API) {
    writeln(g, "init_vararg_utility_functions :: proc() {")
    g.indent += 1

    for &f in api.utility_functions {
        if !f.is_vararg do continue
        writeln(g, "{")
        g.indent += 1
        writef(g, "sn := string_name_from_cstring(\"%s\")\n", f.name)
        writef(g, "vararg_utility_binds.%s = cast(UtilityBindPtr)gde_interface.variant_get_ptr_utility_function(cast(GDExtensionConstStringNamePtr)&sn, %d)\n",
               f.name, f.hash)
        writeln(g, "destroy_string_name(&sn)")
        g.indent -= 1
        writeln(g, "}")
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
}

generate_vararg_utility_wrappers :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "VARARG UTILITY FUNCTION WRAPPERS")

    for &f in api.utility_functions {
        if !f.is_vararg do continue

        // All vararg utility functions take Variant args
        // Generate: func_name :: proc(args: ..^Variant) -> RetType
        ret_type := ""
        if rt, ok := f.return_type.?; ok {
            ret_type = convert_builtin_type(g, rt)
        }

        // Postfix underscore to avoid conflicts with Odin builtins
        odin_conflicts := [?]string{"print", "max", "min", "str"}
        needs_suffix := false
        for c in odin_conflicts {
            if f.name == c { needs_suffix = true; break }
        }
        wrapper_name := fmt.tprintf("%s%s", f.name, "_" if needs_suffix else "")

        if len(ret_type) > 0 {
            writef(g, "%s :: proc(args: ..^Variant) -> %s {{\n", wrapper_name, ret_type)
        } else {
            writef(g, "%s :: proc(args: ..^Variant) {{\n", wrapper_name)
        }
        g.indent += 1

        writeln(g, "call_args := cast([^]GDExtensionConstTypePtr)raw_data(args)")
        args_ref := "call_args if len(args) > 0 else nil"

        if len(ret_type) > 0 {
            writef(g, "ret: %s\n", ret_type)
            writef(g, "vararg_utility_binds.%s(cast(GDExtensionTypePtr)&ret, %s, cast(i32)len(args))\n", f.name, args_ref)
            writeln(g, "return ret")
        } else {
            writef(g, "vararg_utility_binds.%s(nil, %s, cast(i32)len(args))\n", f.name, args_ref)
        }

        g.indent -= 1
        writeln(g, "}")
        writeln(g)
    }
}

// Vararg Helpers

// Emit code to convert a fixed arg to a Variant based on its Godot type name.
emit_variant_conversion :: proc(g: ^Generator, index: int, arg_type: string, safe_name: string) {
    switch arg_type {
    case "int":
        writef(g, "fixed_%d := Variant_from(cast(i64)%s)\n", index, safe_name)
    case "float":
        writef(g, "fixed_%d := Variant_from(cast(f64)%s)\n", index, safe_name)
    case:
        // StringName, String, bool, Object, enums — all dispatch through Variant_from's when chain
        if strings.has_prefix(arg_type, "enum::") || strings.has_prefix(arg_type, "bitfield::") {
            writef(g, "fixed_%d := Variant_from(cast(i64)%s)\n", index, safe_name)
        } else {
            writef(g, "fixed_%d := Variant_from(%s)\n", index, safe_name)
        }
    }
}

// Emit the stack-allocated call_args buffer, filling fixed args and copying varargs.
// MAX_VARARG_CALL_ARGS is defined as a constant in the generated output.
emit_vararg_call_args :: proc(g: ^Generator, num_fixed: int) {
    writef(g, "total_args := %d + len(varargs)\n", num_fixed)
    writeln(g, "assert(total_args <= MAX_VARARG_CALL_ARGS)")
    writeln(g, "call_args: [MAX_VARARG_CALL_ARGS]GDExtensionConstVariantPtr")
    for i in 0..<num_fixed {
        writef(g, "call_args[%d] = cast(GDExtensionConstVariantPtr)&fixed_%d\n", i, i)
    }
    writef(g, "for v, i in varargs {{\n")
    g.indent += 1
    writef(g, "call_args[%d + i] = cast(GDExtensionConstVariantPtr)v\n", num_fixed)
    g.indent -= 1
    writeln(g, "}")
}

// Vararg Class Methods (emit_signal, call, call_deferred, etc.)

generate_vararg_class_method_wrappers :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "VARARG CLASS METHOD WRAPPERS")

    for &cls in api.classes {
        for &m in cls.methods {
            if !is_vararg_class_method(&m) do continue

            is_singleton := g.singleton_set[cls.name]

            // Build fixed args
            fixed_args := strings.builder_make()
            if !m.is_static && !is_singleton {
                strings.write_string(&fixed_args, "obj: ObjectPtr")
            }
            for arg in m.arguments {
                if strings.builder_len(fixed_args) > 0 do strings.write_string(&fixed_args, ", ")
                arg_type := convert_builtin_type(g, arg.type)
                safe_name := sanitize_identifier(arg.name)
                strings.write_string(&fixed_args, fmt.tprintf("%s: %s", safe_name, arg_type))
            }
            if strings.builder_len(fixed_args) > 0 do strings.write_string(&fixed_args, ", ")
            strings.write_string(&fixed_args, "varargs: ..^Variant")

            // Determine return type: vararg calls return Variant,
            // except enum types (return i64) and void.
            ret_type := ""
            is_enum_return := false
            if rv, ok := m.return_value.?; ok {
                if strings.has_prefix(rv.type, "enum::") || strings.has_prefix(rv.type, "bitfield::") {
                    ret_type = "i64"
                    is_enum_return = true
                } else {
                    ret_type = "Variant"
                }
            }

            method_name := fmt.tprintf("%s_%s", cls.name, m.name)

            if len(ret_type) > 0 {
                writef(g, "%s :: proc(%s) -> %s {{\n", method_name, strings.to_string(fixed_args), ret_type)
            } else {
                writef(g, "%s :: proc(%s) {{\n", method_name, strings.to_string(fixed_args))
            }
            g.indent += 1

            // Convert fixed args to Variants
            num_fixed := len(m.arguments)
            for arg, i in m.arguments {
                emit_variant_conversion(g, i, arg.type, sanitize_identifier(arg.name))
            }
            for i in 0..<num_fixed {
                writef(g, "defer Variant_destroy(&fixed_%d)\n", i)
            }

            // Build combined arg array on the stack
            emit_vararg_call_args(g, num_fixed)

            obj_ref: string
            if m.is_static {
                obj_ref = "nil"
            } else if is_singleton {
                obj_ref = fmt.tprintf("get_singleton(\"%s\")", cls.name)
            } else {
                obj_ref = "obj"
            }

            writeln(g, "err: GDExtensionCallError")

            if len(ret_type) > 0 {
                writeln(g, "ret_var: Variant")
                writef(g, "gde_interface.object_method_bind_call(cast(GDExtensionMethodBindPtr)method_binds.%s_%s, cast(GDExtensionObjectPtr)%s, cast(^GDExtensionConstVariantPtr)&call_args[0], cast(i64)total_args, cast(GDExtensionUninitializedVariantPtr)&ret_var, &err)\n",
                       cls.name, m.name, obj_ref)
                if is_enum_return {
                    writeln(g, "defer Variant_destroy(&ret_var)")
                    writeln(g, "return Variant_to(i64, &ret_var)")
                } else {
                    writeln(g, "return ret_var")
                }
            } else {
                writef(g, "gde_interface.object_method_bind_call(cast(GDExtensionMethodBindPtr)method_binds.%s_%s, cast(GDExtensionObjectPtr)%s, cast(^GDExtensionConstVariantPtr)&call_args[0], cast(i64)total_args, nil, &err)\n",
                       cls.name, m.name, obj_ref)
            }

            g.indent -= 1
            writeln(g, "}")
            writeln(g)
        }
    }
}

// Vararg Builtin Methods (Callable.call, Signal.emit, etc.)

generate_vararg_builtin_method_wrappers :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "VARARG BUILTIN METHOD WRAPPERS")

    for &cls in api.builtin_classes {
        odin_cls := builtin_odin_type_name(cls.name)

        for &m in cls.methods {
            if !m.is_vararg do continue

            // Build args: self pointer + any fixed args + varargs
            args := strings.builder_make()
            if !m.is_static {
                strings.write_string(&args, fmt.tprintf("self: ^%s", odin_cls))
            }
            for arg in m.arguments {
                if strings.builder_len(args) > 0 do strings.write_string(&args, ", ")
                arg_type := convert_builtin_type(g, arg.type)
                safe_name := sanitize_identifier(arg.name)
                strings.write_string(&args, fmt.tprintf("%s: %s", safe_name, arg_type))
            }
            if strings.builder_len(args) > 0 do strings.write_string(&args, ", ")
            strings.write_string(&args, "varargs: ..^Variant")

            has_return := m.return_type != nil
            method_name := fmt.tprintf("%s_%s", odin_cls, m.name)

            if has_return {
                writef(g, "%s :: proc(%s) -> Variant {{\n", method_name, strings.to_string(args))
            } else {
                writef(g, "%s :: proc(%s) {{\n", method_name, strings.to_string(args))
            }
            g.indent += 1

            // variant_call requires a Variant self, so convert from the builtin type
            variant_type := builtin_name_to_variant_type(cls.name)
            writef(g, "self_var := Variant_from_type_ptr(.%s, self)\n", variant_type)
            writeln(g, "defer Variant_destroy(&self_var)")

            // Convert fixed args to Variants
            num_fixed := len(m.arguments)
            for arg, i in m.arguments {
                emit_variant_conversion(g, i, arg.type, sanitize_identifier(arg.name))
            }
            for i in 0..<num_fixed {
                writef(g, "defer Variant_destroy(&fixed_%d)\n", i)
            }

            emit_vararg_call_args(g, num_fixed)

            writef(g, "mn := string_name_from_cstring(\"%s\")\n", m.name)
            writeln(g, "defer destroy_string_name(&mn)")
            writeln(g, "err: GDExtensionCallError")

            if has_return {
                writeln(g, "ret_var: Variant")
                writef(g, "gde_interface.variant_call(cast(GDExtensionVariantPtr)&self_var, cast(GDExtensionConstStringNamePtr)&mn, cast(^GDExtensionConstVariantPtr)&call_args[0], cast(i64)total_args, cast(GDExtensionUninitializedVariantPtr)&ret_var, &err)\n")
                writeln(g, "return ret_var")
            } else {
                writef(g, "gde_interface.variant_call(cast(GDExtensionVariantPtr)&self_var, cast(GDExtensionConstStringNamePtr)&mn, cast(^GDExtensionConstVariantPtr)&call_args[0], cast(i64)total_args, nil, &err)\n")
            }

            g.indent -= 1
            writeln(g, "}")
            writeln(g)
        }
    }
}

// Virtual Method Arg Unpackers/Packers

// Check if a virtual method's arg/return types are all ones we can handle
is_bindable_virtual :: proc(m: ^API_Method) -> bool {
    if !m.is_virtual do return false
    if m.is_vararg do return false

    for arg in m.arguments {
        if !is_supported_virtual_type(arg.type) do return false
    }
    if rv, ok := m.return_value.?; ok {
        if !is_supported_virtual_type(rv.type) do return false
    }
    return true
}

is_supported_virtual_type :: proc(type_name: string) -> bool {
    // Skip raw pointer types we can't represent safely
    if strings.has_suffix(type_name, "*") do return false
    // Skip const pointer returns like "const Glyph*"
    if strings.has_prefix(type_name, "const ") && strings.has_suffix(type_name, "*") do return false
    return true
}

has_bindable_virtuals :: proc(cls: ^API_Class) -> bool {
    for &m in cls.methods {
        if is_bindable_virtual(&m) do return true
    }
    return false
}

// Strip leading underscore from Godot virtual name: "_gui_input" -> "gui_input"
virtual_method_name :: proc(name: string) -> string {
    if strings.has_prefix(name, "_") {
        return name[1:]
    }
    return name
}

// Convert a virtual method arg type to the Odin wire type.
// Virtual methods use the same ptrcall widening: float->f64, int->i64, bool->u8.
convert_virtual_type :: proc(g: ^Generator, type_name: string) -> string {
    switch type_name {
    case "float":  return "f64"
    case "int":    return "i64"
    case "bool":   return "u8"
    case "String": return "GodotString"
    }
    if strings.has_prefix(type_name, "enum::") || strings.has_prefix(type_name, "bitfield::") {
        return "i64"
    }
    if strings.has_prefix(type_name, "typedarray::") {
        return "Array"
    }
    if mapped, ok := g.type_map[type_name]; ok {
        return mapped
    }
    // Object-derived types are passed as ObjectPtr in ptrcall
    return "ObjectPtr"
}

generate_virtual_unpackers :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "VIRTUAL METHOD ARG UNPACKERS")

    for &cls in api.classes {
        if !has_bindable_virtuals(&cls) do continue

        writef(g, "// %s\n", cls.name)

        for &m in cls.methods {
            if !is_bindable_virtual(&m) do continue
            generate_virtual_unpacker(g, &cls, &m)
        }
        writeln(g)
    }
}

// User-facing type for virtual args/returns: bool instead of u8
convert_virtual_user_type :: proc(g: ^Generator, type_name: string) -> string {
    if type_name == "bool" do return "bool"
    return convert_virtual_type(g, type_name)
}

generate_virtual_unpacker :: proc(g: ^Generator, cls: ^API_Class, m: ^API_Method) {
    vname := virtual_method_name(m.name)
    num_args := len(m.arguments)

    // Only generate unpacker if there are args to unpack
    if num_args > 0 {
        // Build return list with user-facing types
        ret_parts := strings.builder_make()
        for arg, i in m.arguments {
            if i > 0 do strings.write_string(&ret_parts, ", ")
            safe_name := sanitize_identifier(arg.name)
            user_type := convert_virtual_user_type(g, arg.type)
            strings.write_string(&ret_parts, fmt.tprintf("%s: %s", safe_name, user_type))
        }
        ret_str := strings.to_string(ret_parts)

        writef(g, "%s_vargs_%s :: proc(args: ^GDExtensionConstTypePtr) -> (%s) {{\n", cls.name, vname, ret_str)
        g.indent += 1

        writeln(g, "a := cast([^]GDExtensionConstTypePtr)args")
        for arg, i in m.arguments {
            safe_name := sanitize_identifier(arg.name)
            if arg.type == "bool" {
                writef(g, "%s = (cast(^u8)a[%d])^ != 0\n", safe_name, i)
            } else {
                wire_type := convert_virtual_type(g, arg.type)
                writef(g, "%s = (cast(^%s)a[%d])^\n", safe_name, wire_type, i)
            }
        }
        writeln(g, "return")

        g.indent -= 1
        writeln(g, "}")
        writeln(g)
    }

    // Generate packer if there's a return value
    if rv, ok := m.return_value.?; ok {
        user_type := convert_virtual_user_type(g, rv.type)

        writef(g, "%s_vargs_%s_pack :: proc(ret: GDExtensionTypePtr, value: %s) {{\n", cls.name, vname, user_type)
        g.indent += 1
        if rv.type == "bool" {
            writeln(g, "(cast(^u8)ret)^ = 1 if value else 0")
        } else {
            wire_type := convert_virtual_type(g, rv.type)
            writef(g, "(cast(^%s)ret)^ = value\n", wire_type)
        }
        g.indent -= 1
        writeln(g, "}")
        writeln(g)
    }
}

// Main Generation

write_section_header :: proc(g: ^Generator, title: string) {
    writeln(g, "// =============================================================================")
    writef(g, "// %s\n", title)
    writeln(g, "// =============================================================================")
    writeln(g)
}

generate_types_by_kind :: proc(g: ^Generator, iface: ^GDExtension_Interface, kind: string) {
    for &t in iface.types {
        if t.kind != kind do continue
        switch kind {
        case "enum":     generate_enum(g, &t)
        case "handle":   generate_handle(g, &t)
        case "alias":    generate_alias(g, &t)
        case "function": generate_function_type(g, &t)
        case "struct":   generate_struct(g, &t)
        }
    }
}

generate_bindings :: proc(iface: ^GDExtension_Interface, api: ^Extension_API) -> string {
    g: Generator
    g.output = strings.builder_make()
    g.type_map = make(map[string]string)
    g.handle_types = make(map[string]bool)
    g.enum_types = make(map[string]bool)
    g.struct_types = make(map[string]bool)
    g.func_types = make(map[string]Type_Def)
    g.singleton_set = make(map[string]bool)

    init_type_map(&g)

    for &s in api.singletons {
        g.singleton_set[s.type] = true
    }

    for &t in iface.types {
        switch t.kind {
        case "handle":   g.handle_types[t.name] = true
        case "enum":     g.enum_types[t.name] = true
        case "struct":   g.struct_types[t.name] = true
        case "function": g.func_types[t.name] = t
        case "alias":
            if aliased, ok := t.type.?; ok {
                g.type_map[t.name] = convert_type(&g, aliased)
            }
        }
    }

    writeln(&g, "package godot")
    writeln(&g)
    writeln(&g, "// AUTO-GENERATED FILE - DO NOT EDIT")
    writeln(&g)
    writeln(&g, "import \"core:c\"")
    writeln(&g)

    write_section_header(&g, "BUILTIN TYPES")
    generate_builtin_types(&g, api)
    writeln(&g)

    write_section_header(&g, "GDEXTENSION ENUMS")
    generate_types_by_kind(&g, iface, "enum")

    write_section_header(&g, "GDEXTENSION HANDLE TYPES")
    generate_types_by_kind(&g, iface, "handle")

    write_section_header(&g, "GDEXTENSION TYPE ALIASES")
    generate_types_by_kind(&g, iface, "alias")

    write_section_header(&g, "GDEXTENSION FUNCTION TYPES")
    generate_types_by_kind(&g, iface, "function")

    write_section_header(&g, "GDEXTENSION STRUCTS")
    generate_types_by_kind(&g, iface, "struct")

    write_section_header(&g, "ADDITIONAL TYPES")
    writeln(&g, "ObjectPtr :: rawptr")
    writeln(&g, "ClassLibraryPtr :: rawptr")
    writeln(&g, "MethodBindPtr :: rawptr")
    writeln(&g, "ConstTypePtr :: rawptr")
    writeln(&g, "TypePtr :: rawptr")
    writeln(&g, "ConstStringNamePtr :: ^StringName")
    writeln(&g, "ConstStringPtr :: ^GodotString")
    writeln(&g, "BuiltinMethodBindPtr :: #type proc \"c\" (base: GDExtensionTypePtr, args: [^]GDExtensionConstTypePtr, ret: GDExtensionTypePtr, arg_count: i32)")
    writeln(&g)
    writeln(&g, "// Maximum number of arguments (fixed + varargs) for vararg method calls.")
    writeln(&g, "// Uses a stack-allocated buffer to avoid heap allocation per call.")
    writeln(&g, "MAX_VARARG_CALL_ARGS :: 32")
    writeln(&g)
    writeln(&g, "InitializationLevel :: enum c.int {")
    writeln(&g, "    CORE = 0,")
    writeln(&g, "    SERVERS = 1,")
    writeln(&g, "    SCENE = 2,")
    writeln(&g, "    EDITOR = 3,")
    writeln(&g, "}")
    writeln(&g)
    writeln(&g, "Initialization :: struct {")
    writeln(&g, "    minimum_initialization_level: InitializationLevel,")
    writeln(&g, "    userdata: rawptr,")
    writeln(&g, "    initialize: proc \"c\" (userdata: rawptr, level: InitializationLevel),")
    writeln(&g, "    deinitialize: proc \"c\" (userdata: rawptr, level: InitializationLevel),")
    writeln(&g, "}")
    writeln(&g)
    writeln(&g, "GetProcAddress :: #type proc \"c\" (name: cstring) -> rawptr")
    writeln(&g)
    writeln(&g, "InitializationFunction :: #type proc \"c\" (")
    writeln(&g, "    get_proc_address: GetProcAddress,")
    writeln(&g, "    library: ClassLibraryPtr,")
    writeln(&g, "    initialization: ^Initialization,")
    writeln(&g, ") -> u8")
    writeln(&g)

    write_section_header(&g, "LIBGODOT FOREIGN FUNCTIONS")
    writeln(&g, "when ODIN_OS == .Windows {")
    writeln(&g, "    when ODIN_ARCH == .amd64 { foreign import libgodot \"system:godot.windows.editor.dev.x86_64\" }")
    writeln(&g, "    else { foreign import libgodot \"system:godot.windows.editor.dev.arm64\" }")
    writeln(&g, "} else when ODIN_OS == .Darwin {")
    writeln(&g, "    when ODIN_ARCH == .amd64 { foreign import libgodot \"system:godot.macos.editor.dev.x86_64\" }")
    writeln(&g, "    else { foreign import libgodot \"system:godot.macos.editor.dev.arm64\" }")
    writeln(&g, "} else {")
    writeln(&g, "    when ODIN_ARCH == .amd64 { foreign import libgodot \"system:godot.linuxbsd.editor.dev.x86_64\" }")
    writeln(&g, "    else { foreign import libgodot \"system:godot.linuxbsd.editor.dev.arm64\" }")
    writeln(&g, "}")
    writeln(&g)
    writeln(&g, "@(default_calling_convention = \"c\")")
    writeln(&g, "foreign libgodot {")
    writeln(&g, "    libgodot_create_godot_instance :: proc(argc: c.int, argv: [^][^]u8, init_func: InitializationFunction) -> ObjectPtr ---")
    writeln(&g, "    libgodot_destroy_godot_instance :: proc(godot_instance: ObjectPtr) ---")
    writeln(&g, "}")
    writeln(&g)

    write_section_header(&g, "GDEXTENSION INTERFACE")
    writeln(&g, "GDExtensionInterface :: struct {")
    g.indent += 1
    for &f in iface.interface {
        generate_interface_function(&g, &f)
    }
    g.indent -= 1
    writeln(&g, "}")
    writeln(&g)

    write_section_header(&g, "GLOBAL STATE")
    writeln(&g, "@(private)")
    writeln(&g, "gde_interface: GDExtensionInterface")
    writeln(&g)
    writeln(&g, "@(private)")
    writeln(&g, "gpa: GetProcAddress = nil")
    writeln(&g)

    write_section_header(&g, "INITIALIZATION")
    writeln(&g, "init :: proc(get_proc_address: GetProcAddress) {")
    writeln(&g, "    gpa = get_proc_address")
    writeln(&g)
    for &f in iface.interface {
        if _, ok := f.deprecated.?; ok do continue
        writef(&g, "    gde_interface.%s = auto_cast gpa(\"%s\")\n", f.name, f.name)
    }
    writeln(&g, "}")
    writeln(&g)

    generate_global_enums(&g, api)
    generate_class_constants(&g, api)
    generate_signal_constants(&g, api)
    generate_builtin_constants(&g, api)
    generate_class_name_strings(&g, api)
    generate_method_binds_struct(&g, api)
    generate_init_scene(&g, api)
    generate_builtin_method_binds_struct(&g, api)
    generate_init_builtin_methods(&g, api)
    generate_builtin_lifecycle_struct(&g, api)
    generate_init_builtin_lifecycle(&g, api)
    generate_builtin_constructor_binds(&g, api)
    generate_init_builtin_constructors(&g, api)
    generate_utility_binds_struct(&g, api)
    generate_init_utility_functions(&g, api)
    generate_vararg_utility_binds(&g, api)
    generate_init_vararg_utility_functions(&g, api)
    generate_init_bindings(&g)
    generate_method_wrappers(&g, api)
    generate_builtin_method_wrappers(&g, api)
    generate_builtin_lifecycle_wrappers(&g, api)
    generate_builtin_constructor_wrappers(&g, api)
    generate_utility_wrappers(&g, api)
    generate_vararg_utility_wrappers(&g, api)
    generate_vararg_class_method_wrappers(&g, api)
    generate_vararg_builtin_method_wrappers(&g, api)
    generate_virtual_unpackers(&g, api)

    return strings.to_string(g.output)
}

// Main

read_and_parse_json :: proc($T: typeid, path: string) -> (result: T, ok: bool) {
    fmt.printfln("Reading %s...", path)
    data, read_ok := os.read_entire_file(path)
    if !read_ok {
        fmt.eprintfln("Failed to read %s", path)
        return {}, false
    }

    fmt.printfln("Parsing %s...", path)
    if err := json.unmarshal(data, &result); err != nil {
        fmt.eprintfln("Failed to parse %s: %v", path, err)
        return {}, false
    }
    return result, true
}

main :: proc() {
    base_path := "json/" if !os.exists("gdextension_interface.json") else ""

    iface, iface_ok := read_and_parse_json(GDExtension_Interface, fmt.tprintf("%sgdextension_interface.json", base_path))
    if !iface_ok do os.exit(1)
    fmt.printfln("Found %d types and %d interface functions", len(iface.types), len(iface.interface))

    api, api_ok := read_and_parse_json(Extension_API, fmt.tprintf("%sextension_api.json", base_path))
    if !api_ok do os.exit(1)
    fmt.printfln("Found %d classes, %d builtin classes, and %d singletons", len(api.classes), len(api.builtin_classes), len(api.singletons))

    fmt.println("Generating bindings...")
    output := generate_bindings(&iface, &api)

    output_path := "bindings/godot.odin"
    fmt.printfln("Writing %s...", output_path)
    if !os.write_entire_file(output_path, transmute([]u8)output) {
        fmt.eprintfln("Failed to write %s", output_path)
        os.exit(1)
    }

}


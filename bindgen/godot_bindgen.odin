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

API_ClassConstant :: struct {
    name:  string,
    value: i64,
}

API_Class :: struct {
    name:           string,
    is_refcounted:  bool,
    is_instantiable: bool,
    inherits:       Maybe(string),
    api_type:       string,
    constants:      []API_ClassConstant,
    methods:        []API_Method,
}

API_Singleton :: struct {
    name: string,
    type: string,
}

Extension_API :: struct {
    header:                        API_Header,
    builtin_class_sizes:           []API_BuildConfig,
    builtin_class_member_offsets:  []API_BuildConfigOffsets,
    classes:                       []API_Class,
    singletons:                    []API_Singleton,
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

    if g.handle_types[type_str] || g.enum_types[type_str] {
        return type_str
    }
    if type_str in g.func_types {
        return type_str
    }
    if g.struct_types[type_str] {
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

camel_to_snake :: proc(name: string) -> string {
    result := strings.builder_make()
    for r, i in name {
        if unicode.is_upper(r) {
            if i > 0 {
                strings.write_byte(&result, '_')
            }
            strings.write_rune(&result, unicode.to_lower(r))
        } else {
            strings.write_rune(&result, r)
        }
    }
    return strings.to_string(result)
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
}

is_pass_by_value_type :: proc(type_name: string) -> bool {
    for t in PASS_BY_VALUE_TYPES {
        if type_name == t {
            return true
        }
    }
    return strings.has_prefix(type_name, "^")
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

has_bindable_methods :: proc(cls: ^API_Class) -> bool {
    for &m in cls.methods {
        if is_bindable_method(&m) {
            return true
        }
    }
    return false
}

generate_class_constants :: proc(g: ^Generator, api: ^Extension_API) {
    write_section_header(g, "ENGINE CLASS CONSTANTS")

    for &cls in api.classes {
        if len(cls.constants) == 0 do continue

        class_snake := strings.to_upper(camel_to_snake(cls.name))
        writef(g, "// %s\n", cls.name)
        for &c in cls.constants {
            writef(g, "%s_%s :: %d\n", class_snake, c.name, c.value)
        }
        writeln(g)
    }
}

generate_method_binds_struct :: proc(g: ^Generator, api: ^Extension_API) {
    writeln(g, "// =============================================================================")
    writeln(g, "// METHOD BINDS (cached at init_scene)")
    writeln(g, "// =============================================================================")
    writeln(g)
    writeln(g, "@(private)")
    writeln(g, "MethodBinds :: struct {")
    g.indent += 1

    for &cls in api.classes {
        if !has_bindable_methods(&cls) do continue

        class_snake := camel_to_snake(cls.name)
        writef(g, "// %s\n", cls.name)

        for &m in cls.methods {
            if !is_bindable_method(&m) do continue
            writef(g, "%s_%s: MethodBindPtr,\n", class_snake, m.name)
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
        if !has_bindable_methods(&cls) do continue

        class_snake := camel_to_snake(cls.name)
        for &m in cls.methods {
            if !is_bindable_method(&m) do continue
            writef(g, "method_binds.%s_%s = get_method_bind(\"%s\", \"%s\", %d)\n",
                   class_snake, m.name, cls.name, m.name, m.hash)
        }
    }

    g.indent -= 1
    writeln(g, "}")
    writeln(g)
}

generate_method_wrappers :: proc(g: ^Generator, api: ^Extension_API) {
    writeln(g, "// =============================================================================")
    writeln(g, "// ENGINE CLASS METHOD WRAPPERS")
    writeln(g, "// =============================================================================")
    writeln(g)

    for &cls in api.classes {
        if !has_bindable_methods(&cls) do continue

        class_snake := camel_to_snake(cls.name)
        is_singleton := g.singleton_set[cls.name]
        writef(g, "// %s\n", cls.name)

        for &m in cls.methods {
            if !is_bindable_method(&m) do continue
            generate_method_wrapper(g, &cls, &m, class_snake, is_singleton)
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

generate_method_wrapper :: proc(g: ^Generator, cls: ^API_Class, m: ^API_Method, class_snake: string, is_singleton: bool) {
    method_name := fmt.tprintf("%s_%s", class_snake, m.name)

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

    if sizes == nil do return

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

    generate_class_constants(&g, api)
    generate_method_binds_struct(&g, api)
    generate_init_scene(&g, api)
    generate_method_wrappers(&g, api)

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
    fmt.printfln("Found %d classes and %d singletons", len(api.classes), len(api.singletons))

    fmt.println("Generating bindings...")
    output := generate_bindings(&iface, &api)

    output_path := "bindings/godot.odin"
    fmt.printfln("Writing %s...", output_path)
    if !os.write_entire_file(output_path, transmute([]u8)output) {
        fmt.eprintfln("Failed to write %s", output_path)
        os.exit(1)
    }

    api_md := generate_api_markdown(&iface, &api)
    api_md_path := "godot-api.md"
    if !os.write_entire_file(api_md_path, transmute([]u8)api_md) {
        fmt.eprintfln("Failed to write %s", api_md_path)
    }
}

// Markdown API Reference Generation

generate_api_markdown :: proc(iface: ^GDExtension_Interface, api: ^Extension_API) -> string {
    b := strings.builder_make()

    singleton_set := make(map[string]bool)
    for &s in api.singletons {
        singleton_set[s.type] = true
    }

    strings.write_string(&b, "# Godot Odin API Reference\n\n")
    strings.write_string(&b, "Auto-generated from extension_api.json and gdextension_interface.json.\n\n")

    strings.write_string(&b, "## GDExtension Types\n\n")
    for &t in iface.types {
        switch t.kind {
        case "handle":
            fmt.sbprintf(&b, "- `%s` (handle, distinct rawptr)\n", t.name)
        case "enum":
            fmt.sbprintf(&b, "- `%s` (enum)\n", t.name)
        case "function":
            args := build_md_func_args(t.arguments)
            rv := t.return_value.? or_else Return_Value{}
            if len(rv.type) > 0 && rv.type != "void" {
                fmt.sbprintf(&b, "- `%s :: proc(%s) -> %s`\n", t.name, args, rv.type)
            } else {
                fmt.sbprintf(&b, "- `%s :: proc(%s)`\n", t.name, args)
            }
        case "struct":
            fmt.sbprintf(&b, "- `%s` (struct)\n", t.name)
        case "alias":
            aliased := t.type.? or_else "rawptr"
            fmt.sbprintf(&b, "- `%s` (alias for %s)\n", t.name, aliased)
        }
    }
    strings.write_string(&b, "\n")

    strings.write_string(&b, "## GDExtension Interface Functions\n\n")
    for &f in iface.interface {
        if _, ok := f.deprecated.?; ok do continue
        args := build_md_func_args(f.arguments)
        rv := f.return_value.? or_else Return_Value{}
        if len(rv.type) > 0 && rv.type != "void" {
            fmt.sbprintf(&b, "- `gde_interface.%s(%s) -> %s`\n", f.name, args, rv.type)
        } else {
            fmt.sbprintf(&b, "- `gde_interface.%s(%s)`\n", f.name, args)
        }
    }
    strings.write_string(&b, "\n")

    strings.write_string(&b, "## Engine Classes\n\n")
    for &cls in api.classes {
        if !has_bindable_methods(&cls) do continue
        class_snake := camel_to_snake(cls.name)

        fmt.sbprintf(&b, "### %s", cls.name)
        if parent, ok := cls.inherits.?; ok {
            fmt.sbprintf(&b, " (extends %s)", parent)
        }
        strings.write_string(&b, "\n\n")

        for &m in cls.methods {
            if !is_bindable_method(&m) do continue

            method_name := fmt.tprintf("%s_%s", class_snake, m.name)
            args := build_md_method_args(&m, cls.name in singleton_set)

            rv := ""
            if r, ok := m.return_value.?; ok {
                if meta, mok := r.meta.?; mok {
                    rv = meta
                } else {
                    rv = r.type
                }
            }

            if len(rv) > 0 {
                fmt.sbprintf(&b, "- `%s(%s) -> %s`\n", method_name, args, rv)
            } else {
                fmt.sbprintf(&b, "- `%s(%s)`\n", method_name, args)
            }
        }
        strings.write_string(&b, "\n")
    }

    strings.write_string(&b, "## Helper Functions (godot_helpers.odin)\n\n")
    strings.write_string(&b, "- `string_name_from_cstring(s: cstring) -> StringName`\n")
    strings.write_string(&b, "- `godot_string_from_cstring(s: cstring) -> GodotString`\n")
    strings.write_string(&b, "- `godot_string_to_odin(gs: ^GodotString, buf: []u8) -> string`\n")
    strings.write_string(&b, "- `get_singleton(name: cstring) -> ObjectPtr`\n")
    strings.write_string(&b, "- `get_method_bind(class_name, method_name: cstring, hash: i64) -> MethodBindPtr`\n")
    strings.write_string(&b, "- `ptrcall(method: MethodBindPtr, obj: ObjectPtr, args: [^]ConstTypePtr, ret: TypePtr)`\n")
    strings.write_string(&b, "- `construct_object(class_name: cstring) -> ObjectPtr`\n")
    strings.write_string(&b, "- `vec2(x, y: f32) -> Vector2`\n")
    strings.write_string(&b, "- `vec3(x, y, z: f32) -> Vector3`\n")
    strings.write_string(&b, "- `vec4(x, y, z, w: f32) -> Vector4`\n")
    strings.write_string(&b, "- `rect2(x, y, width, height: f32) -> Rect2`\n")
    strings.write_string(&b, "- `color(r, g, b: f32, a: f32 = 1.0) -> Color`\n")
    strings.write_string(&b, "- `color_rgb(r, g, b: u8, a: u8 = 255) -> Color`\n")
    strings.write_string(&b, "- `instance_create(argc: c.int, argv: [^][^]u8, init_func: InitializationFunction) -> (Instance, bool)`\n")
    strings.write_string(&b, "- `instance_destroy(instance: ^Instance)`\n")
    strings.write_string(&b, "- `instance_start(instance: ^Instance) -> bool`\n")
    strings.write_string(&b, "- `instance_iteration(instance: ^Instance) -> bool`\n")
    strings.write_string(&b, "- `register_class(library: ClassLibraryPtr, class_name, parent_name: cstring, info: ^GDExtensionClassCreationInfo4)`\n")

    return strings.to_string(b)
}

build_md_func_args :: proc(arguments: []Function_Argument) -> string {
    b := strings.builder_make()
    for arg, i in arguments {
        if i > 0 do strings.write_string(&b, ", ")
        name := arg.name if len(arg.name) > 0 else fmt.tprintf("arg%d", i)
        fmt.sbprintf(&b, "%s: %s", name, arg.type)
    }
    return strings.to_string(b)
}

build_md_method_args :: proc(m: ^API_Method, is_singleton: bool) -> string {
    b := strings.builder_make()
    if !m.is_static && !is_singleton {
        strings.write_string(&b, "obj: ObjectPtr")
    }
    for arg in m.arguments {
        if strings.builder_len(b) > 0 do strings.write_string(&b, ", ")
        atype := arg.type
        if meta, ok := arg.meta.?; ok {
            atype = meta
        }
        fmt.sbprintf(&b, "%s: %s", arg.name, atype)
    }
    return strings.to_string(b)
}

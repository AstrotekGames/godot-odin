package godot

import "core:c"
import "base:runtime"

// String lifecycle

@(private = "file")
cached_string_dtor: GDExtensionPtrDestructor = nil
@(private = "file")
cached_string_name_dtor: GDExtensionPtrDestructor = nil

string_name_from_cstring :: proc(s: cstring) -> StringName {
    sn: StringName
    assert(gde_interface.string_name_new_with_utf8_chars != nil, "[godot] string_name_new_with_utf8_chars not loaded")
    gde_interface.string_name_new_with_utf8_chars(cast(GDExtensionUninitializedStringNamePtr)&sn, s)
    return sn
}

godot_string_from_cstring :: proc(s: cstring) -> GodotString {
    gs: GodotString
    assert(gde_interface.string_new_with_utf8_chars != nil, "[godot] string_new_with_utf8_chars not loaded")
    gde_interface.string_new_with_utf8_chars(cast(GDExtensionUninitializedStringPtr)&gs, s)
    return gs
}

destroy_string :: proc(s: ^GodotString) {
    if cached_string_dtor == nil {
        cached_string_dtor = gde_interface.variant_get_ptr_destructor(.VARIANT_TYPE_STRING)
    }
    assert(cached_string_dtor != nil, "[godot] String destructor not available")
    cached_string_dtor(cast(GDExtensionTypePtr)s)
}

destroy_string_name :: proc(s: ^StringName) {
    if cached_string_name_dtor == nil {
        cached_string_name_dtor = gde_interface.variant_get_ptr_destructor(.VARIANT_TYPE_STRING_NAME)
    }
    assert(cached_string_name_dtor != nil, "[godot] StringName destructor not available")
    cached_string_name_dtor(cast(GDExtensionTypePtr)s)
}

godot_string_to_odin :: proc(gs: ^GodotString, buf: []u8) -> string {
    assert(gde_interface.string_to_utf8_chars != nil, "[godot] string_to_utf8_chars not loaded")
    n := gde_interface.string_to_utf8_chars(cast(GDExtensionConstStringPtr)gs, cast(cstring)raw_data(buf), i64(len(buf)))
    if n <= 0 {
        return ""
    }
    return string(buf[:n])
}

// Engine queries

get_singleton :: proc(name: cstring) -> ObjectPtr {
    sn := string_name_from_cstring(name)
    defer destroy_string_name(&sn)
    assert(gde_interface.global_get_singleton != nil, "[godot] global_get_singleton not loaded")
    return gde_interface.global_get_singleton(cast(GDExtensionConstStringNamePtr)&sn)
}

get_method_bind :: proc(class_name, method_name: cstring, hash: i64 = 0) -> MethodBindPtr {
    cn := string_name_from_cstring(class_name)
    defer destroy_string_name(&cn)
    mn := string_name_from_cstring(method_name)
    defer destroy_string_name(&mn)
    assert(gde_interface.classdb_get_method_bind != nil, "[godot] classdb_get_method_bind not loaded")
    return cast(MethodBindPtr)gde_interface.classdb_get_method_bind(
        cast(GDExtensionConstStringNamePtr)&cn,
        cast(GDExtensionConstStringNamePtr)&mn,
        hash,
    )
}

ptrcall :: proc(method: MethodBindPtr, obj: ObjectPtr, args: [^]ConstTypePtr, ret: TypePtr) {
    assert(gde_interface.object_method_bind_ptrcall != nil, "[godot] object_method_bind_ptrcall not loaded")
    gde_interface.object_method_bind_ptrcall(
        cast(GDExtensionMethodBindPtr)method,
        cast(GDExtensionObjectPtr)obj,
        cast([^]GDExtensionConstTypePtr)args,
        cast(GDExtensionTypePtr)ret,
    )
}

Object_construct :: proc(class_name: cstring) -> ObjectPtr {
    cn := string_name_from_cstring(class_name)
    defer destroy_string_name(&cn)
    assert(gde_interface.classdb_construct_object2 != nil, "[godot] classdb_construct_object2 not loaded")
    return cast(ObjectPtr)gde_interface.classdb_construct_object2(cast(GDExtensionConstStringNamePtr)&cn)
}

Vector2_create :: proc(x, y: f32) -> Vector2 {
    return Vector2{x, y}
}

Vector2i_create :: proc(x, y: i32) -> Vector2i {
    return Vector2i{x, y}
}

Vector3_create :: proc(x, y, z: f32) -> Vector3 {
    return Vector3{x, y, z}
}

Vector3i_create :: proc(x, y, z: i32) -> Vector3i {
    return Vector3i{x, y, z}
}

Vector4_create :: proc(x, y, z, w: f32) -> Vector4 {
    return Vector4{x, y, z, w}
}

Vector4i_create :: proc(x, y, z, w: i32) -> Vector4i {
    return Vector4i{x, y, z, w}
}

Rect2_create :: proc(x, y, width, height: f32) -> Rect2 {
    return Rect2{position = {x, y}, size = {width, height}}
}

Rect2i_create :: proc(x, y, width, height: i32) -> Rect2i {
    return Rect2i{position = {x, y}, size = {width, height}}
}

Color_create :: proc(r, g, b: f32, a: f32 = 1.0) -> Color {
    return Color{r, g, b, a}
}

Color_create_rgb :: proc(r, g, b: u8, a: u8 = 255) -> Color {
    return Color{f32(r) / 255.0, f32(g) / 255.0, f32(b) / 255.0, f32(a) / 255.0}
}

COLOR_WHITE :: Color{1, 1, 1, 1}
COLOR_BLACK :: Color{0, 0, 0, 1}
COLOR_RED :: Color{1, 0, 0, 1}
COLOR_GREEN :: Color{0, 1, 0, 1}
COLOR_BLUE :: Color{0, 0, 1, 1}
COLOR_YELLOW :: Color{1, 1, 0, 1}
COLOR_CYAN :: Color{0, 1, 1, 1}
COLOR_MAGENTA :: Color{1, 0, 1, 1}
COLOR_TRANSPARENT :: Color{0, 0, 0, 0}

Instance :: struct {
    ptr: ObjectPtr,
}

@(private = "file")
instance_method_start: MethodBindPtr = nil
@(private = "file")
instance_method_iteration: MethodBindPtr = nil

init_core :: proc() {
    instance_method_start = get_method_bind("GodotInstance", "start", 2240911060)
    instance_method_iteration = get_method_bind("GodotInstance", "iteration", 2240911060)
}

instance_create :: proc(argc: c.int, argv: [^][^]u8, init_func: InitializationFunction) -> (Instance, bool) {
    ptr := libgodot_create_godot_instance(argc, argv, init_func)
    if ptr == nil {
        return Instance{}, false
    }
    return Instance{ptr = ptr}, true
}

instance_destroy :: proc(instance: ^Instance) {
    if instance.ptr == nil {
        return
    }
    libgodot_destroy_godot_instance(instance.ptr)
    instance.ptr = nil
}

instance_start :: proc(instance: ^Instance) -> bool {
    assert(instance_method_start != nil, "[godot] GodotInstance.start method not bound (was init_core called?)")
    ret: u8 = 0
    ptrcall(instance_method_start, instance.ptr, nil, cast(TypePtr)&ret)
    return ret != 0
}

instance_iteration :: proc(instance: ^Instance) -> bool {
    assert(instance_method_iteration != nil, "[godot] GodotInstance.iteration method not bound (was init_core called?)")
    ret: u8 = 0
    ptrcall(instance_method_iteration, instance.ptr, nil, cast(TypePtr)&ret)
    return ret != 0
}

@(private = "file")
class_library: GDExtensionClassLibraryPtr = nil

ClassLibrary_set :: proc(lib: ClassLibraryPtr) {
    class_library = cast(GDExtensionClassLibraryPtr)lib
}

Class_register :: proc(class_name, parent_name: cstring, info: ^GDExtensionClassCreationInfo4) {
    cn := string_name_from_cstring(class_name)
    defer destroy_string_name(&cn)
    pn := string_name_from_cstring(parent_name)
    defer destroy_string_name(&pn)
    assert(gde_interface.classdb_register_extension_class5 != nil, "[godot] classdb_register_extension_class5 not loaded")
    gde_interface.classdb_register_extension_class5(
        class_library,
        cast(GDExtensionConstStringNamePtr)&cn,
        cast(GDExtensionConstStringNamePtr)&pn,
        info,
    )
}

// Variant converters - cached function pointers

@(private = "file")
VARIANT_TYPE_COUNT :: int(GDExtensionVariantType.VARIANT_TYPE_VARIANT_MAX)

@(private = "file")
variant_from_type: [VARIANT_TYPE_COUNT]GDExtensionVariantFromTypeConstructorFunc
@(private = "file")
variant_to_type: [VARIANT_TYPE_COUNT]GDExtensionTypeFromVariantConstructorFunc

init_variant_converters :: proc() {
    for i in 1 ..< VARIANT_TYPE_COUNT {
        variant_from_type[i] = gde_interface.get_variant_from_type_constructor(auto_cast i)
        variant_to_type[i] = gde_interface.get_variant_to_type_constructor(auto_cast i)
    }
}

// Low-level: construct a Variant from a typed pointer and variant type index.
Variant_from_type_ptr :: proc(type_index: GDExtensionVariantType, ptr: rawptr) -> Variant {
    v: Variant
    variant_from_type[type_index](cast(GDExtensionUninitializedVariantPtr)&v, cast(GDExtensionTypePtr)ptr)
    return v
}

Variant_from :: proc(val: $T) -> Variant {
    when T == bool {
        tmp: u8 = 1 if val else 0
        return Variant_from_type_ptr(.VARIANT_TYPE_BOOL, &tmp)
    } else {
        vtype: GDExtensionVariantType
        when T == i64            { vtype = .VARIANT_TYPE_INT }
        else when T == f64       { vtype = .VARIANT_TYPE_FLOAT }
        else when T == GodotString { vtype = .VARIANT_TYPE_STRING }
        else when T == StringName { vtype = .VARIANT_TYPE_STRING_NAME }
        else when T == ObjectPtr { vtype = .VARIANT_TYPE_OBJECT }
        else when T == Vector2   { vtype = .VARIANT_TYPE_VECTOR2 }
        else when T == Vector2i  { vtype = .VARIANT_TYPE_VECTOR2I }
        else when T == Vector3   { vtype = .VARIANT_TYPE_VECTOR3 }
        else when T == Vector3i  { vtype = .VARIANT_TYPE_VECTOR3I }
        else when T == Vector4   { vtype = .VARIANT_TYPE_VECTOR4 }
        else when T == Vector4i  { vtype = .VARIANT_TYPE_VECTOR4I }
        else when T == Color     { vtype = .VARIANT_TYPE_COLOR }
        else when T == Rect2     { vtype = .VARIANT_TYPE_RECT2 }
        else when T == Rect2i    { vtype = .VARIANT_TYPE_RECT2I }
        else when T == Transform2D { vtype = .VARIANT_TYPE_TRANSFORM2D }
        else when T == Transform3D { vtype = .VARIANT_TYPE_TRANSFORM3D }
        else when T == Basis     { vtype = .VARIANT_TYPE_BASIS }
        else when T == Quaternion { vtype = .VARIANT_TYPE_QUATERNION }
        else when T == AABB      { vtype = .VARIANT_TYPE_AABB }
        else when T == Plane     { vtype = .VARIANT_TYPE_PLANE }
        else when T == Projection { vtype = .VARIANT_TYPE_PROJECTION }
        else when T == Callable  { vtype = .VARIANT_TYPE_CALLABLE }
        else when T == Signal    { vtype = .VARIANT_TYPE_SIGNAL }
        else when T == Array     { vtype = .VARIANT_TYPE_ARRAY }
        else when T == Dictionary { vtype = .VARIANT_TYPE_DICTIONARY }
        else when T == NodePath  { vtype = .VARIANT_TYPE_NODE_PATH }
        else when T == RID       { vtype = .VARIANT_TYPE_RID }
        else { #panic("Variant_from: unsupported type") }

        tmp := val
        return Variant_from_type_ptr(vtype, &tmp)
    }
}

Variant_to :: proc($T: typeid, v: ^Variant) -> T {
    when T == bool {
        ret: u8
        variant_to_type[GDExtensionVariantType.VARIANT_TYPE_BOOL](cast(GDExtensionUninitializedTypePtr)&ret, cast(GDExtensionVariantPtr)v)
        return ret != 0
    } else {
        vtype: GDExtensionVariantType
        when T == i64            { vtype = .VARIANT_TYPE_INT }
        else when T == f64       { vtype = .VARIANT_TYPE_FLOAT }
        else when T == GodotString { vtype = .VARIANT_TYPE_STRING }
        else when T == StringName { vtype = .VARIANT_TYPE_STRING_NAME }
        else when T == Vector2   { vtype = .VARIANT_TYPE_VECTOR2 }
        else when T == Vector2i  { vtype = .VARIANT_TYPE_VECTOR2I }
        else when T == Vector3   { vtype = .VARIANT_TYPE_VECTOR3 }
        else when T == Vector3i  { vtype = .VARIANT_TYPE_VECTOR3I }
        else when T == Vector4   { vtype = .VARIANT_TYPE_VECTOR4 }
        else when T == Vector4i  { vtype = .VARIANT_TYPE_VECTOR4I }
        else when T == Color     { vtype = .VARIANT_TYPE_COLOR }
        else when T == Rect2     { vtype = .VARIANT_TYPE_RECT2 }
        else when T == Rect2i    { vtype = .VARIANT_TYPE_RECT2I }
        else when T == Transform2D { vtype = .VARIANT_TYPE_TRANSFORM2D }
        else when T == Transform3D { vtype = .VARIANT_TYPE_TRANSFORM3D }
        else when T == Basis     { vtype = .VARIANT_TYPE_BASIS }
        else when T == Quaternion { vtype = .VARIANT_TYPE_QUATERNION }
        else when T == AABB      { vtype = .VARIANT_TYPE_AABB }
        else when T == Plane     { vtype = .VARIANT_TYPE_PLANE }
        else when T == Projection { vtype = .VARIANT_TYPE_PROJECTION }
        else when T == Callable  { vtype = .VARIANT_TYPE_CALLABLE }
        else when T == Signal    { vtype = .VARIANT_TYPE_SIGNAL }
        else when T == Array     { vtype = .VARIANT_TYPE_ARRAY }
        else when T == Dictionary { vtype = .VARIANT_TYPE_DICTIONARY }
        else when T == NodePath  { vtype = .VARIANT_TYPE_NODE_PATH }
        else when T == RID       { vtype = .VARIANT_TYPE_RID }
        else { #panic("Variant_to: unsupported type") }

        ret: T
        variant_to_type[vtype](cast(GDExtensionUninitializedTypePtr)&ret, cast(GDExtensionVariantPtr)v)
        return ret
    }
}

Variant_destroy :: proc(v: ^Variant) {
    gde_interface.variant_destroy(cast(GDExtensionVariantPtr)v)
}

// Callable construction helper

Callable_from_object_method :: proc(obj: ObjectPtr, method_name: cstring) -> Callable {
    c_val: Callable
    sn := string_name_from_cstring(method_name)
    defer destroy_string_name(&sn)
    obj_copy := obj
    args: [2]GDExtensionConstTypePtr
    args[0] = cast(GDExtensionConstTypePtr)&obj_copy
    args[1] = cast(GDExtensionConstTypePtr)&sn
    builtin_lifecycle.Callable_constructor_2(cast(GDExtensionUninitializedTypePtr)&c_val, &args[0])
    return c_val
}

// Virtual method dispatch helpers

VirtualEntry :: struct {
    name:     cstring,
    callback: GDExtensionClassCallVirtual,
}

MAX_VIRTUALS_PER_CLASS :: 128
MAX_VIRTUAL_CLASSES :: 512

@(private = "file")
ResolvedVirtual :: struct {
    sn:       StringName,
    callback: GDExtensionClassCallVirtual,
}

@(private = "file")
VirtualClassEntry :: struct {
    key:     rawptr,
    entries: [MAX_VIRTUALS_PER_CLASS]ResolvedVirtual,
    count:   int,
}

@(private = "file")
registered_virtuals: [MAX_VIRTUAL_CLASSES]VirtualClassEntry
@(private = "file")
registered_virtuals_count: int = 0

@(private = "file")
default_get_virtual :: proc "c" (class_userdata: rawptr, name_ptr: GDExtensionConstStringNamePtr, _hash: u32) -> GDExtensionClassCallVirtual {
    context = runtime.default_context()

    // todo quick table lookup
    for i in 0..<registered_virtuals_count {
        if registered_virtuals[i].key == class_userdata {
            cls := &registered_virtuals[i]
            for j in 0..<cls.count {
                if (cast(^u64)name_ptr)^ == (cast(^u64)&cls.entries[j].sn)^ {
                    return cls.entries[j].callback
                }
            }
            return nil
        }
    }
    return nil
}

Class_register_virtual :: proc(class_name, parent_name: cstring, info: ^GDExtensionClassCreationInfo4, virtuals: ..VirtualEntry) {
    if len(virtuals) > 0 {
        assert(info.get_virtual_func == nil, "[godot] get_virtual_func already set, don't pass virtuals and set get_virtual_func manually")
        assert(info.class_userdata == nil, "[godot] class_userdata already set, Class_register_virtual uses class_userdata internally for virtual dispatch")
        assert(registered_virtuals_count < MAX_VIRTUAL_CLASSES, "[godot] too many registered virtual classes")
        assert(len(virtuals) <= MAX_VIRTUALS_PER_CLASS, "[godot] too many virtuals for one class")
        
        info.class_userdata = cast(rawptr)info
        cls := &registered_virtuals[registered_virtuals_count]
        cls.key = cast(rawptr)info
        cls.count = len(virtuals)
        for e, i in virtuals {
            cls.entries[i] = { sn = string_name_from_cstring(e.name), callback = e.callback }
        }

        registered_virtuals_count += 1
        info.get_virtual_func = default_get_virtual
    }

    Class_register(class_name, parent_name, info)
}

// Class instance setup

Object_set_instance :: proc(obj: ObjectPtr, class_name: cstring, instance: rawptr) {
    cn := string_name_from_cstring(class_name)
    defer destroy_string_name(&cn)
    assert(gde_interface.object_set_instance != nil, "[godot] object_set_instance not loaded")
    gde_interface.object_set_instance(
        cast(GDExtensionObjectPtr)obj,
        cast(GDExtensionConstStringNamePtr)&cn,
        cast(GDExtensionClassInstancePtr)instance,
    )
}

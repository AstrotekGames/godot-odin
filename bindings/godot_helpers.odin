package godot

import "core:c"

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

construct_object :: proc(class_name: cstring) -> ObjectPtr {
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

set_class_library :: proc(lib: ClassLibraryPtr) {
    class_library = cast(GDExtensionClassLibraryPtr)lib
}

register_class :: proc(class_name, parent_name: cstring, info: ^GDExtensionClassCreationInfo4) {
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

object_set_instance :: proc(obj: ObjectPtr, class_name: cstring, instance: rawptr) {
    cn := string_name_from_cstring(class_name)
    defer destroy_string_name(&cn)
    assert(gde_interface.object_set_instance != nil, "[godot] object_set_instance not loaded")
    gde_interface.object_set_instance(
        cast(GDExtensionObjectPtr)obj,
        cast(GDExtensionConstStringNamePtr)&cn,
        cast(GDExtensionClassInstancePtr)instance,
    )
}

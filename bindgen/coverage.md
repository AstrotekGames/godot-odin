# Binding Coverage

## Generated

```
Section                              Count    Notes
-------------------------------------+--------+--------------------------------------
builtin_class_sizes + member_offsets | all    | struct definitions
global_enums                         | 22     | all generated
builtin_classes.methods              | ~840   | all non-vararg wrappers
builtin_classes.constructors (def)   | heap   | default constructors + destructors
builtin_classes.constructors (extra) | ~28    | String(StringName) Vector2(Vector2i) etc
builtin_classes.constants            | ~210   | Vector2_Zero Color_AliceBlue Basis_Identity
builtin_classes.enums                | all    | Vector2.Axis etc
builtin_classes.vararg methods       | 6      | Callable.call .bind Signal.emit etc
classes.methods (non-virtual)        | ~14918 | ptrcall wrappers
classes.methods (virtual)            | ~1413  | vargs unpackers/packers
classes.methods (vararg)             | 16     | emit_signal call call_deferred rpc etc
classes.constants                    | all    | NotificationDraw etc
classes.enums                        | all    | MouseFilter etc
classes.signals                      | ~489   | ClassName_Signal_Name cstring constants
singletons                           | all    | singleton dispatch
utility_functions (non-vararg)       | ~102   | sin lerp clamp abs randf randi etc
utility_functions (vararg)           | 12     | godot_print godot_str godot_max etc
default_parameters                   | 1717   | 96% of 1785; numeric/bool/null/struct/zero-value
```

## Notes

- 68 defaults can't be emitted as Odin default params because they need
  heap allocation (non-empty string literals like `"Alert!"`, `&"Master"`, etc.)
  or are Variant-typed args. Not worth the complexity.
- Generated code does zero heap allocs -- vararg wrappers use stack arrays.
- `Variant_from`/`Variant_to` are generic, 27 types via compile-time `when`.
  `Variant_from_type_ptr` exists as escape hatch for the raw variant type enum.

## Skipped

```
Section                       Count  Reason
------------------------------+------+---------------------------------------------
global_constants              | 0    | empty in JSON, nothing to generate
classes.properties            | 606  | getter/setter pairs, already callable
builtin_classes.operators     | 749  | Odin handles +/*== natively for value types
native_structures             | 14   | physics/text server extension structs (niche)
```




- autogenerate bindings from json
- custom class registration and callbacks
- my planes for this to be a procedural module for the bindings generator and there will be another module if we do anything more advanced like the other Odin bindings are doing


What's missing from the coverage doc (should add to Skipped)
Nothing — the coverage doc's "Skipped" section is accurate. All JSON top-level sections are accounted for.

What will actually cause headaches when writing code
High priority (fix before writing game code):

Missing Variant converters for Vector2/3/4, Color, Array, Dictionary — Any method taking Variant (182 methods) can't receive these types. You already have Variant_from_type_ptr so adding these is trivial one-liners in the helpers.

No Variant_to_ for complex types* — Can't extract Vector2/Color/etc from Variant returns (vararg methods return Variant).

Default parameters not supported — 990 methods have defaults. Callers must pass every argument. Not a codegen issue per se, but worth knowing — methods like RichTextLabel_add_image require all 11 args.

Medium priority (annoying but workable):

Virtual dispatch allocates a StringName per comparison — your // todo comment. Pre-caching StringNames in VirtualEntry would fix it.

No Object_is_class helper exposed — you use it in main.odin via a generated wrapper, but there's no typed cast/validation pattern.

RefCounted types have no special handling — user must understand which objects are refcounted vs manually freed.

Low priority (niche):

Native structures (14) — physics/text server extension structs. Only matters if you use PhysicsServer directly instead of physics nodes.

Builtin operators — Odin handles arithmetic natively for value types. Only missing for opaque types like String concatenation (+), Array concatenation, Dictionary comparison.

Want me to add the missing Variant converters to the helpers? That's the most impactful fix — just a handful of one-liners using Variant_from_type_ptr.
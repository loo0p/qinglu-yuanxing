extends RefCounted
## 取自 GLoot v3.0.2（MIT，Copyright (c) 2022 Peter Kish）core/proto_tree.gd
## 青庐改动：去掉 class_name；deserialize 直接吃 Dictionary（data/items.json 读出来的），
## 多层“inherits 写在后面”也能挂上（原版只等一层）；不做 str_to_var（数值本来就是 JSON 数）。
## A prototype tree (prototree).
##
## A tree structure of prototypes with a root prototype that can have a number of child prototypes.

const Prototype = preload("res://scripts/vendor/gloot/prototype.gd")

var _root := Prototype.new("ROOT")


## Returns the root prototype.
func get_root():
    return _root


## Creates a child prototype for the root prototype.
func create_prototype(prototype_id: String):
    return _root.inherit(prototype_id)


## Returns the prototype with the given ID.
func get_prototype(prototype_id: String):
    return _root.get_derived_prototype(prototype_id)


## Returns an array of all child prototypes of the root.
func get_prototypes() -> Array:
    return _root.get_derived_prototypes()


## Checks if the prototree contains the prototype with the given ID.
func has_prototype(prototype_id: String) -> bool:
    return _root._prototype_id_taken(prototype_id)


## Checks if the prototype with the given ID has the given property defined.
func prototype_has_property(prototype_id: String, property: String) -> bool:
    if !has_prototype(prototype_id):
        return false
    return _root.get_derived_prototype(prototype_id).has_property(property)


## Returns the given property of the prototype with the given ID. If the prototype does not have the property defined,
## `default_value` is returned.
func get_prototype_property(prototype_id: String, property: String, default_value: Variant = null) -> Variant:
    if has_prototype(prototype_id):
        var prototype = get_prototype(prototype_id)
        if prototype.has_property(property):
            return prototype.get_property(property)
    
    return default_value


## Clears the prototree by clearing the roots properties and child prototypes.
func clear() -> void:
    _root._clear()


## Checks if the prototree is empty (the root has no properties and no child prototypes).
func is_empty() -> bool:
    return _root.get_properties().is_empty() && _root.get_derived_prototypes().is_empty()


## Parses the given prototype dictionary into a prototree. Returns `false` if some "inherits" never resolves.
func deserialize(data: Dictionary) -> bool:
    clear()
    var pending: Array = data.keys()
    var progress := true
    while progress and not pending.is_empty():
        progress = false
        var rest: Array = []
        for prototype_id in pending:
            var d: Dictionary = data[prototype_id]
            var base = _root
            if d.has("inherits"):
                base = _root._find_derived_prototype(String(d["inherits"]))
            if base == null:
                rest.append(prototype_id)
                continue
            _deserialize_prototype(d, base, String(prototype_id))
            progress = true
        pending = rest
    return pending.is_empty()


func _deserialize_prototype(prototype_dict: Dictionary, base, prototype_id: String):
    var new_protototype = base.inherit(prototype_id)
    for property in prototype_dict.keys():
        if property != "inherits":
            new_protototype.set_property(property, prototype_dict[property])
    return new_protototype

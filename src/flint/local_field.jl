export NonArchimedeanLocalField, NonArchimedeanLocalFieldElem, FlintLocalField, FlintLocalFieldElem, NALocalField, NALocalFieldElem

parent_type(::Type{NALocalFieldElem}) = NALocalField

parent_type(::Type{FlintLocalFieldElem}) = FlintLocalField

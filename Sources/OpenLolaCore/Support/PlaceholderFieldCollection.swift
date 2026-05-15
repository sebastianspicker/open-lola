typealias PlaceholderSensitiveField = (name: String, value: String)

func placeholderFields(_ fields: PlaceholderSensitiveField...) -> [PlaceholderSensitiveField] {
    fields
}

func placeholderFields<Root>(
    _ root: Root,
    prefix: String,
    _ fields: [(name: String, keyPath: KeyPath<Root, String>)]
) -> [PlaceholderSensitiveField] {
    fields.map { field in
        ("\(prefix).\(field.name)", root[keyPath: field.keyPath])
    }
}

func placeholderFields<Root>(
    _ values: [Root],
    prefix: (Int, Root) -> String,
    _ fields: [(name: String, keyPath: KeyPath<Root, String>)]
) -> [PlaceholderSensitiveField] {
    values.enumerated().flatMap { index, value in
        placeholderFields(value, prefix: prefix(index, value), fields)
    }
}

func placeholderIndexedFields(
    _ values: [String],
    prefix: String
) -> [PlaceholderSensitiveField] {
    values.enumerated().map { index, value in
        ("\(prefix)[\(index)]", value)
    }
}

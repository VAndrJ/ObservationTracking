import SwiftSyntax

extension AttributeSyntax {
    func hasAttributeName(_ expectedName: String) -> Bool {
        if let identifierType = attributeName.as(IdentifierTypeSyntax.self) {
            return identifierType.name.text == expectedName
        }

        if let memberType = attributeName.as(MemberTypeSyntax.self) {
            return memberType.name.text == expectedName
        }

        return false
    }
}

extension AttributeListSyntax.Element {
    func hasAttributeName(_ expectedName: String) -> Bool {
        guard case let .attribute(attribute) = self else {
            return false
        }

        return attribute.hasAttributeName(expectedName)
    }
}

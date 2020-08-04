//
//  SchemaFragmentResolvingTests.swift
//  
//
//  Created by Mathew Polzin on 8/2/20.
//

import Foundation
import XCTest
import OpenAPIKit

final class SchemaFragmentResolvingTests: XCTestCase {
    // MARK: - Empty
    func test_resolveEmptyFragmentsList() throws {
        let fragments: [JSONSchemaFragment] = []
        XCTAssertEqual(
            try fragments.resolved(against: .noComponents),
            .undefined(description: nil)
        )
    }

    // MARK: - Single Fragment
    func test_resolvingSingleDescription() {
        let fragments: [JSONSchemaFragment] = [
            .general(.init(description: "hello world"))
        ]
        XCTAssertEqual(
            try fragments.resolved(against: .noComponents),
            .undefined(description: "hello world")
        )
    }

    func test_resolvingSingleBoolean() {
        let fragments: [JSONSchemaFragment] = [
            .boolean(.init())
        ]
        XCTAssertEqual(
            try fragments.resolved(against: .noComponents),
            .boolean(.init())
        )
    }

    func test_resolvingSingleInteger() {
        let fragments: [JSONSchemaFragment] = [
            .integer(.init(), .init())
        ]
        XCTAssertEqual(
            try fragments.resolved(against: .noComponents),
            .integer(.init(), .init())
        )
    }

    func test_resolvingSingleNumber() {
        let fragments: [JSONSchemaFragment] = [
            .number(.init(), .init())
        ]
        XCTAssertEqual(
            try fragments.resolved(against: .noComponents),
            .number(.init(), .init())
        )
    }

    func test_resolveSingleString() {
        let fragments: [JSONSchemaFragment] = [
            .string(.init(), .init())
        ]
        XCTAssertEqual(
            try fragments.resolved(against: .noComponents),
            .string(.init(), .init())
        )
    }

    func test_resolvingSingleArray() {
        let fragments: [JSONSchemaFragment] = [
            .array(.init(), .init())
        ]
        XCTAssertEqual(
            try fragments.resolved(against: .noComponents),
            .array(.init(), DereferencedJSONSchema.ArrayContext(JSONSchema.ArrayContext())!)
        )
    }

    func test_resolvingSingleObject() {
        let fragments: [JSONSchemaFragment] = [
            .object(.init(), .init())
        ]
        XCTAssertEqual(
            try fragments.resolved(against: .noComponents),
            .object(.init(), DereferencedJSONSchema.ObjectContext(JSONSchema.ObjectContext(properties: [:]))!)
        )
    }

    // MARK: - Formats
    func test_resolvingSingleIntegerWithFormat() {
        let fragments: [JSONSchemaFragment] = [
            .integer(.init(format: "int32"), .init())
        ]
        XCTAssertEqual(
            try fragments.resolved(against: .noComponents),
            .integer(.init(format: .int32), .init())
        )
    }

    func test_resolvingSingleNumberWithFormat() {
        let fragments: [JSONSchemaFragment] = [
            .number(.init(format: "double"), .init())
        ]
        XCTAssertEqual(
            try fragments.resolved(against: .noComponents),
            .number(.init(format: .double), .init())
        )
    }

    func test_resolveSingleStringWithFormat() {
        let fragments: [JSONSchemaFragment] = [
            .string(.init(format: "binary"), .init())
        ]
        XCTAssertEqual(
            try fragments.resolved(against: .noComponents),
            .string(.init(format: .binary), .init())
        )
    }

    // MARK: - Fragment Combinations
    func test_resolveStringFragmentAndDisciminatorFragment() {
        let fragments: [JSONSchemaFragment] = [
            .string(.init(), .init()),
            .general(.init(discriminator: .init(propertyName: "test")))
        ]
        XCTAssertEqual(
            try fragments.resolved(against: .noComponents),
            .string(.init(discriminator: .init(propertyName: "test")), .init())
        )

        // at least in one test, make sure order of fragments does not matter
        let fragments2: [JSONSchemaFragment] = [
            .general(.init(discriminator: .init(propertyName: "test"))),
            .string(.init(), .init())
        ]
        XCTAssertEqual(
            try fragments2.resolved(against: .noComponents),
            .string(.init(discriminator: .init(propertyName: "test")), .init())
        )
    }

    #warning("TODO: add more fragment combination tests")

    // MARK: - Dereferencing
    #warning("TODO")

    // MARK: - Conflict Failures
    func test_typeConflicts() {
        let booleanFragment = JSONSchemaFragment.boolean(.init())
        let integerFragment = JSONSchemaFragment.integer(.init(), .init())
        let numberFragment = JSONSchemaFragment.number(.init(), .init())
        let stringFragment = JSONSchemaFragment.string(.init(), .init())
        let arrayFragment = JSONSchemaFragment.array(.init(), .init())
        let objectFragment = JSONSchemaFragment.object(.init(), .init())

        let fragments = [
            booleanFragment,
            integerFragment,
            numberFragment,
            stringFragment,
            arrayFragment,
            objectFragment
        ]

        for left in fragments {
            for right in fragments where right != left {
                XCTAssertThrowsError(try [left, right].resolved(against: .noComponents)) { error in
                    guard let error = error as? JSONSchemaResolutionError else { XCTFail("Received unexpected error"); return }
                    XCTAssert(error ~= .typeConflict)
                }
            }
        }
    }

    func test_booleanFormatConflicts() {
        // boolean does not have any built-in formats, but we can use two different custom formats.
        let format1: JSONTypeFormat.BooleanFormat = .other("integer")
        let format2: JSONTypeFormat.BooleanFormat = .other("textual")

        let formatStrings = [
            format1,
            format2
        ].map { $0.rawValue }

        for left in formatStrings {
            for right in formatStrings where left != right {
                let fragments: [JSONSchemaFragment] = [
                    .boolean(.init(format: left)),
                    .boolean(.init(format: right))
                ]
                XCTAssertThrowsError(try fragments.resolved(against: .noComponents)) { error in
                    guard let error = error as? JSONSchemaResolutionError else { XCTFail("Received unexpected error"); return }
                    XCTAssert(error ~= .formatConflict)
                }
            }
        }
    }

    func test_integerFormatConflicts() {
        let int32: JSONTypeFormat.IntegerFormat = .int32
        let int64: JSONTypeFormat.IntegerFormat = .int64
        let uint32: JSONTypeFormat.IntegerFormat = .extended(.uint32)
        let other: JSONTypeFormat.IntegerFormat = .other("bigint")

        let formatStrings = [
            int32,
            int64,
            uint32,
            other
        ].map { $0.rawValue }

        for left in formatStrings {
            for right in formatStrings where left != right {
                let fragments: [JSONSchemaFragment] = [
                    .integer(.init(format: left), .init()),
                    .integer(.init(format: right), .init())
                ]
                XCTAssertThrowsError(try fragments.resolved(against: .noComponents)) { error in
                    guard let error = error as? JSONSchemaResolutionError else { XCTFail("Received unexpected error"); return }
                    XCTAssert(error ~= .formatConflict)
                }
            }
        }
    }

    func test_numberFormatConflicts() {
        let float: JSONTypeFormat.NumberFormat = .float
        let double: JSONTypeFormat.NumberFormat = .double
        let other: JSONTypeFormat.NumberFormat = .other("bigint")

        let formatStrings = [
            float,
            double,
            other
        ].map { $0.rawValue }

        for left in formatStrings {
            for right in formatStrings where left != right {
                let fragments: [JSONSchemaFragment] = [
                    .number(.init(format: left), .init()),
                    .number(.init(format: right), .init())
                ]
                XCTAssertThrowsError(try fragments.resolved(against: .noComponents)) { error in
                    guard let error = error as? JSONSchemaResolutionError else { XCTFail("Received unexpected error"); return }
                    XCTAssert(error ~= .formatConflict)
                }
            }
        }
    }

    func test_StringFormatConflicts() {
        let byte: JSONTypeFormat.StringFormat = .byte
        let binary: JSONTypeFormat.StringFormat = .binary
        let date: JSONTypeFormat.StringFormat = .date
        let dateTime: JSONTypeFormat.StringFormat = .dateTime
        let password: JSONTypeFormat.StringFormat = .password
        let uuid: JSONTypeFormat.StringFormat = .extended(.uuid)
        let other: JSONTypeFormat.StringFormat = .other("moontalk")

        let formatStrings = [
            byte,
            binary,
            date,
            dateTime,
            password,
            uuid,
            other
        ].map { $0.rawValue }

        for left in formatStrings {
            for right in formatStrings where left != right {
                let fragments: [JSONSchemaFragment] = [
                    .string(.init(format: left), .init()),
                    .string(.init(format: right), .init())
                ]
                XCTAssertThrowsError(try fragments.resolved(against: .noComponents)) { error in
                    guard let error = error as? JSONSchemaResolutionError else { XCTFail("Received unexpected error"); return }
                    XCTAssert(error ~= .formatConflict)
                }
            }
        }
    }

    func test_ArrayFormatConflicts() {
        // array does not have any built-in formats, but we can use two different custom formats.
        let format1: JSONTypeFormat.ArrayFormat = .other("numbered")
        let format2: JSONTypeFormat.ArrayFormat = .other("bulleted")

        let formatStrings = [
            format1,
            format2
        ].map { $0.rawValue }

        for left in formatStrings {
            for right in formatStrings where left != right {
                let fragments: [JSONSchemaFragment] = [
                    .array(.init(format: left), .init()),
                    .array(.init(format: right), .init())
                ]
                XCTAssertThrowsError(try fragments.resolved(against: .noComponents)) { error in
                    guard let error = error as? JSONSchemaResolutionError else { XCTFail("Received unexpected error"); return }
                    XCTAssert(error ~= .formatConflict)
                }
            }
        }
    }

    func test_ObjectFormatConflicts() {
        // object does not have any built-in formats, but we can use two different custom formats.
        let format1: JSONTypeFormat.ObjectFormat = .other("compact")
        let format2: JSONTypeFormat.ObjectFormat = .other("pretty")

        let formatStrings = [
            format1,
            format2
        ].map { $0.rawValue }

        for left in formatStrings {
            for right in formatStrings where left != right {
                let fragments: [JSONSchemaFragment] = [
                    .object(.init(format: left), .init()),
                    .object(.init(format: right), .init())
                ]
                XCTAssertThrowsError(try fragments.resolved(against: .noComponents)) { error in
                    guard let error = error as? JSONSchemaResolutionError else { XCTFail("Received unexpected error"); return }
                    XCTAssert(error ~= .formatConflict)
                }
            }
        }
    }

    func test_generalAttributeConflicts() {

        let differentDescription = [
            JSONSchemaFragment.GeneralContext(description: "string1"),
            JSONSchemaFragment.GeneralContext(description: "string2")
        ]

        let differentDiscriminator = [
            JSONSchemaFragment.GeneralContext(discriminator: .init(propertyName: "string1")),
            JSONSchemaFragment.GeneralContext(discriminator: .init(propertyName: "string2"))
        ]

        let differentTitle = [
            JSONSchemaFragment.GeneralContext(title: "string1"),
            JSONSchemaFragment.GeneralContext(title: "string2")
        ]

        let differentNullable = [
            JSONSchemaFragment.GeneralContext(nullable: true),
            JSONSchemaFragment.GeneralContext(nullable: false)
        ]

        let differentDeprecated = [
            JSONSchemaFragment.GeneralContext(deprecated: true),
            JSONSchemaFragment.GeneralContext(deprecated: false)
        ]

        let differentExternalDocs = [
            JSONSchemaFragment.GeneralContext(externalDocs: .init(url: URL(string: "https://string1.com")!)),
            JSONSchemaFragment.GeneralContext(externalDocs: .init(url: URL(string: "https://string2.com")!))
        ]

        let differentAllowedValues = [
            JSONSchemaFragment.GeneralContext(allowedValues: ["string1"]),
            JSONSchemaFragment.GeneralContext(allowedValues: ["string2"])
        ]

        let differentExample = [
            JSONSchemaFragment.GeneralContext(example: "string1"),
            JSONSchemaFragment.GeneralContext(example: "string2")
        ]

        let differentReadOnly = [
            JSONSchemaFragment.GeneralContext(readOnly: true),
            JSONSchemaFragment.GeneralContext(readOnly: false)
        ]

        let differentWriteOnly = [
            JSONSchemaFragment.GeneralContext(writeOnly: true),
            JSONSchemaFragment.GeneralContext(writeOnly: false)
        ]

        let differences = [
            differentDescription,
            differentDiscriminator,
            differentTitle,
            differentNullable,
            differentDeprecated,
            differentExternalDocs,
            differentAllowedValues,
            differentExample,
            differentReadOnly,
            differentWriteOnly
        ]

        // break up for type checking
        let fragmentsArray1: [[JSONSchemaFragment]] = differences.map { $0.map { .general($0) } }
            + differences.map { $0.map { .boolean($0) } }
            + differences.map { $0.map { .integer($0, .init()) } }
            + differences.map { $0.map { .number($0, .init()) } }
        let fragmentsArray2: [[JSONSchemaFragment]] = differences.map { $0.map { .string($0, .init()) } }
            + differences.map { $0.map { .array($0, .init()) } }
            + differences.map { $0.map { .object($0, .init()) } }

        for fragments in fragmentsArray1 + fragmentsArray2 {
            XCTAssertThrowsError(try fragments.resolved(against: .noComponents)) { error in
                guard let error = error as? JSONSchemaResolutionError else { XCTFail("Received unexpected error"); return }
                XCTAssert(error ~= .attributeConflict, "\(error) is not ~= `.formatConflict` --  \(fragments)")
            }
        }
    }

    func test_integerAttributeConflicts() {
        let differentMultipleOf = [
            JSONSchemaFragment.IntegerContext(multipleOf: 10),
            JSONSchemaFragment.IntegerContext(multipleOf: 2)
        ]

        let differentMaximum = [
            JSONSchemaFragment.IntegerContext(maximum: 10),
            JSONSchemaFragment.IntegerContext(maximum: 100)
        ]

        let differentExclusiveMaximum = [
            JSONSchemaFragment.IntegerContext(exclusiveMaximum: true),
            JSONSchemaFragment.IntegerContext(exclusiveMaximum: false)
        ]

        let differentMinimum = [
            JSONSchemaFragment.IntegerContext(minimum: 1),
            JSONSchemaFragment.IntegerContext(minimum: 3)
        ]

        let differentExclusiveMinimum = [
            JSONSchemaFragment.IntegerContext(exclusiveMinimum: true),
            JSONSchemaFragment.IntegerContext(exclusiveMinimum: false)
        ]

        let differences = [
            differentMultipleOf,
            differentMaximum,
            differentExclusiveMaximum,
            differentMinimum,
            differentExclusiveMinimum
        ]

        for difference in differences {
            let fragments: [JSONSchemaFragment] = difference.map { .integer(.init(), $0) }
            XCTAssertThrowsError(try fragments.resolved(against: .noComponents)) { error in
                guard let error = error as? JSONSchemaResolutionError else { XCTFail("Received unexpected error"); return }
                XCTAssert(error ~= .attributeConflict, "\(error) is not ~= `.formatConflict` --  \(fragments)")
            }
        }
    }

    func test_numberAttributeConflicts() {
        let differentMultipleOf = [
            JSONSchemaFragment.NumericContext(multipleOf: 10),
            JSONSchemaFragment.NumericContext(multipleOf: 2)
        ]

        let differentMaximum = [
            JSONSchemaFragment.NumericContext(maximum: 10),
            JSONSchemaFragment.NumericContext(maximum: 100)
        ]

        let differentExclusiveMaximum = [
            JSONSchemaFragment.NumericContext(exclusiveMaximum: true),
            JSONSchemaFragment.NumericContext(exclusiveMaximum: false)
        ]

        let differentMinimum = [
            JSONSchemaFragment.NumericContext(minimum: 1),
            JSONSchemaFragment.NumericContext(minimum: 3)
        ]

        let differentExclusiveMinimum = [
            JSONSchemaFragment.NumericContext(exclusiveMinimum: true),
            JSONSchemaFragment.NumericContext(exclusiveMinimum: false)
        ]

        let differences = [
            differentMultipleOf,
            differentMaximum,
            differentExclusiveMaximum,
            differentMinimum,
            differentExclusiveMinimum
        ]

        for difference in differences {
            let fragments: [JSONSchemaFragment] = difference.map { .number(.init(), $0) }
            XCTAssertThrowsError(try fragments.resolved(against: .noComponents)) { error in
                guard let error = error as? JSONSchemaResolutionError else { XCTFail("Received unexpected error"); return }
                XCTAssert(error ~= .attributeConflict, "\(error) is not ~= `.formatConflict` --  \(fragments)")
            }
        }
    }

    func test_StringAttributeConflicts() {
        let differentMaxLength = [
            JSONSchemaFragment.StringContext(maxLength: 10),
            JSONSchemaFragment.StringContext(maxLength: 2)
        ]

        let differentMinLength = [
            JSONSchemaFragment.StringContext(minLength: 10),
            JSONSchemaFragment.StringContext(minLength: 100)
        ]

        let differentPattern = [
            JSONSchemaFragment.StringContext(pattern: "string1"),
            JSONSchemaFragment.StringContext(pattern: "string2")
        ]

        let differences = [
            differentMaxLength,
            differentMinLength,
            differentPattern
        ]

        for difference in differences {
            let fragments: [JSONSchemaFragment] = difference.map { .string(.init(), $0) }
            XCTAssertThrowsError(try fragments.resolved(against: .noComponents)) { error in
                guard let error = error as? JSONSchemaResolutionError else { XCTFail("Received unexpected error"); return }
                XCTAssert(error ~= .attributeConflict, "\(error) is not ~= `.formatConflict` --  \(fragments)")
            }
        }
    }

    func test_ArrayAttributeConflicts() {
        let differentItems = [
            JSONSchemaFragment.ArrayContext(items: .string),
            JSONSchemaFragment.ArrayContext(items: .boolean)
        ]

        let differentMaxItems = [
            JSONSchemaFragment.ArrayContext(maxItems: 10),
            JSONSchemaFragment.ArrayContext(maxItems: 100)
        ]

        let differentMinItems = [
            JSONSchemaFragment.ArrayContext(minItems: 1),
            JSONSchemaFragment.ArrayContext(minItems: 2)
        ]

        let differentUniqueItems = [
            JSONSchemaFragment.ArrayContext(uniqueItems: true),
            JSONSchemaFragment.ArrayContext(uniqueItems: false)
        ]

        let differences = [
            differentItems,
            differentMaxItems,
            differentMinItems,
            differentUniqueItems
        ]

        for difference in differences {
            let fragments: [JSONSchemaFragment] = difference.map { .array(.init(), $0) }
            XCTAssertThrowsError(try fragments.resolved(against: .noComponents)) { error in
                guard let error = error as? JSONSchemaResolutionError else { XCTFail("Received unexpected error"); return }
                XCTAssert(error ~= .attributeConflict, "\(error) is not ~= `.formatConflict` --  \(fragments)")
            }
        }
    }

    func test_ObjectAttributeConflicts() {
        let differentMaxProperties = [
            JSONSchemaFragment.ObjectContext(maxProperties: 10),
            JSONSchemaFragment.ObjectContext(maxProperties: 2)
        ]

        let differentMinProperties = [
            JSONSchemaFragment.ObjectContext(minProperties: 10),
            JSONSchemaFragment.ObjectContext(minProperties: 100)
        ]

        let differentProperties = [
            JSONSchemaFragment.ObjectContext(properties: ["string1": .string(description: "truth")]),
            JSONSchemaFragment.ObjectContext(properties: ["string1": .string(description: "falsity")])
        ]

        let differentAdditionalProperties1 = [
            JSONSchemaFragment.ObjectContext(additionalProperties: .init(true)),
            JSONSchemaFragment.ObjectContext(additionalProperties: .init(false))
        ]

        let differentAdditionalProperties2 = [
            JSONSchemaFragment.ObjectContext(additionalProperties: .init(true)),
            JSONSchemaFragment.ObjectContext(additionalProperties: .init(.string))
        ]

        let differentAdditionalProperties3 = [
            JSONSchemaFragment.ObjectContext(additionalProperties: .init(.boolean)),
            JSONSchemaFragment.ObjectContext(additionalProperties: .init(.string))
        ]

        let differentRequiredProeprties = [
            JSONSchemaFragment.ObjectContext(requiredProperties: []),
            JSONSchemaFragment.ObjectContext(requiredProperties: ["string1"])
        ]

        let differences = [
            differentMaxProperties,
            differentMinProperties,
            differentProperties,
            differentAdditionalProperties1,
            differentAdditionalProperties2,
            differentAdditionalProperties3,
            differentRequiredProeprties
        ]

        for difference in differences {
            let fragments: [JSONSchemaFragment] = difference.map { .object(.init(), $0) }
            XCTAssertThrowsError(try fragments.resolved(against: .noComponents), "\(fragments)") { error in
                guard let error = error as? JSONSchemaResolutionError else { XCTFail("Received unexpected error"); return }
                XCTAssert(error ~= .attributeConflict, "\(error) is not ~= `.formatConflict` --  \(fragments)")
            }
        }
    }

    // MARK: - Inconsistency Failures
    #warning("TODO")
}

// Loads JSON fixtures from valid, invalid, or root bundle locations in precedence order.
import Foundation
import Testing

func loadJSONFixture<Fixture>(
    named name: String,
    fixtureDirectory: String,
    decode: (Data) throws -> Fixture
) throws -> Fixture {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "\(fixtureDirectory)/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "\(fixtureDirectory)/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    let url = try #require(validURL ?? invalidURL ?? rootURL)
    return try decode(Data(contentsOf: url))
}

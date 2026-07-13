import CryptoKit
import Foundation

struct AppcastConfiguration: Equatable, Sendable {
    let feedURL: URL
    let publicEdKey: Data

    init(feedURL: URL, publicEdKeyBase64: String) throws {
        guard feedURL.scheme?.lowercased() == "https" else {
            throw UpdateFailure.invalidConfiguration("Appcast URL must use HTTPS")
        }
        guard let key = Data(base64Encoded: publicEdKeyBase64), key.count == 32 else {
            throw UpdateFailure.invalidConfiguration("EdDSA public key must decode to 32 bytes")
        }
        self.feedURL = feedURL
        publicEdKey = key
    }
}

struct SignedAppcastVerifier {
    private let configuration: AppcastConfiguration

    init(configuration: AppcastConfiguration) {
        self.configuration = configuration
    }

    func release(from data: Data, currentBuild: String, fixtureRoot: URL? = nil) throws -> UpdateRelease? {
        let parser = AppcastParser(data: data)
        guard parser.parse(), let item = parser.item else {
            throw UpdateFailure.invalidFeed(parser.parserError?.localizedDescription ?? "Malformed appcast")
        }
        guard item.url.scheme?.lowercased() == "https" || (fixtureRoot != nil && item.url.isFileURL) else {
            throw UpdateFailure.invalidFeed("Update archive URL must use HTTPS")
        }
        let archiveURL = fixtureRoot.map { item.url.isFileURL ? item.url : $0.appendingPathComponent(item.url.lastPathComponent) } ?? item.url
        guard archiveURL.isFileURL else {
            throw UpdateFailure.invalidFeed("Probe verification requires a local archive")
        }
        let archive = try Data(contentsOf: archiveURL)
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: configuration.publicEdKey)
        guard key.isValidSignature(item.signature, for: archive) else { throw UpdateFailure.signatureRejected }
        return compareBuild(item.build, currentBuild) == .orderedDescending
            ? UpdateRelease(version: item.version, build: item.build, downloadURL: item.url, contentLength: Int64(archive.count))
            : nil
    }

    private func compareBuild(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.compare(rhs, options: .numeric)
    }
}

private final class AppcastParser: NSObject, XMLParserDelegate {
    struct Item { let version: String; let build: String; let url: URL; let signature: Data }
    private let parser: XMLParser
    private(set) var item: Item?
    private(set) var parserError: Error?

    init(data: Data) { parser = XMLParser(data: data); super.init(); parser.delegate = self }
    func parse() -> Bool { parser.parse() && item != nil }
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) { parserError = parseError }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        guard elementName == "enclosure" || qName == "enclosure" else { return }
        guard let version = attributes["sparkle:shortVersionString"],
              let build = attributes["sparkle:version"],
              let urlString = attributes["url"], let url = URL(string: urlString),
              let signatureString = attributes["sparkle:edSignature"], let signature = Data(base64Encoded: signatureString)
        else { return }
        item = Item(version: version, build: build, url: url, signature: signature)
    }
}

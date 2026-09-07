import AppKit
import Foundation

/// Builds the web URL for a review item and hands it to the browser.
///
/// The web app is a hash-router SPA, so every route lives behind `/#/`. If the
/// user is signed out there, its route guard bounces to `/#/login?redirect=…`
/// and sends them back here after a successful login — that round trip is
/// handled entirely on the web side; all this type has to do is produce the
/// destination URL.
enum ReviewDeepLink {
    static func url(for item: IslandReviewItem, webBaseURL: URL) -> URL? {
        let base = webBaseURL.absoluteString
            .components(separatedBy: "#")[0]
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let subjectID = item.subjectID, subjectID.isEmpty == false else {
            // No subject to open — land the user on the dashboard rather than
            // on a broken route.
            return URL(string: "\(base)/#/home")
        }
        return URL(string: "\(base)/#/subject/\(subjectID)?point=\(item.id)")
    }
}

/// Opens web links in the user's default browser.
///
/// `NSWorkspace.open` already reuses a running browser instead of launching a
/// second copy — we only ask it to activate so the existing window comes
/// forward. The short repeat window additionally swallows accidental
/// double-taps on the same island row, which would otherwise pile up
/// duplicate tabs.
final class ReviewDeepLinkOpener {
    private let webBaseURL: URL
    private let opener: ExternalURLOpening
    private let now: () -> Date
    private var lastOpenedURL: URL?
    private var lastOpenedAt: Date?

    /// Repeat taps on the same item inside this window are ignored.
    static let duplicateSuppressionWindow: TimeInterval = 1.5

    init(
        webBaseURL: URL,
        opener: ExternalURLOpening = NSWorkspace.shared,
        now: @escaping () -> Date = Date.init
    ) {
        self.webBaseURL = webBaseURL
        self.opener = opener
        self.now = now
    }

    @discardableResult
    func open(_ item: IslandReviewItem) -> Bool {
        guard let url = ReviewDeepLink.url(for: item, webBaseURL: webBaseURL) else { return false }
        let timestamp = now()
        if let lastOpenedURL,
           let lastOpenedAt,
           lastOpenedURL == url,
           timestamp.timeIntervalSince(lastOpenedAt) < Self.duplicateSuppressionWindow {
            return false
        }
        lastOpenedURL = url
        lastOpenedAt = timestamp
        return opener.open(url)
    }
}

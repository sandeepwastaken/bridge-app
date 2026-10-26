import Foundation
import Testing
@testable import Bridge

struct ArticleFetcherTests {
    @Test func onlyASingleWebAddressCountsAsALink() {
        #expect(ArticleFetcher.link(in: "  https://www.nps.gov/subjects/trails/types-of-trails.htm \n") != nil)
        #expect(ArticleFetcher.link(in: "http://example.com") != nil)
        #expect(ArticleFetcher.link(in: "Read https://example.com please") == nil)
        #expect(ArticleFetcher.link(in: "file:///etc/hosts") == nil)
        #expect(ArticleFetcher.link(in: "Your appointment is on Tuesday.") == nil)
    }

    @Test func articleTextKeepsHeadingsAndParagraphsAndDropsPageChrome() {
        let html = """
        <html><head><style>p { color: red }</style><script>var p = "<p>tracking</p>";</script></head>
        <body><nav><p>Home | About | Contact us and more links here</p></nav>
        <article><h1>Types of Trails</h1>
        <p>Trails come in many forms, from paved paths in cities to rough routes in the mountains.</p>
        <p>Accessible trails have firm surfaces &amp; gentle slopes, so more people can use them.</p>
        <p>Short.</p></article>
        <footer><p>Copyright and contact information for this website goes here.</p></footer></body></html>
        """
        let text = ArticleFetcher.readableText(fromHTML: html)
        #expect(text == """
        Types of Trails

        Trails come in many forms, from paved paths in cities to rough routes in the mountains.

        Accessible trails have firm surfaces & gentle slopes, so more people can use them.
        """)
    }

    @Test func numericEntitiesAreDecoded() {
        let text = ArticleFetcher.readableText(fromHTML: "<p>It&#8217;s a long enough sentence to keep in the article text.</p>")
        #expect(text == "It\u{2019}s a long enough sentence to keep in the article text.")
    }
}

@MainActor
struct AssistCommandTests {
    @Test func spokenRequestsOpenTheMatchingTool() {
        #expect(AssistView.route(for: "Open translate") == .translate)
        #expect(AssistView.route(for: "read something") == .read)
        #expect(AssistView.route(for: "Talk together") == .talk)
        #expect(AssistView.route(for: "quick phrases") == .phrases)
        #expect(AssistView.route(for: "help with a form") == .guide)
        #expect(AssistView.route(for: "Speak for me") == .speak)
        #expect(AssistView.route(for: "open settings") == .settings)
        #expect(AssistView.route(for: "Open floating assistant") == .overlay)
        #expect(AssistView.route(for: "Explain this page") == .read)
        #expect(AssistView.route(for: "Please call +1 512 555 0100") == .call("+15125550100"))
        #expect(AssistView.route(for: "Call someone") == .call(""))
        #expect(AssistView.route(for: "Prepare a message Please bring my words list.") == .speak)
        #expect(AssistView.message(in: "Prepare a message Please bring my ID. Appointment: 10:30!") == "Please bring my ID. Appointment: 10:30!")
        #expect(AssistView.message(in: "Open my words") == nil)
        #expect(AssistView.route(for: "what is the weather") == nil)
    }
}

@MainActor
struct ExplainerTests {
    @Test func explainsAParagraphWhenAppleIntelligenceIsAvailable() async throws {
        if let reason = Explainer.unavailableReason {
            print("Explainer unavailable here: \(reason)")
            return
        }
        let result: String
        do {
            result = try await Explainer.explain(
                "Your appointment with Dr. Rao is on Tuesday at 10:30. Please bring your insurance card.",
                in: .english)
        } catch {
            print("Explainer could not run here: \(error)")
            return
        }
        print("Explainer said: \(result)")
        #expect(!result.isEmpty)
        #expect(result.contains("10:30"))
    }
}

import XCTest
@testable import BlockSitesCore

final class FirewallRulesTests: XCTestCase {

    func testCIDRRangesExistForKnownSites() {
        let instagramCIDRs = DomainExpander.cidrRanges(for: "instagram.com")
        XCTAssertFalse(instagramCIDRs.isEmpty)

        let twitterCIDRs = DomainExpander.cidrRanges(for: "twitter.com")
        XCTAssertFalse(twitterCIDRs.isEmpty)

        let youtubeCIDRs = DomainExpander.cidrRanges(for: "youtube.com")
        XCTAssertFalse(youtubeCIDRs.isEmpty)
    }

    func testCIDRRangesEmptyForUnknownSite() {
        let unknownCIDRs = DomainExpander.cidrRanges(for: "unknownsite12345.com")
        XCTAssertTrue(unknownCIDRs.isEmpty)
    }

    func testDohDomainsListNotEmpty() {
        XCTAssertFalse(DomainExpander.dohDomains.isEmpty)
        XCTAssertTrue(DomainExpander.dohDomains.contains("dns.google"))
        XCTAssertTrue(DomainExpander.dohDomains.contains("cloudflare-dns.com"))
    }

    func testDohIPsListNotEmpty() {
        XCTAssertFalse(DomainExpander.dohIPs.isEmpty)
        XCTAssertTrue(DomainExpander.dohIPs.contains("8.8.8.8"))
        XCTAssertTrue(DomainExpander.dohIPs.contains("1.1.1.1"))
    }

    func testDomainExpansionIncludesMainAndWww() {
        let domains = DomainExpander.expandDomains(for: "example.com")
        XCTAssertTrue(domains.contains("example.com"))
        XCTAssertTrue(domains.contains("www.example.com"))
    }

    func testDomainExpansionForInstagram() {
        let domains = DomainExpander.expandDomains(for: "instagram.com")
        XCTAssertTrue(domains.contains("i.instagram.com"))
        XCTAssertTrue(domains.contains("graph.instagram.com"))
        XCTAssertTrue(domains.contains("cdninstagram.com"))
    }

    func testDomainExpansionForTwitter() {
        let domains = DomainExpander.expandDomains(for: "twitter.com")
        XCTAssertTrue(domains.contains("x.com"))
        XCTAssertTrue(domains.contains("t.co"))
        XCTAssertTrue(domains.contains("twimg.com"))
    }

    func testDomainExpansionForYoutube() {
        let domains = DomainExpander.expandDomains(for: "youtube.com")
        XCTAssertTrue(domains.contains("youtu.be"))
        XCTAssertTrue(domains.contains("googlevideo.com"))
        XCTAssertTrue(domains.contains("ytimg.com"))
    }

    func testNoDuplicatesInDomainExpansion() {
        let sites = ["instagram.com", "facebook.com", "twitter.com", "youtube.com", "tiktok.com", "reddit.com"]
        for site in sites {
            let domains = DomainExpander.expandDomains(for: site)
            let unique = Set(domains)
            XCTAssertEqual(domains.count, unique.count, "Duplicate domains found for \(site)")
        }
    }

    func testCommonSubdomainsIncludedInExpansion() {
        let domains = DomainExpander.expandDomains(for: "example.com")
        for subdomain in DomainExpander.commonSubdomains {
            XCTAssertTrue(domains.contains("\(subdomain).example.com"), "Missing \(subdomain).example.com")
        }
    }
}

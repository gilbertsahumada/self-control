import XCTest
@testable import BlockSitesCore

final class DomainExpanderTests: XCTestCase {

    // MARK: - Generic Site Expansion

    func testGenericSiteIncludesMainAndWww() {
        let domains = DomainExpander.expandDomains(for: "example.com")
        XCTAssertTrue(domains.contains("example.com"))
        XCTAssertTrue(domains.contains("www.example.com"))
    }

    func testGenericSiteIncludesCommonSubdomains() {
        let domains = DomainExpander.expandDomains(for: "example.com")
        for subdomain in DomainExpander.commonSubdomains {
            XCTAssertTrue(domains.contains("\(subdomain).example.com"),
                          "Missing subdomain: \(subdomain).example.com")
        }
    }

    func testGenericSiteHasExpectedCount() {
        let domains = DomainExpander.expandDomains(for: "example.com")
        // main + www + 8 common subdomains = 10
        XCTAssertEqual(domains.count, 10)
    }

    // MARK: - Instagram

    func testInstagramIncludesSpecificDomains() {
        let domains = DomainExpander.expandDomains(for: "instagram.com")
        XCTAssertTrue(domains.contains("i.instagram.com"))
        XCTAssertTrue(domains.contains("graph.instagram.com"))
        XCTAssertTrue(domains.contains("cdninstagram.com"))
        XCTAssertTrue(domains.contains("scontent.cdninstagram.com"))
        XCTAssertTrue(domains.contains("edge-chat.instagram.com"))
        // New critical domains
        XCTAssertTrue(domains.contains("gateway.instagram.com"))
        XCTAssertTrue(domains.contains("lookaside.instagram.com"))
        XCTAssertTrue(domains.contains("lookaside.fbsbx.com"))
        XCTAssertTrue(domains.contains("edge-mqtt.instagram.com"))
        XCTAssertTrue(domains.contains("platform.instagram.com"))
        XCTAssertTrue(domains.contains("accountscenter.instagram.com"))
        // Specific regional CDN servers
        XCTAssertTrue(domains.contains("scontent-lax3-1.cdninstagram.com"))
        XCTAssertTrue(domains.contains("scontent-iad3-1.cdninstagram.com"))
    }

    func testInstagramDoesNotContainWildcard() {
        let domains = DomainExpander.expandDomains(for: "instagram.com")
        for domain in domains {
            XCTAssertFalse(domain.contains("*"), "Wildcard found in domain: \(domain) — wildcards don't work in /etc/hosts")
        }
    }

    // MARK: - Facebook

    func testFacebookIncludesSpecificDomains() {
        let domains = DomainExpander.expandDomains(for: "facebook.com")
        XCTAssertTrue(domains.contains("fbcdn.net"))
        XCTAssertTrue(domains.contains("fbcdn.com"))
        XCTAssertTrue(domains.contains("connect.facebook.net"))
        XCTAssertTrue(domains.contains("staticxx.facebook.com"))
        XCTAssertTrue(domains.contains("graph.facebook.com"))
    }

    // MARK: - Twitter/X

    func testTwitterIncludesCrossDomains() {
        let domains = DomainExpander.expandDomains(for: "twitter.com")
        XCTAssertTrue(domains.contains("x.com"))
        XCTAssertTrue(domains.contains("t.co"))
        XCTAssertTrue(domains.contains("twimg.com"))
        XCTAssertTrue(domains.contains("pbs.twimg.com"))
    }

    func testXComIncludesCrossDomains() {
        let domains = DomainExpander.expandDomains(for: "x.com")
        XCTAssertTrue(domains.contains("twitter.com"))
        XCTAssertTrue(domains.contains("t.co"))
        XCTAssertTrue(domains.contains("twimg.com"))
    }

    // MARK: - YouTube

    func testYoutubeIncludesSpecificDomains() {
        let domains = DomainExpander.expandDomains(for: "youtube.com")
        XCTAssertTrue(domains.contains("youtu.be"))
        XCTAssertTrue(domains.contains("googlevideo.com"))
        XCTAssertTrue(domains.contains("ytimg.com"))
        XCTAssertTrue(domains.contains("music.youtube.com"))
        XCTAssertTrue(domains.contains("youtube-nocookie.com"))
    }

    // MARK: - TikTok

    func testTiktokIncludesSpecificDomains() {
        let domains = DomainExpander.expandDomains(for: "tiktok.com")
        XCTAssertTrue(domains.contains("vm.tiktok.com"))
        XCTAssertTrue(domains.contains("t.tiktok.com"))
        XCTAssertTrue(domains.contains("mon.musical.ly"))
        XCTAssertTrue(domains.contains("sf-tb-sg.ibytedtos.com"))
    }

    // MARK: - Reddit

    func testRedditIncludesSpecificDomains() {
        let domains = DomainExpander.expandDomains(for: "reddit.com")
        XCTAssertTrue(domains.contains("old.reddit.com"))
        XCTAssertTrue(domains.contains("new.reddit.com"))
        XCTAssertTrue(domains.contains("redd.it"))
        XCTAssertTrue(domains.contains("i.redd.it"))
        XCTAssertTrue(domains.contains("v.redd.it"))
        XCTAssertTrue(domains.contains("redditstatic.com"))
    }

    // MARK: - Firewall Expansion

    func testExpandDomainsForFirewallIncludesMainAndWww() {
        let domains = DomainExpander.expandDomainsForFirewall("example.com")
        XCTAssertEqual(domains[0], "example.com")
        XCTAssertEqual(domains[1], "www.example.com")
    }

    func testExpandDomainsForFirewallTwitter() {
        let domains = DomainExpander.expandDomainsForFirewall("twitter.com")
        XCTAssertTrue(domains.contains("t.co"))
        XCTAssertTrue(domains.contains("twimg.com"))
        XCTAssertTrue(domains.contains("api.twitter.com"))
    }

    func testExpandDomainsForFirewallYoutube() {
        let domains = DomainExpander.expandDomainsForFirewall("youtube.com")
        XCTAssertTrue(domains.contains("youtu.be"))
        XCTAssertTrue(domains.contains("googlevideo.com"))
    }

    func testExpandDomainsForFirewallInstagram() {
        let domains = DomainExpander.expandDomainsForFirewall("instagram.com")
        XCTAssertTrue(domains.contains("gateway.instagram.com"))
        XCTAssertTrue(domains.contains("lookaside.instagram.com"))
        XCTAssertTrue(domains.contains("edge-mqtt.instagram.com"))
        XCTAssertTrue(domains.contains("platform.instagram.com"))
        XCTAssertTrue(domains.contains("web.instagram.com"))
        XCTAssertTrue(domains.contains("lookaside.fbsbx.com"))
        // Should have significantly more than the old 7 domains
        XCTAssertGreaterThanOrEqual(domains.count, 12)
    }

    // MARK: - CIDR Ranges

    func testCIDRRangesExistForInstagram() {
        let cidrs = DomainExpander.cidrRanges(for: "instagram.com")
        XCTAssertFalse(cidrs.isEmpty, "Instagram should have CIDR ranges")
        XCTAssertTrue(cidrs.contains("157.240.0.0/16"), "Should include Meta primary range")
    }

    func testCIDRRangesExistForTwitter() {
        let cidrs = DomainExpander.cidrRanges(for: "twitter.com")
        XCTAssertFalse(cidrs.isEmpty, "Twitter should have CIDR ranges")
        XCTAssertTrue(cidrs.contains("104.244.40.0/21"), "Should include Twitter primary range")
    }

    func testCIDRRangesEmptyForUnknownSite() {
        let cidrs = DomainExpander.cidrRanges(for: "unknownsite123.com")
        XCTAssertTrue(cidrs.isEmpty, "Unknown sites should have no CIDR ranges")
    }

    func testCIDRRangesExistForYoutube() {
        let cidrs = DomainExpander.cidrRanges(for: "youtube.com")
        XCTAssertFalse(cidrs.isEmpty, "YouTube should have CIDR ranges")
        XCTAssertTrue(cidrs.contains("142.250.0.0/15"), "Should include Google primary range")
    }

    // MARK: - DNS-over-HTTPS

    func testDohDomainsListIsNotEmpty() {
        XCTAssertFalse(DomainExpander.dohDomains.isEmpty, "DoH domains list should not be empty")
        XCTAssertTrue(DomainExpander.dohDomains.contains("dns.google"))
        XCTAssertTrue(DomainExpander.dohDomains.contains("cloudflare-dns.com"))
        XCTAssertTrue(DomainExpander.dohDomains.contains("mozilla.cloudflare-dns.com"))
    }

    func testDohIPsListIsNotEmpty() {
        XCTAssertFalse(DomainExpander.dohIPs.isEmpty, "DoH IPs list should not be empty")
        XCTAssertTrue(DomainExpander.dohIPs.contains("8.8.8.8"))
        XCTAssertTrue(DomainExpander.dohIPs.contains("1.1.1.1"))
        XCTAssertTrue(DomainExpander.dohIPs.contains("9.9.9.9"))
    }

    // MARK: - Subdomain Count

    func testSubdomainCountMatchesExpandedDomains() {
        let sites = ["example.com", "twitter.com", "instagram.com", "facebook.com",
                      "youtube.com", "tiktok.com", "reddit.com", "x.com"]
        for site in sites {
            let expanded = DomainExpander.expandDomains(for: site)
            let count = DomainExpander.subdomainCount(for: site)
            XCTAssertEqual(count, expanded.count - 1,
                           "subdomainCount mismatch for \(site): expected \(expanded.count - 1), got \(count)")
        }
    }

    // MARK: - No Duplicates

    func testNoDuplicateDomainsInExpansion() {
        let sites = ["twitter.com", "instagram.com", "facebook.com",
                      "youtube.com", "tiktok.com", "reddit.com", "x.com"]
        for site in sites {
            let domains = DomainExpander.expandDomains(for: site)
            let unique = Set(domains)
            XCTAssertEqual(domains.count, unique.count,
                           "Duplicate domains found for \(site): \(domains.count) total, \(unique.count) unique")
        }
    }
}

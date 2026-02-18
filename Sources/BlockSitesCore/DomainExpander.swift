import Foundation

public enum DomainExpander {
    public static let commonSubdomains = ["mobile", "m", "api", "static", "cdn", "pbs", "abs", "video"]

    // MARK: - CIDR Ranges

    /// Known CIDR ranges for major platforms. Blocking these at the firewall level
    /// prevents bypass via DNS-over-HTTPS since it operates at the network layer.
    public static let knownCIDRRanges: [String: [String]] = [
        "instagram.com": [
            "157.240.0.0/16",   // Meta primary
            "31.13.24.0/21",    // Meta
            "31.13.64.0/18",    // Meta
            "129.134.0.0/16",   // Meta
            "185.89.218.0/23",  // Meta
            "179.60.192.0/22",  // Meta
        ],
        "facebook.com": [
            "157.240.0.0/16",
            "31.13.24.0/21",
            "31.13.64.0/18",
            "129.134.0.0/16",
            "185.89.218.0/23",
            "179.60.192.0/22",
        ],
        "twitter.com": [
            "104.244.40.0/21",
            "199.16.156.0/22",
            "199.59.148.0/22",
            "69.195.160.0/19",
        ],
        "x.com": [
            "104.244.40.0/21",
            "199.16.156.0/22",
            "199.59.148.0/22",
            "69.195.160.0/19",
        ],
        "youtube.com": [
            "142.250.0.0/15",   // Google
            "172.217.0.0/16",   // Google
            "216.58.192.0/19",  // Google
            "74.125.0.0/16",    // Google
            "173.194.0.0/16",   // Google
        ],
        "tiktok.com": [
            "161.117.0.0/16",   // ByteDance
            "144.22.0.0/16",    // ByteDance
            "152.199.0.0/16",   // Edgecast/Verizon CDN
        ],
        "reddit.com": [
            "151.101.0.0/16",   // Fastly
            "199.232.0.0/16",   // Fastly
        ],
    ]

    /// Returns CIDR ranges to block for a given site.
    public static func cidrRanges(for site: String) -> [String] {
        return knownCIDRRanges[site] ?? []
    }

    // MARK: - DNS-over-HTTPS Blocking

    /// Known DNS-over-HTTPS provider domains. Blocking these in /etc/hosts forces
    /// browsers to fall back to system DNS, which respects /etc/hosts entries.
    public static let dohDomains: [String] = [
        "dns.google",
        "dns.google.com",
        "cloudflare-dns.com",
        "mozilla.cloudflare-dns.com",
        "dns.quad9.net",
        "doh.opendns.com",
        "dns.nextdns.io",
        "doh.cleanbrowsing.org",
        "dns.adguard.com",
    ]

    /// Known DNS-over-HTTPS provider IPs. Blocking these on port 443 in the firewall
    /// prevents encrypted DNS lookups that bypass /etc/hosts.
    public static let dohIPs: [String] = [
        "8.8.8.8",         // Google DNS
        "8.8.4.4",         // Google DNS
        "1.1.1.1",         // Cloudflare DNS
        "1.0.0.1",         // Cloudflare DNS
        "9.9.9.9",         // Quad9
        "149.112.112.112", // Quad9
        "208.67.222.222",  // OpenDNS
        "208.67.220.220",  // OpenDNS
    ]

    // MARK: - Domain Expansion

    /// Returns ALL domains to block for a given site (main + www + common subdomains + site-specific).
    public static func expandDomains(for site: String) -> [String] {
        var domains: [String] = []

        // Main domain + www
        domains.append(site)
        domains.append("www.\(site)")

        // Common subdomains
        for subdomain in commonSubdomains {
            domains.append("\(subdomain).\(site)")
        }

        // Site-specific domains
        switch site {
        case "x.com", "twitter.com":
            let xDomains = [
                "x.com", "www.x.com", "mobile.x.com", "api.x.com",
                "twitter.com", "www.twitter.com", "mobile.twitter.com", "api.twitter.com",
                "t.co", "www.t.co",
                "twimg.com", "pbs.twimg.com", "abs.twimg.com", "video.twimg.com"
            ]
            domains.append(contentsOf: xDomains)

        case "instagram.com":
            let igDomains = [
                "instagram.com", "www.instagram.com", "i.instagram.com",
                "graph.instagram.com", "edge-chat.instagram.com",
                "scontent.cdninstagram.com", "cdninstagram.com",
                "www.cdninstagram.com", "static.cdninstagram.com",
                // Specific regional CDN servers (wildcards don't work in /etc/hosts)
                "scontent-lax3-1.cdninstagram.com",
                "scontent-lax3-2.cdninstagram.com",
                "scontent-iad3-1.cdninstagram.com",
                "scontent-iad3-2.cdninstagram.com",
                "scontent-atl3-1.cdninstagram.com",
                "scontent-atl3-2.cdninstagram.com",
                "scontent-dfw5-1.cdninstagram.com",
                "scontent-dfw5-2.cdninstagram.com",
                "scontent-sea1-1.cdninstagram.com",
                "scontent-mia3-1.cdninstagram.com",
                "scontent-ord5-1.cdninstagram.com",
                "scontent-den4-1.cdninstagram.com",
                // Critical missing domains
                "l.instagram.com", "b.i.instagram.com",
                "about.instagram.com", "help.instagram.com",
                "web.instagram.com", "d.instagram.com",
                "z-p3-graph.instagram.com", "z-p4-graph.instagram.com",
                "gateway.instagram.com", "lookaside.instagram.com",
                "lookaside.fbsbx.com",
                "edge-mqtt.instagram.com", "platform.instagram.com",
                "accountscenter.instagram.com",
            ]
            domains.append(contentsOf: igDomains)

        case "facebook.com":
            let fbDomains = [
                "facebook.com", "www.facebook.com", "m.facebook.com",
                "web.facebook.com", "mobile.facebook.com",
                "graph.facebook.com", "edge-chat.facebook.com",
                "static.facebook.com", "staticxx.facebook.com",
                "upload.facebook.com", "l.facebook.com",
                "fbcdn.net", "static.xx.fbcdn.net", "scontent.xx.fbcdn.net",
                "video.xx.fbcdn.net", "external.xx.fbcdn.net",
                "fbcdn.com", "connect.facebook.net",
                "star.facebook.com", "z-m-graph.facebook.com"
            ]
            domains.append(contentsOf: fbDomains)

        case "youtube.com":
            let ytDomains = [
                "youtube.com", "www.youtube.com", "m.youtube.com",
                "youtu.be", "www.youtu.be",
                "youtube-nocookie.com", "www.youtube-nocookie.com",
                "googlevideo.com", "www.googlevideo.com",
                "ytimg.com", "i.ytimg.com", "s.ytimg.com",
                "music.youtube.com", "tv.youtube.com",
                "accounts.youtube.com", "studio.youtube.com"
            ]
            domains.append(contentsOf: ytDomains)

        case "tiktok.com":
            let ttDomains = [
                "tiktok.com", "www.tiktok.com", "m.tiktok.com",
                "vm.tiktok.com", "t.tiktok.com",
                "sf-tb-sg.ibytedtos.com", "v16m-default.akamaized.net",
                "mon.musical.ly", "log.tiktokv.com",
                "ib.tiktokv.com", "api.tiktokv.com"
            ]
            domains.append(contentsOf: ttDomains)

        case "reddit.com":
            let rdDomains = [
                "reddit.com", "www.reddit.com", "old.reddit.com",
                "new.reddit.com", "i.reddit.com", "m.reddit.com",
                "sh.reddit.com", "oauth.reddit.com",
                "redd.it", "i.redd.it", "v.redd.it", "preview.redd.it",
                "external-preview.redd.it", "www.redditmedia.com",
                "redditstatic.com", "www.redditstatic.com"
            ]
            domains.append(contentsOf: rdDomains)

        default:
            break
        }

        // Deduplicate while preserving order
        var seen = Set<String>()
        return domains.filter { seen.insert($0).inserted }
    }

    /// Returns key domains for IP resolution (firewall blocking).
    public static func expandDomainsForFirewall(_ site: String) -> [String] {
        var domains = [site, "www.\(site)"]

        switch site {
        case "instagram.com":
            domains += [
                "i.instagram.com", "graph.instagram.com",
                "scontent.cdninstagram.com", "cdninstagram.com",
                "edge-chat.instagram.com", "gateway.instagram.com",
                "lookaside.instagram.com", "edge-mqtt.instagram.com",
                "platform.instagram.com", "web.instagram.com",
                "l.instagram.com", "lookaside.fbsbx.com",
            ]
        case "facebook.com":
            domains += ["m.facebook.com", "web.facebook.com", "graph.facebook.com", "fbcdn.net", "fbcdn.com", "connect.facebook.net", "static.facebook.com"]
        case "twitter.com", "x.com":
            domains += ["api.x.com", "api.twitter.com", "t.co", "twimg.com", "pbs.twimg.com"]
        case "youtube.com":
            domains += ["m.youtube.com", "youtu.be", "googlevideo.com", "ytimg.com"]
        case "tiktok.com":
            domains += ["m.tiktok.com", "vm.tiktok.com"]
        case "reddit.com":
            domains += ["old.reddit.com", "i.redd.it", "v.redd.it", "redd.it"]
        default:
            break
        }

        return domains
    }

    /// Returns the number of subdomains that will be blocked for a given site (excluding the main domain itself).
    public static func subdomainCount(for site: String) -> Int {
        return expandDomains(for: site).count - 1
    }
}

import Foundation

public enum HostsGenerator {
    /// Generates hosts file entries for the given sites, marked with the
    /// specified marker. Writes both an IPv4 (`127.0.0.1`) and an IPv6
    /// (`::1`) mapping for every domain so browsers asking for an AAAA
    /// record cannot bypass the block via IPv6.
    ///
    /// Also adds DNS-over-HTTPS provider domains so browsers are forced to
    /// use the system resolver, which honours `/etc/hosts`.
    public static func generateHostsEntries(for sites: [String], marker: String = "# MONKMODE") -> String {
        var blockEntries = "\n\(marker) START\n"
        for site in sites {
            let domains = DomainExpander.expandDomains(for: site)
            for domain in domains {
                blockEntries += "127.0.0.1 \(domain) \(marker)\n"
                blockEntries += "::1 \(domain) \(marker)\n"
            }
        }

        for domain in DomainExpander.dohDomains {
            blockEntries += "127.0.0.1 \(domain) \(marker)\n"
            blockEntries += "::1 \(domain) \(marker)\n"
        }

        blockEntries += "\(marker) END\n"
        return blockEntries
    }

    /// Removes all lines containing the marker from the given hosts content.
    public static func cleanHostsContent(_ content: String, marker: String = "# MONKMODE") -> String {
        let lines = content.components(separatedBy: .newlines)
        return lines.filter { !$0.contains(marker) }.joined(separator: "\n")
    }
}

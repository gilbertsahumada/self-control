import Foundation

public enum HostsGenerator {
    /// Generates hosts file entries for the given sites, marked with the specified marker.
    /// Also includes DNS-over-HTTPS provider domains to force browsers to use system DNS.
    public static func generateHostsEntries(for sites: [String], marker: String = "# BLOCKSITES") -> String {
        var blockEntries = "\n\(marker) START\n"
        for site in sites {
            let domains = DomainExpander.expandDomains(for: site)
            for domain in domains {
                blockEntries += "127.0.0.1 \(domain) \(marker)\n"
            }
        }

        // Block DNS-over-HTTPS providers to force browsers to use system DNS
        // (which respects /etc/hosts entries)
        for domain in DomainExpander.dohDomains {
            blockEntries += "127.0.0.1 \(domain) \(marker)\n"
        }

        blockEntries += "\(marker) END\n"
        return blockEntries
    }

    /// Removes all lines containing the marker from the given hosts content.
    public static func cleanHostsContent(_ content: String, marker: String = "# BLOCKSITES") -> String {
        let lines = content.components(separatedBy: .newlines)
        return lines.filter { !$0.contains(marker) }.joined(separator: "\n")
    }
}

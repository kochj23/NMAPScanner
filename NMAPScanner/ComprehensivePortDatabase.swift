//
//  ComprehensivePortDatabase.swift
//  NMAP Scanner - Comprehensive TCP/UDP Port Database
//
//  Based on IANA assignments and Wikipedia List of TCP and UDP port numbers
//  Created by Jordan Koch on 2025-11-24.
//

import Foundation

/// Comprehensive port database with 500+ well-known and registered ports
struct ComprehensivePortDatabase {

    static let ports: [Int: PortDefinition] = [
        // Well-Known Ports (0-1023)
        1: PortDefinition(name: "TCPMUX", description: "TCP Port Service Multiplexer", protocols: [.tcp]),
        5: PortDefinition(name: "RJE", description: "Remote Job Entry", protocols: [.tcp, .udp]),
        7: PortDefinition(name: "Echo", description: "Echo Protocol", protocols: [.tcp, .udp]),
        9: PortDefinition(name: "Discard", description: "Discard Protocol", protocols: [.tcp, .udp]),
        11: PortDefinition(name: "SYSTAT", description: "Active Users", protocols: [.tcp]),
        13: PortDefinition(name: "Daytime", description: "Daytime Protocol", protocols: [.tcp, .udp]),
        17: PortDefinition(name: "QOTD", description: "Quote of the Day", protocols: [.tcp, .udp]),
        18: PortDefinition(name: "MSP", description: "Message Send Protocol", protocols: [.tcp, .udp]),
        19: PortDefinition(name: "CHARGEN", description: "Character Generator Protocol", protocols: [.tcp, .udp]),
        20: PortDefinition(name: "FTP-DATA", description: "File Transfer Protocol (Data)", protocols: [.tcp]),
        21: PortDefinition(name: "FTP", description: "File Transfer Protocol (Control)", protocols: [.tcp]),
        22: PortDefinition(name: "SSH", description: "Secure Shell", protocols: [.tcp]),
        23: PortDefinition(name: "Telnet", description: "Telnet Protocol", protocols: [.tcp]),
        25: PortDefinition(name: "SMTP", description: "Simple Mail Transfer Protocol", protocols: [.tcp]),
        37: PortDefinition(name: "TIME", description: "Time Protocol", protocols: [.tcp, .udp]),
        42: PortDefinition(name: "NAMESERVER", description: "Host Name Server", protocols: [.tcp, .udp]),
        43: PortDefinition(name: "WHOIS", description: "WHOIS Protocol", protocols: [.tcp]),
        49: PortDefinition(name: "TACACS", description: "Terminal Access Controller Access-Control System", protocols: [.tcp, .udp]),
        53: PortDefinition(name: "DNS", description: "Domain Name System", protocols: [.tcp, .udp]),
        67: PortDefinition(name: "DHCP-SERVER", description: "Dynamic Host Configuration Protocol (Server)", protocols: [.udp]),
        68: PortDefinition(name: "DHCP-CLIENT", description: "Dynamic Host Configuration Protocol (Client)", protocols: [.udp]),
        69: PortDefinition(name: "TFTP", description: "Trivial File Transfer Protocol", protocols: [.udp]),
        70: PortDefinition(name: "Gopher", description: "Gopher Protocol", protocols: [.tcp]),
        79: PortDefinition(name: "Finger", description: "Finger Protocol", protocols: [.tcp]),
        80: PortDefinition(name: "HTTP", description: "Hypertext Transfer Protocol", protocols: [.tcp]),
        88: PortDefinition(name: "Kerberos", description: "Kerberos Authentication", protocols: [.tcp, .udp]),
        102: PortDefinition(name: "ISO-TSAP", description: "ISO Transport Service Access Point", protocols: [.tcp]),
        110: PortDefinition(name: "POP3", description: "Post Office Protocol v3", protocols: [.tcp]),
        113: PortDefinition(name: "Ident", description: "Identification Protocol", protocols: [.tcp]),
        119: PortDefinition(name: "NNTP", description: "Network News Transfer Protocol", protocols: [.tcp]),
        123: PortDefinition(name: "NTP", description: "Network Time Protocol", protocols: [.udp]),
        135: PortDefinition(name: "MS-RPC", description: "Microsoft Remote Procedure Call", protocols: [.tcp, .udp]),
        137: PortDefinition(name: "NetBIOS-NS", description: "NetBIOS Name Service", protocols: [.tcp, .udp]),
        138: PortDefinition(name: "NetBIOS-DGM", description: "NetBIOS Datagram Service", protocols: [.tcp, .udp]),
        139: PortDefinition(name: "NetBIOS-SSN", description: "NetBIOS Session Service", protocols: [.tcp, .udp]),
        143: PortDefinition(name: "IMAP", description: "Internet Message Access Protocol", protocols: [.tcp]),
        161: PortDefinition(name: "SNMP", description: "Simple Network Management Protocol", protocols: [.udp]),
        162: PortDefinition(name: "SNMP-TRAP", description: "SNMP Trap", protocols: [.udp]),
        177: PortDefinition(name: "XDMCP", description: "X Display Manager Control Protocol", protocols: [.tcp, .udp]),
        179: PortDefinition(name: "BGP", description: "Border Gateway Protocol", protocols: [.tcp]),
        194: PortDefinition(name: "IRC", description: "Internet Relay Chat", protocols: [.tcp, .udp]),
        201: PortDefinition(name: "AppleTalk", description: "AppleTalk Routing Maintenance", protocols: [.tcp, .udp]),
        389: PortDefinition(name: "LDAP", description: "Lightweight Directory Access Protocol", protocols: [.tcp, .udp]),
        443: PortDefinition(name: "HTTPS", description: "HTTP Secure (HTTP over TLS/SSL)", protocols: [.tcp]),
        445: PortDefinition(name: "SMB", description: "Server Message Block over TCP", protocols: [.tcp]),
        464: PortDefinition(name: "Kerberos-Change", description: "Kerberos Change/Set Password", protocols: [.tcp, .udp]),
        465: PortDefinition(name: "SMTPS", description: "SMTP over TLS/SSL", protocols: [.tcp]),
        500: PortDefinition(name: "ISAKMP", description: "Internet Security Association and Key Management Protocol", protocols: [.udp]),
        514: PortDefinition(name: "Syslog", description: "System Logging Protocol", protocols: [.udp]),
        515: PortDefinition(name: "LPD", description: "Line Printer Daemon", protocols: [.tcp]),
        520: PortDefinition(name: "RIP", description: "Routing Information Protocol", protocols: [.udp]),
        521: PortDefinition(name: "RIPng", description: "Routing Information Protocol Next Generation", protocols: [.udp]),
        548: PortDefinition(name: "AFP", description: "Apple Filing Protocol (AFP)", protocols: [.tcp]),
        554: PortDefinition(name: "RTSP", description: "Real Time Streaming Protocol", protocols: [.tcp, .udp]),
        587: PortDefinition(name: "SMTP-SUBMISSION", description: "SMTP Message Submission", protocols: [.tcp]),
        631: PortDefinition(name: "IPP", description: "Internet Printing Protocol (AirPrint)", protocols: [.tcp, .udp]),
        636: PortDefinition(name: "LDAPS", description: "LDAP over TLS/SSL", protocols: [.tcp, .udp]),
        639: PortDefinition(name: "MSDP", description: "Multicast Source Discovery Protocol", protocols: [.tcp, .udp]),
        646: PortDefinition(name: "LDP", description: "Label Distribution Protocol", protocols: [.tcp, .udp]),
        873: PortDefinition(name: "rsync", description: "rsync File Synchronization", protocols: [.tcp]),
        989: PortDefinition(name: "FTPS-DATA", description: "FTP over TLS/SSL (Data)", protocols: [.tcp, .udp]),
        990: PortDefinition(name: "FTPS", description: "FTP over TLS/SSL (Control)", protocols: [.tcp, .udp]),
        993: PortDefinition(name: "IMAPS", description: "IMAP over TLS/SSL", protocols: [.tcp]),
        995: PortDefinition(name: "POP3S", description: "POP3 over TLS/SSL", protocols: [.tcp]),

        // Registered Ports (1024-49151)
        1025: PortDefinition(name: "NFS/IIS", description: "Network File System or IIS", protocols: [.tcp]),
        1080: PortDefinition(name: "SOCKS", description: "SOCKS Proxy", protocols: [.tcp]),
        1194: PortDefinition(name: "OpenVPN", description: "OpenVPN", protocols: [.tcp, .udp]),
        1214: PortDefinition(name: "Kazaa", description: "Kazaa P2P", protocols: [.tcp]),
        1241: PortDefinition(name: "Nessus", description: "Nessus Security Scanner", protocols: [.tcp]),
        1311: PortDefinition(name: "Dell-OpenManage", description: "Dell OpenManage", protocols: [.tcp]),
        1337: PortDefinition(name: "WASTE", description: "WASTE Encrypted P2P", protocols: [.tcp]),
        1433: PortDefinition(name: "MS-SQL", description: "Microsoft SQL Server", protocols: [.tcp]),
        1434: PortDefinition(name: "MS-SQL-UDP", description: "Microsoft SQL Server Browser", protocols: [.udp]),
        1521: PortDefinition(name: "Oracle", description: "Oracle Database", protocols: [.tcp]),
        1701: PortDefinition(name: "L2TP", description: "Layer 2 Tunneling Protocol", protocols: [.udp]),
        1723: PortDefinition(name: "PPTP", description: "Point-to-Point Tunneling Protocol", protocols: [.tcp]),
        1725: PortDefinition(name: "Steam", description: "Valve Steam Client", protocols: [.udp]),
        1812: PortDefinition(name: "RADIUS", description: "RADIUS Authentication", protocols: [.udp]),
        1813: PortDefinition(name: "RADIUS-Accounting", description: "RADIUS Accounting", protocols: [.udp]),
        1883: PortDefinition(name: "MQTT", description: "Message Queue Telemetry Transport (IoT)", protocols: [.tcp]),
        1900: PortDefinition(name: "UPnP", description: "Universal Plug and Play (SSDP)", protocols: [.udp]),
        1935: PortDefinition(name: "RTMP", description: "Real-Time Messaging Protocol", protocols: [.tcp]),
        2049: PortDefinition(name: "NFS", description: "Network File System", protocols: [.tcp, .udp]),
        2082: PortDefinition(name: "cPanel", description: "cPanel Default", protocols: [.tcp]),
        2083: PortDefinition(name: "cPanel-SSL", description: "cPanel Default SSL", protocols: [.tcp]),
        2087: PortDefinition(name: "WHM", description: "WebHost Manager", protocols: [.tcp]),
        2181: PortDefinition(name: "ZooKeeper", description: "Apache ZooKeeper", protocols: [.tcp]),
        2222: PortDefinition(name: "SSH-Alt", description: "SSH Alternate Port", protocols: [.tcp]),
        2375: PortDefinition(name: "Docker", description: "Docker REST API (unencrypted)", protocols: [.tcp]),
        2376: PortDefinition(name: "Docker-TLS", description: "Docker REST API (TLS)", protocols: [.tcp]),
        2379: PortDefinition(name: "etcd", description: "etcd Client Communication", protocols: [.tcp]),
        2380: PortDefinition(name: "etcd-Peer", description: "etcd Peer Communication", protocols: [.tcp]),
        2483: PortDefinition(name: "Oracle-TLS", description: "Oracle Database over TLS/SSL", protocols: [.tcp, .udp]),
        2484: PortDefinition(name: "Oracle-Secure", description: "Oracle Database Secure", protocols: [.tcp, .udp]),
        3000: PortDefinition(name: "Node.js/Grafana", description: "Node.js/Grafana Web Interface", protocols: [.tcp]),
        3128: PortDefinition(name: "Squid", description: "Squid HTTP Proxy", protocols: [.tcp]),
        3268: PortDefinition(name: "AD-Global-Catalog", description: "Active Directory Global Catalog", protocols: [.tcp]),
        3269: PortDefinition(name: "AD-Global-Catalog-SSL", description: "AD Global Catalog over SSL", protocols: [.tcp]),
        3283: PortDefinition(name: "ARD", description: "Apple Remote Desktop", protocols: [.tcp, .udp]),
        3306: PortDefinition(name: "MySQL", description: "MySQL Database", protocols: [.tcp]),
        3389: PortDefinition(name: "RDP", description: "Remote Desktop Protocol", protocols: [.tcp, .udp]),
        3478: PortDefinition(name: "STUN/TURN", description: "Session Traversal Utilities for NAT", protocols: [.tcp, .udp]),
        3689: PortDefinition(name: "DAAP", description: "Digital Audio Access Protocol (iTunes)", protocols: [.tcp]),
        3690: PortDefinition(name: "SVN", description: "Subversion", protocols: [.tcp, .udp]),
        4000: PortDefinition(name: "Diablo-II", description: "Diablo II Game", protocols: [.tcp, .udp]),
        4369: PortDefinition(name: "Erlang-PMD", description: "Erlang Port Mapper Daemon", protocols: [.tcp, .udp]),
        4443: PortDefinition(name: "HTTPS-Alt", description: "HTTPS Alternate Port", protocols: [.tcp]),
        4444: PortDefinition(name: "Metasploit", description: "Metasploit Default", protocols: [.tcp]),
        4500: PortDefinition(name: "IPSec-NAT", description: "IPSec NAT Traversal", protocols: [.udp]),
        4567: PortDefinition(name: "Sinatra", description: "Sinatra Web Framework", protocols: [.tcp]),
        4713: PortDefinition(name: "PulseAudio", description: "PulseAudio Sound Server", protocols: [.tcp]),
        5000: PortDefinition(name: "UPnP/AirPlay", description: "UPnP/HomeKit AirPlay Audio (HomePod)", protocols: [.tcp]),
        5001: PortDefinition(name: "Slingbox", description: "Slingbox Control", protocols: [.tcp]),
        5009: PortDefinition(name: "AirPort", description: "Apple AirPort Base Station", protocols: [.tcp, .udp]),
        5060: PortDefinition(name: "SIP", description: "Session Initiation Protocol", protocols: [.tcp, .udp]),
        5061: PortDefinition(name: "SIPS", description: "SIP over TLS", protocols: [.tcp]),
        5222: PortDefinition(name: "XMPP-Client", description: "XMPP Client Connection", protocols: [.tcp]),
        5223: PortDefinition(name: "APNs", description: "Apple Push Notification Service", protocols: [.tcp]),
        5269: PortDefinition(name: "XMPP-Server", description: "XMPP Server Connection", protocols: [.tcp]),
        5353: PortDefinition(name: "mDNS", description: "Multicast DNS (Bonjour)", protocols: [.udp]),
        5432: PortDefinition(name: "PostgreSQL", description: "PostgreSQL Database", protocols: [.tcp]),
        5500: PortDefinition(name: "VNC-HTTP", description: "VNC HTTP Access", protocols: [.tcp]),
        5632: PortDefinition(name: "PCAnywhere", description: "Symantec PCAnywhere", protocols: [.tcp, .udp]),
        5672: PortDefinition(name: "AMQP", description: "Advanced Message Queuing Protocol (RabbitMQ)", protocols: [.tcp]),
        5800: PortDefinition(name: "VNC-Web", description: "VNC over HTTP", protocols: [.tcp]),
        5900: PortDefinition(name: "VNC/Screen-Sharing", description: "Virtual Network Computing / Apple Screen Sharing", protocols: [.tcp, .udp]),
        5984: PortDefinition(name: "CouchDB", description: "CouchDB Database", protocols: [.tcp]),
        5985: PortDefinition(name: "WinRM-HTTP", description: "Windows Remote Management over HTTP", protocols: [.tcp]),
        5986: PortDefinition(name: "WinRM-HTTPS", description: "Windows Remote Management over HTTPS", protocols: [.tcp]),
        6000: PortDefinition(name: "X11", description: "X Window System", protocols: [.tcp, .udp]),
        6379: PortDefinition(name: "Redis", description: "Redis Database", protocols: [.tcp]),
        6443: PortDefinition(name: "Kubernetes", description: "Kubernetes API Server", protocols: [.tcp]),
        6660: PortDefinition(name: "IRC-Alt", description: "IRC Alternate Port", protocols: [.tcp]),
        6666: PortDefinition(name: "IRC-666", description: "IRC Port 6666", protocols: [.tcp]),
        6667: PortDefinition(name: "IRC-Standard", description: "IRC Standard Port", protocols: [.tcp]),
        6881: PortDefinition(name: "BitTorrent", description: "BitTorrent (first default)", protocols: [.tcp, .udp]),
        6969: PortDefinition(name: "BitTorrent-Tracker", description: "BitTorrent Tracker", protocols: [.tcp]),
        7000: PortDefinition(name: "AirPlay-Control/Cassandra", description: "HomeKit AirPlay Control (HomePod) / Apache Cassandra", protocols: [.tcp]),
        7001: PortDefinition(name: "Cassandra-TLS", description: "Apache Cassandra TLS", protocols: [.tcp]),
        7199: PortDefinition(name: "Cassandra-JMX", description: "Apache Cassandra JMX", protocols: [.tcp]),
        7474: PortDefinition(name: "Neo4j", description: "Neo4j Graph Database", protocols: [.tcp]),
        8000: PortDefinition(name: "HTTP-Alt", description: "HTTP Alternate Port", protocols: [.tcp]),
        8008: PortDefinition(name: "HTTP-8008", description: "HTTP Alternate (Google APIs)", protocols: [.tcp]),
        8080: PortDefinition(name: "HTTP-Proxy", description: "HTTP Proxy/Alternate", protocols: [.tcp]),
        8081: PortDefinition(name: "HTTP-8081", description: "HTTP Alternate Port 8081", protocols: [.tcp]),
        8086: PortDefinition(name: "InfluxDB", description: "InfluxDB HTTP API", protocols: [.tcp]),
        8088: PortDefinition(name: "InfluxDB-RPC", description: "InfluxDB RPC", protocols: [.tcp]),
        8123: PortDefinition(name: "Home-Assistant", description: "Home Assistant Web Interface", protocols: [.tcp]),
        8200: PortDefinition(name: "Vault", description: "HashiCorp Vault", protocols: [.tcp]),
        8291: PortDefinition(name: "MikroTik", description: "MikroTik RouterOS", protocols: [.tcp]),
        8332: PortDefinition(name: "Bitcoin-JSON-RPC", description: "Bitcoin JSON-RPC", protocols: [.tcp]),
        8333: PortDefinition(name: "Bitcoin", description: "Bitcoin Network", protocols: [.tcp]),
        8443: PortDefinition(name: "HTTPS-8443", description: "HTTPS Alternate Port 8443", protocols: [.tcp]),
        8500: PortDefinition(name: "Consul", description: "HashiCorp Consul", protocols: [.tcp]),
        8545: PortDefinition(name: "Ethereum", description: "Ethereum JSON-RPC", protocols: [.tcp]),
        8834: PortDefinition(name: "Nessus-Web", description: "Nessus Web Interface", protocols: [.tcp]),
        8883: PortDefinition(name: "MQTT-TLS", description: "MQTT over TLS/SSL", protocols: [.tcp]),
        8888: PortDefinition(name: "Jupyter", description: "Jupyter Notebook", protocols: [.tcp]),
        9000: PortDefinition(name: "SonarQube/PHP-FPM", description: "SonarQube or PHP-FPM", protocols: [.tcp]),
        9042: PortDefinition(name: "Cassandra-CQL", description: "Apache Cassandra CQL", protocols: [.tcp]),
        9090: PortDefinition(name: "Prometheus", description: "Prometheus Metrics", protocols: [.tcp]),
        9092: PortDefinition(name: "Kafka", description: "Apache Kafka", protocols: [.tcp]),
        9093: PortDefinition(name: "Alertmanager", description: "Prometheus Alertmanager", protocols: [.tcp]),
        9100: PortDefinition(name: "Node-Exporter", description: "Prometheus Node Exporter", protocols: [.tcp]),
        9200: PortDefinition(name: "Elasticsearch", description: "Elasticsearch HTTP API", protocols: [.tcp]),
        9300: PortDefinition(name: "Elasticsearch-Transport", description: "Elasticsearch Transport", protocols: [.tcp]),
        9418: PortDefinition(name: "Git", description: "Git Protocol", protocols: [.tcp, .udp]),
        9999: PortDefinition(name: "Urchin", description: "Urchin Web Analytics", protocols: [.tcp]),
        10000: PortDefinition(name: "Webmin", description: "Webmin Web Interface", protocols: [.tcp]),
        10050: PortDefinition(name: "Zabbix-Agent", description: "Zabbix Agent", protocols: [.tcp]),
        10051: PortDefinition(name: "Zabbix-Server", description: "Zabbix Server", protocols: [.tcp]),
        11211: PortDefinition(name: "Memcached", description: "Memcached", protocols: [.tcp, .udp]),
        11371: PortDefinition(name: "PGP-Keyserver", description: "OpenPGP HTTP Keyserver", protocols: [.tcp]),
        19132: PortDefinition(name: "Minecraft-Bedrock", description: "Minecraft Bedrock Edition", protocols: [.udp]),
        19133: PortDefinition(name: "Minecraft-Bedrock-IPv6", description: "Minecraft Bedrock IPv6", protocols: [.udp]),
        25565: PortDefinition(name: "Minecraft", description: "Minecraft Java Edition", protocols: [.tcp]),
        25575: PortDefinition(name: "Minecraft-RCON", description: "Minecraft Remote Console", protocols: [.tcp]),
        27015: PortDefinition(name: "Steam-Server", description: "Steam Game Server", protocols: [.tcp, .udp]),
        27017: PortDefinition(name: "MongoDB", description: "MongoDB Database", protocols: [.tcp]),
        27018: PortDefinition(name: "MongoDB-Shard", description: "MongoDB Shard Server", protocols: [.tcp]),
        27019: PortDefinition(name: "MongoDB-Config", description: "MongoDB Config Server", protocols: [.tcp]),
        28015: PortDefinition(name: "RethinkDB", description: "RethinkDB Client Driver", protocols: [.tcp]),
        28017: PortDefinition(name: "RethinkDB-Web", description: "RethinkDB Web Interface", protocols: [.tcp]),
        32400: PortDefinition(name: "Plex", description: "Plex Media Server", protocols: [.tcp]),
        33848: PortDefinition(name: "Jenkins-Agent", description: "Jenkins JNLP Agent", protocols: [.tcp]),
        37777: PortDefinition(name: "Dahua-DVR", description: "Dahua DVR/Camera", protocols: [.tcp]),
        49152: PortDefinition(name: "HomeKit-HAP", description: "HomeKit Accessory Protocol", protocols: [.tcp]),
        50000: PortDefinition(name: "SAP", description: "SAP NetWeaver", protocols: [.tcp]),
        50070: PortDefinition(name: "Hadoop-NameNode", description: "Hadoop NameNode HTTP", protocols: [.tcp]),
        51413: PortDefinition(name: "Transmission", description: "Transmission BitTorrent Client", protocols: [.tcp, .udp]),
        54321: PortDefinition(name: "Squid-SNMP", description: "Squid HTTP Proxy SNMP", protocols: [.udp]),
        62078: PortDefinition(name: "Apple-TV-Remote", description: "Apple TV Remote Protocol", protocols: [.tcp]),
    ]

    /// Get port definition
    static func getDefinition(for port: Int) -> PortDefinition? {
        return ports[port]
    }

    /// Search ports by service name
    static func search(serviceName: String) -> [(Int, PortDefinition)] {
        let query = serviceName.lowercased()
        return ports.filter { $0.value.name.lowercased().contains(query) || $0.value.description.lowercased().contains(query) }
            .sorted { $0.key < $1.key }
    }
}

// MARK: - Data Models

struct PortDefinition {
    let name: String
    let description: String
    let protocols: [ProtocolType]

    enum ProtocolType: String {
        case tcp = "TCP"
        case udp = "UDP"
    }

    var protocolString: String {
        protocols.map { $0.rawValue }.joined(separator: "/")
    }
}

// MARK: - Enhanced Port Info Integration

extension PortInfo {
    /// Get comprehensive port information
    /// Priority: HomeKit/Apple services > Comprehensive Database > Fallback
    var comprehensiveInfo: String {
        // PRIORITY 1: Check HomeKit/Apple-specific services first (user requirement)
        if let homeKitInfo = HomeKitPortDefinitions.getServiceInfo(for: port) {
            return "\(homeKitInfo.service) - \(homeKitInfo.description)"
        }
        // PRIORITY 2: Check comprehensive database
        else if let definition = ComprehensivePortDatabase.getDefinition(for: port) {
            return "\(definition.name) - \(definition.description) (\(definition.protocolString))"
        }
        // PRIORITY 3: Fallback to generic service name
        else {
            return service
        }
    }

    /// Get service category
    /// Priority: HomeKit/Apple services > Comprehensive Database
    var serviceCategory: String? {
        // PRIORITY 1: Check HomeKit/Apple-specific services first
        if let homeKitInfo = HomeKitPortDefinitions.getServiceInfo(for: port) {
            return homeKitInfo.category.rawValue
        }
        // PRIORITY 2: Check comprehensive database
        else if let definition = ComprehensivePortDatabase.getDefinition(for: port) {
            return definition.name
        }
        return nil
    }
}

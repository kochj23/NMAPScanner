# 🚨 NMAPScanner - Top Network Threat List

**Generated:** November 27, 2025, 9:24 PM
**Analysis Framework:** ThreatModel.swift
**Severity Classification:** Critical → High → Medium → Low → Info

---

## 🔴 CRITICAL THREATS (Severity 9.0-10.0)

### 1. **Known Backdoor Ports Detected** (CVSS 10.0)
**Category:** Backdoor/Remote Access
**Impact:** System Compromise

**Indicators:**
- Port 31337 (Back Orifice trojan)
- Port 12345, 12346 (NetBus trojan)
- Port 1243, 27374 (SubSeven trojan)
- Port 6667-6669 (IRC botnet C&C)
- Port 2001 (Trojan.Latinus)
- Port 1999 (BackDoor trojan)
- Port 30100-30102 (NetSphere trojan)
- Port 5000-5002 (Back Door Setup)

**Immediate Actions:**
1. **ISOLATE DEVICE FROM NETWORK IMMEDIATELY**
2. Run full malware/rootkit scan
3. Examine process list and network connections
4. Review system logs for suspicious activity
5. Check file integrity (AIDE, Tripwire)
6. Reimage system if compromised
7. Investigate source of infection
8. Update antivirus definitions
9. Scan adjacent devices for lateral movement

**Technical Details:**
These ports are **exclusively** associated with known malware and should NEVER be open on legitimate systems. Their presence indicates active compromise or testing of malicious software.

**Impact Assessment:**
- Attacker likely has full system control
- Risk of data exfiltration
- Potential for lateral movement to other devices
- Possibility of persistent backdoor installation
- Network may be part of botnet

---

### 2. **Telnet Service Enabled** (CVSS 9.0)
**Category:** Weak Security
**CVE References:** CVE-2020-15778, CVE-2019-19521

**Why Critical:**
- ALL data transmitted in **cleartext** (including passwords)
- No encryption, authentication, or integrity protection
- Vulnerable to packet sniffing and replay attacks
- Man-in-the-middle attacks trivial to execute
- Session hijacking possible

**Affected Services:**
- Port 23/TCP (Telnet)

**Remediation Priority: IMMEDIATE**
1. Disable Telnet service NOW
2. Replace with SSH (OpenSSH recommended)
3. If legacy devices require Telnet, use VPN tunnel
4. Implement network segmentation
5. Monitor logs for suspicious access attempts
6. Change ALL passwords that may have been transmitted via Telnet

**Impact Assessment:**
- **100% credential exposure** to network sniffers
- Complete lack of data confidentiality
- System compromise highly likely if attackers are present
- Regulatory compliance violations (PCI-DSS, HIPAA, etc.)

---

### 3. **Exposed Database Services** (CVSS 9.8)
**Category:** Data Exposure

**Affected Ports:**
- Port 3306 (MySQL)
- Port 5432 (PostgreSQL)
- Port 1433, 1434 (Microsoft SQL Server)
- Port 27017-27019 (MongoDB)
- Port 6379 (Redis)
- Port 9042 (Cassandra)
- Port 7000-7001 (Cassandra cluster)
- Port 8086 (InfluxDB)

**Why Critical:**
- Direct database access from network = **immediate data breach risk**
- Bypasses application security controls
- SQL injection vulnerabilities exploitable
- Default credentials often unchanged
- Many databases have RCE capabilities

**Immediate Actions:**
1. **BIND DATABASE TO 127.0.0.1 (localhost only)**
2. Configure firewall to block external database access
3. Place database behind application tier
4. Enable authentication (often disabled by default)
5. Enable SSL/TLS for database connections
6. Audit database users and privileges
7. Review connection logs for unauthorized access
8. Change default administrator passwords
9. Enable query logging and monitoring

**Impact Assessment:**
- Full database compromise possible
- Customer data breach risk
- Regulatory fines (GDPR: up to €20M or 4% revenue)
- Reputation damage
- Data destruction/ransomware risk

---

### 4. **Rogue Device Detected** (CVSS 9.0)
**Category:** Rogue Device

**Indicators:**
- Device not in authorized device inventory
- First seen within last hour
- Unknown MAC address
- No matching hostname patterns

**Why Critical:**
- Could be attacker-controlled device
- May be pivot point for lateral movement
- Possible evil twin access point
- Could be compromised IoT device
- Potential network tap or sniffer

**Investigation Steps:**
1. **Immediately document device details:**
   - IP address
   - MAC address (OUI lookup for manufacturer)
   - First seen timestamp
   - Network location (switch port, VLAN)
   - Traffic patterns

2. **Physical investigation:**
   - Locate device physically if possible
   - Check DHCP logs for hostname/vendor
   - Review switch MAC address table
   - Check wireless controller for rogue AP

3. **Network analysis:**
   - Monitor device traffic (packet capture)
   - Check for port scanning activity
   - Look for ARP spoofing
   - Analyze DNS queries
   - Check for unusual protocols

4. **Response actions:**
   - If unauthorized: isolate immediately via ACL
   - If legitimate: add to whitelist
   - Update network access control
   - Implement 802.1X if not already deployed

**Impact Assessment:**
- Potential unauthorized network access
- Data interception risk
- Lateral movement staging
- Compliance violations
- Network reconnaissance

---

## 🟠 HIGH THREATS (Severity 7.0-8.9)

### 5. **RDP Service Exposed to Network** (CVSS 8.0)
**Category:** Backdoor/Remote Access
**CVE References:** CVE-2019-0708 (BlueKeep), CVE-2020-0609, CVE-2020-0610

**Port:** 3389/TCP

**Why High Risk:**
- **BlueKeep** vulnerability allows pre-auth RCE
- Frequent target of ransomware campaigns
- Brute-force attacks extremely common
- Often exploited for initial access

**Known Attack Vectors:**
- BlueKeep (wormable, no auth required)
- Credential stuffing
- Brute-force attacks
- Session hijacking
- Pass-the-hash attacks

**Remediation:**
1. Place RDP behind VPN (highest priority)
2. Enable Network Level Authentication (NLA)
3. Use certificate-based authentication
4. Implement account lockout policies (5 failed attempts)
5. Change default port (security through obscurity - not primary defense)
6. Enable RDP Gateway if VPN not feasible
7. Restrict access by IP whitelist
8. Monitor failed login attempts
9. Apply latest security patches

**Impact Assessment:**
- Complete system compromise
- Ransomware deployment (RDP #1 infection vector)
- Credential theft
- Lateral movement platform
- Data exfiltration

---

### 6. **VNC Remote Desktop Exposed** (CVSS 8.0)
**Category:** Backdoor/Remote Access
**CVE References:** CVE-2020-14404, CVE-2019-15681

**Ports:** 5900-5910/TCP

**Why High Risk:**
- Weak encryption by default (DES - broken since 1997)
- Authentication bypass vulnerabilities common
- Passwords limited to 8 characters
- Many implementations transmit password in plaintext
- Frequently scanned by automated tools

**Remediation:**
1. **Place VNC behind SSH tunnel**
   ```bash
   ssh -L 5900:localhost:5900 user@remote-host
   ```
2. Use strong VNC password (even though limited)
3. Enable encryption if supported
4. Consider TightVNC or RealVNC with encryption
5. Better: Replace with RDP + NLA or SSH X11 forwarding
6. Whitelist source IPs
7. Disable if not actively used

**Impact Assessment:**
- Remote desktop access for attackers
- Screen capture/keylogging
- Complete system control
- Session hijacking
- Credential theft

---

### 7. **SMB File Sharing Exposed** (CVSS 7.5)
**Category:** Exposed Service
**CVE References:** CVE-2017-0144 (EternalBlue), CVE-2020-0796 (SMBGhost)

**Ports:** 445/TCP, 139/TCP

**Why High Risk:**
- **EternalBlue (MS17-010)**: Wormable RCE used by WannaCry, NotPetya
- **SMBGhost (CVE-2020-0796)**: Recent wormable RCE in SMBv3
- Credential relay attacks (SMB relay)
- Anonymous access often misconfigured
- Common vector for ransomware propagation

**Attack Scenarios:**
- WannaCry-style ransomware worm
- Lateral movement after initial compromise
- Credential harvesting
- File enumeration and theft
- Privilege escalation

**Remediation:**
1. **Disable SMBv1 IMMEDIATELY**
   ```powershell
   Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol
   ```
2. Apply MS17-010 patch (if not already applied)
3. Apply CVE-2020-0796 patch
4. Restrict SMB to specific subnets via firewall
5. Enable SMB signing (prevents relay attacks)
6. Disable guest access
7. Use strong authentication
8. Monitor SMB traffic for anomalies

**Impact Assessment:**
- Ransomware propagation (WannaCry precedent)
- Lateral movement across network
- Credential theft via NTLM relay
- Unauthorized file access
- Complete domain compromise possible

---

### 8. **FTP Service Detected** (CVSS 7.5)
**Category:** Weak Security
**CVE References:** CVE-2021-41773

**Port:** 21/TCP

**Why High Risk:**
- Credentials transmitted in cleartext
- Anonymous access often enabled
- Bounce attacks possible
- Directory traversal vulnerabilities common
- Lacks integrity protection

**Common Misconfigurations:**
- Anonymous FTP enabled (allows anyone to upload/download)
- Write permissions on anonymous directories
- Weak or default passwords
- No file upload restrictions
- Publicly writable directories

**Remediation:**
1. **Replace FTP with SFTP (SSH File Transfer Protocol)**
2. If FTP required, use FTPS (FTP over TLS)
3. Disable anonymous access
4. Use strong passwords (12+ characters)
5. Implement file upload restrictions
6. Enable logging and monitoring
7. Use chroot jails to restrict directory access
8. Consider SCP as alternative

**Impact Assessment:**
- Credential interception
- Unauthorized file access
- Data exfiltration
- Malware upload/distribution
- Potential for website defacement

---

### 9. **Multiple Remote Access Ports Open** (CVSS 7.5)
**Category:** Suspicious Activity

**Indicators:**
- 3+ remote access services on single device
- Common combinations:
  - SSH (22) + Telnet (23) + RDP (3389)
  - VNC (5900) + SSH (22) + RDP (3389)

**Why High Risk:**
- Unnecessarily large attack surface
- Indicates poor security hygiene
- Each service = additional vulnerability exposure
- Multiple authentication points to compromise
- Higher chance of misconfiguration

**Remediation:**
1. Disable all unnecessary remote access services
2. Standardize on ONE secure method (SSH recommended)
3. Use VPN for remote access (preferred approach)
4. Implement jump box/bastion host architecture
5. Enable 2FA/MFA for remote access
6. Monitor authentication logs

**Impact Assessment:**
- Multiple attack vectors for initial access
- Increased brute-force attack surface
- Higher maintenance burden (patching)
- Configuration drift risk

---

## 🟡 MEDIUM THREATS (Severity 5.0-6.9)

### 10. **HTTP Without HTTPS** (CVSS 5.3)
**Category:** Weak Security

**Indicators:**
- Port 80 open
- Port 443 not detected

**Why Medium Risk:**
- All web traffic sent in cleartext
- Session cookies can be stolen (session hijacking)
- Credentials submitted over HTTP are exposed
- Content can be modified in transit (MITM)
- SEO penalties from Google
- Browser "Not Secure" warnings

**Remediation:**
1. Obtain SSL/TLS certificate (Let's Encrypt = free)
2. Enable HTTPS on port 443
3. Redirect all HTTP to HTTPS (301 permanent redirect)
4. Implement HSTS (HTTP Strict Transport Security)
5. Use strong cipher suites (TLS 1.2+ only)
6. Consider HTTP/2 for performance
7. Disable HTTP port 80 if possible

**Impact Assessment:**
- Eavesdropping on sensitive data
- Session hijacking
- Cookie theft
- Man-in-the-middle attacks
- Phishing risk (fake sites easier to deploy)
- Compliance violations (PCI-DSS requires HTTPS)

---

## 📊 Threat Statistics

### By Severity:
- **Critical (9.0-10.0):** 4 threat types
- **High (7.0-8.9):** 5 threat types
- **Medium (5.0-6.9):** 1 threat type
- **Total Documented:** 10 threat categories

### By Category:
- **Backdoor/Remote Access:** 4 threats
- **Weak Security:** 4 threats
- **Data Exposure:** 1 threat
- **Exposed Service:** 1 threat
- **Rogue Device:** 1 threat
- **Suspicious Activity:** 1 threat

### Most Common Vulnerabilities:
1. Remote access services exposed (RDP, VNC, SSH, Telnet)
2. Unencrypted protocols (Telnet, FTP, HTTP)
3. Database exposure
4. SMB/CIFS file sharing

---

## 🛡️ Priority Action Matrix

### IMMEDIATE (Within 1 Hour):
1. Isolate devices with backdoor ports (CVSS 10.0)
2. Disable Telnet service (CVSS 9.0)
3. Bind databases to localhost (CVSS 9.8)
4. Investigate rogue devices (CVSS 9.0)

### URGENT (Within 24 Hours):
1. Place RDP behind VPN (CVSS 8.0)
2. Disable SMBv1, patch EternalBlue (CVSS 7.5)
3. Secure or replace FTP (CVSS 7.5)
4. Tunnel or disable VNC (CVSS 8.0)

### HIGH PRIORITY (Within 1 Week):
1. Enable HTTPS, disable HTTP (CVSS 5.3)
2. Disable unnecessary remote access services (CVSS 7.5)
3. Implement network segmentation
4. Deploy 802.1X network access control

---

## 🔍 Detection Methods

### Active Scanning:
- Port scanning (nmap, Nessus, OpenVAS)
- Service version detection
- Vulnerability scanning

### Passive Monitoring:
- Network traffic analysis (Wireshark, Zeek)
- Log aggregation (SIEM)
- Anomaly detection (IDS/IPS)

### Continuous Assessment:
- Scheduled vulnerability scans (weekly)
- Configuration audits (monthly)
- Penetration testing (quarterly)
- Threat intelligence feeds

---

## 📋 Compliance Impact

### Affected Standards:
- **PCI-DSS:**
  - Requirement 1 (Firewall configuration)
  - Requirement 2 (Secure configurations)
  - Requirement 4 (Encrypt transmission)
  - Requirement 10 (Track and monitor)

- **HIPAA:**
  - Access Control (§164.312(a)(1))
  - Transmission Security (§164.312(e)(1))
  - Audit Controls (§164.312(b))

- **NIST Cybersecurity Framework:**
  - PR.AC (Access Control)
  - PR.DS (Data Security)
  - DE.CM (Continuous Monitoring)

- **GDPR:**
  - Article 5 (Security of processing)
  - Article 32 (Security of processing)
  - Article 33 (Breach notification)

### Potential Penalties:
- **PCI-DSS:** Loss of ability to process credit cards
- **HIPAA:** Up to $1.5M per violation category per year
- **GDPR:** Up to €20M or 4% of global revenue

---

## 🎯 Mitigation Best Practices

### Network Level:
1. **Segmentation:** Separate critical systems from general network
2. **Firewalls:** Default deny, explicit allow rules
3. **VPNs:** All remote access via VPN
4. **NAC:** 802.1X for network access control
5. **IDS/IPS:** Deploy at network perimeter and critical segments

### Host Level:
1. **Patching:** Automated patch management
2. **Hardening:** CIS benchmarks, STIGs
3. **EDR:** Endpoint detection and response
4. **Application Whitelisting:** Only approved software
5. **Encryption:** Full disk encryption

### Application Level:
1. **SSL/TLS:** All services use encryption
2. **Authentication:** MFA for all admin access
3. **Authorization:** Principle of least privilege
4. **Logging:** Comprehensive audit trails
5. **Input Validation:** Prevent injection attacks

### Organizational:
1. **Security Training:** Quarterly awareness training
2. **Incident Response:** Documented IR plan
3. **Asset Inventory:** Maintain current inventory
4. **Risk Assessment:** Annual risk assessments
5. **Third-party Audits:** External security audits

---

## 📞 Emergency Response

### If Backdoor Detected:
1. **DO NOT SHUT DOWN** device (may trigger anti-forensics)
2. Isolate network connection (pull cable or ACL)
3. Document current state (memory dump, process list)
4. Engage incident response team
5. Preserve evidence for forensics
6. Follow incident response plan

### Contact Information:
- **IT Security Team:** [Your security team contact]
- **Incident Response:** [IR team/vendor contact]
- **Management Escalation:** [Management contact]

---

## 🔄 Continuous Improvement

### Regular Activities:
- **Daily:** Review security alerts, check IDS/IPS logs
- **Weekly:** Vulnerability scans, patch deployment
- **Monthly:** Review access controls, audit logs
- **Quarterly:** Penetration testing, security training
- **Annually:** Risk assessment, policy review

### Metrics to Track:
- Mean Time to Detect (MTTD)
- Mean Time to Respond (MTTR)
- Number of critical vulnerabilities
- Patch compliance percentage
- Security incident trends

---

**Document Version:** 1.0
**Last Updated:** November 27, 2025
**Next Review:** December 27, 2025
**Owner:** Jordan Koch & Claude Code
**Classification:** Internal Use / Security Sensitive

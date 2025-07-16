// ------------------------------------------------------------[ Cleanup                     ]------------------------------------------------------------
MATCH (n)
DETACH DELETE n;

// ------------------------------------------------------------[ Business/network structure  ]------------------------------------------------------------

// =====  ===== Main companies ===== =====
MERGE (buHEADQUARTERS:BusinessUnit {category: "Business", name: "HEADQUARTERS"})
MERGE
  (buENTREPRISE1:BusinessUnit
    {category: "Business", name: "ENTREPRISE1", external: false})
MERGE
  (buENTREPRISE2:BusinessUnit
    {category: "Business", name: "ENTREPRISE2", external: true})
MERGE (buHEADQUARTERS)-[:MANAGES]->(buENTREPRISE1)

// ===== Sites =====
MERGE
  (siteENTREPRISE1:Site {category: "Business", name: "ENTREPRISE1 Tombouctou"})
MERGE
  (siteENTREPRISE2:Site {category: "Business", name: "ENTREPRISE2 Tombouctou"})
MERGE (buENTREPRISE1)-[:MANAGES]->(siteENTREPRISE1)
MERGE (buENTREPRISE2)-[:MANAGES]->(siteENTREPRISE2)

// ===== WAN =====
MERGE (wan:WAN {category: "Asset", name: "HEADQUARTERS WAN"})
MERGE (wan)<-[:MANAGES]-(buHEADQUARTERS)

// ===== VLANs for site of ENTERPRISE1 =====
MERGE
  (ent1Subnet:VLAN {category: "Asset", name: "ENTERPRISE1 Tombouctou subnet"})
MERGE (ent1Subnet)<-[:MANAGES]-(siteENTREPRISE1)
MERGE
  (vlanUser:VLAN
    {category: "Asset", name: "User VLAN", ip_range: "10.1.120.0/24"})
MERGE
  (vlanPrinter:VLAN
    {category: "Asset", name: "Print VLAN", ip_range: "10.1.122.32/28"})
MERGE
  (vlanGuest:VLAN
    {
      category: "Asset",
      name: "Corporate Wi-Fi Guest",
      ip_range: "10.0.150.0/23"
    })

// ===== Link VLANs to Sites =====
MERGE (ent1Subnet)-[:HAS_VLAN]->(vlanUser)
MERGE (ent1Subnet)-[:HAS_VLAN]->(vlanPrinter)
MERGE (ent1Subnet)-[:HAS_VLAN]->(vlanGuest)
MERGE (wan)-[:HAS_VLAN]->(vlanUser)
MERGE (wan)-[:HAS_VLAN]->(vlanDC)

// ===== VLAN interactions ====
MERGE (vlanUser)-[:CAN_REACH]->(vlanPrinter)
MERGE (vlanUser)-[:CAN_REACH]->(wan)
MERGE (vlanPrinter)-[:CAN_REACH]->(wan)
MERGE (wan)-[:CAN_REACH]->(ent1Subnet)

// ===== VLANs for site of ENTERPRISE2 =====
MERGE (ent2VLAN:VLAN {category: "Asset", name: "ENTERPRISE2 Tombouctou subnet"})
MERGE (ent2VLAN)<-[:MANAGES]-(siteENTREPRISE2)
MERGE (vlan:VLAN {category: "Asset", name: "Unknown VLAN", ip_range: "TODO"})
MERGE (ent2VLAN)-[:HAS_VLAN]->(vlan)
FINISH;

// ------------------------------------------------------------[ Domain structure          ]------------------------------------------------------------
UNWIND [
  {name: "HEADQUARTERS.COM", parent: null},
  {name: "MAIN.HEADQUARTERS.COM", parent: "HEADQUARTERS.COM"},
  {name: "TECH.HEADQUARTERS.COM", parent: "HEADQUARTERS.COM"},
  {name: "PROD.HEADQUARTERS.COM", parent: "HEADQUARTERS.COM"},
  {name: "MASTER.HEADQUARTERS.COM", parent: "HEADQUARTERS.COM"},
  {name: "DOMAIN.LOCAL", parent: null}
] AS domainData

// ===== MERGE domains and optionally link to parent =====
CALL (domainData) {
  MERGE (child:Domain {category: "Asset", name: domainData.name})
  // ===== Handle parent domain if it exists =====
  WITH domainData, child
  WHERE domainData.parent IS NOT NULL
  MERGE (parent:Domain {name: domainData.parent})
  MERGE (parent)-[:HAS_DOMAIN]->(child)
}
FINISH;

// ------------------------------------------------------------[ Domain Assets & trophies  ]------------------------------------------------------------
UNWIND [
  {name: "MAIN.HEADQUARTERS.COM"},
  {name: "TECH.HEADQUARTERS.COM"},
  {name: "PROD.HEADQUARTERS.COM"},
  {name: "MASTER.HEADQUARTERS.COM"},
  {name: "DOMAIN.LOCAL"}
] AS domainData

MATCH (wan:WAN {name: "HEADQUARTERS WAN"})
// ===== Base trophies =====
CALL (domainData, wan) {
  MERGE
    (authAccess:Trophy
      {
        category: "Attack",
        type: "AuthenticatedAccess",
        name: "Authenticated access to " + domainData.name
      })
  MERGE
    (adminAccess:Trophy
      {
        category: "Attack",
        type: "AdminAccess",
        name: "Domain admin access to " + domainData.name
      })
  MERGE (domain:Domain {name: domainData.name})
  MERGE (authAccess)-[:IS_TROPHY]->(domain)
  MERGE (adminAccess)-[:IS_TROPHY]->(domain)
  MERGE (adminAccess)-[:IMPLIES]->(authAccess)
  RETURN count(*) AS _
}

// ===== SMB servers =====
CALL (domainData) {
  MERGE
    (srv:Server
      {category: "Asset", name: domainData.name + " SMB Servers", ip: "TODO"})
  MERGE
    (smb:Service
      {category: "Asset", name: domainData.name + " SMB Service", port: 445})
  WITH srv, smb
  MATCH (domain:Domain {name: domainData.name})
  MERGE (srv)<-[:HAS_MACHINE]-(domain)
  MERGE (srv)-[:EXPOSES_SERVICE]->(smb)
  RETURN count(*) AS _2
}

// ===== DC =====
CALL (domainData) {
  MERGE
    (srv:Server
      {
        category: "Asset",
        name: domainData.name + " Domain Controller",
        ip: "TODO"
      })
  WITH srv
  MATCH (domain:Domain {name: domainData.name})
  MERGE (srv)<-[:HAS_MACHINE]-(domain)
  MERGE (srv)<-[:HAS_DC]-(domain)
  RETURN count(*) AS _3
}

FINISH;

// ------------------------------------------------------------[ LOCAL Assets & trophies   ]------------------------------------------------------------

// ===== VNC Server =====
MERGE
  (srv:Server
    {category: "Asset", name: "ENTREPRISE1 Tombouctou printer", ip: "TODO"})
MERGE
  (vnc:Service {category: "Asset", name: "ENTREPRISE1 Printer VNC", port: 5900})
WITH srv, vnc
MATCH (printVLAN:VLAN {category: "Asset", name: "Print VLAN40"})
MERGE (srv)<-[:HAS_MACHINE]-(printVLAN)
MERGE (srv)-[:EXPOSES_SERVICE]->(vnc)
MERGE
  (vncTrophy:Trophy
    {
      category: "Attack",
      type: "AuthenticatedAccess",
      name: "VNC access to srv-ops"
    })
MERGE (vncTrophy)-[:IS_TROPHY]->(vnc)
FINISH;

// ===== SMTP server =====
MERGE
  (srv:Server
    {category: "Asset", name: "MAIN.HEADQUARTERS.COM SMTP Servers", ip: "TODO"})
MERGE
  (smtp:Service
    {category: "Asset", name: "MAIN.HEADQUARTERS.COM SMTP Service", port: 587})
WITH srv, smtp
MATCH (CORP:Domain {category: "Asset", name: "MAIN.HEADQUARTERS.COM"})
MERGE (srv)<-[:HAS_MACHINE]-(CORP)
MERGE (srv)-[:EXPOSES_SERVICE]->(smtp)
MERGE
  (smtpTrophy:Trophy
    {
      category: "Attack",
      type: "AuthenticatedAccess",
      name: "SMTP Open Relay capabilities"
    })
MERGE (smtpTrophy)-[:IS_TROPHY]->(smtp)
FINISH;

// ===== JEAN.MICHEL =====
MERGE
  (acc:Account {category: "Asset", name: "MAIN.HEADQUARTERS.COM\\JEAN.MICHEL"})
MERGE (d:Domain {category: "Asset", name: "MAIN.HEADQUARTERS.COM"})
MERGE (d)-[:HAS_ACCOUNT]->(acc)
FINISH;

// ------------------------------------------------------------[ Other trophies            ]------------------------------------------------------------

// ===== Global HEADQUARTERS compromise =====
MATCH (bu:BusinessUnit {category: "Business", name: "HEADQUARTERS"})
MERGE
  (trophy:Trophy
    {
      category: "Attack",
      name: "Global compromise of HEADQUARTERS PKI",
      type: "AdminAccess"
    })
MERGE (trophy)-[:IS_TROPHY]->(bu)
FINISH;

// ===== Network access to ENTERPRISE2 network =====
MERGE (vlan:VLAN {name: "Unknown VLAN"})
MERGE
  (trophy:Trophy
    {
      category: "Attack",
      name: "Network access to ENTERPRISE2 network",
      type: "NetworkAccess"
    })
MERGE (trophy)-[:IS_TROPHY]->(vlan)
FINISH;

// ------------------------------------------------------------[ Identified entrypoints   ]------------------------------------------------------------

// ===== Physical access to ENTERPRISE1 =====
// Rationale: Physical intrusion
MATCH (wifi:VLAN {name: "Corporate Wi-Fi Guest"})
MERGE
  (physicalENTREPRISE1:Entry
    {category: "Attack", type: "Physical", name: "Physical ENTREPRISE1 access"})
MERGE (physicalENTREPRISE1)-[:GRANTS]->(wifi)
FINISH;

// ===== Network access to WAN =====
// Rationale: Opened session, Phishing
MATCH (wan:WAN {name: "HEADQUARTERS WAN"})
MERGE
  (networkWAN:Entry
    {category: "Attack", type: "Network", name: "HEADQUARTERS WAN access"})
MERGE (networkWAN)-[:GRANTS]->(wan)
FINISH;

// ------------------------------------------------------------[ Vulnerabilities          ]------------------------------------------------------------

UNWIND [
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: null,
    fromNode: "Physical ENTREPRISE1 access",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: null,
    fromNode: "MAC Addr postits",
    toNode: "HEADQUARTERS WAN"
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: null,
    fromNode: "Physical ENTREPRISE1 access",
    toNode: "Authenticated access to MAIN.HEADQUARTERS.COM"
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: null,
    fromNode: "ENTERPRISE1 Tombouctou subnet",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: null,
    fromNode: "ENTERPRISE1 Tombouctou subnet",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "ENTREPRISE1 Printer VNC",
    fromNode: "Default credentials or unauthenticated services",
    toNode: "VNC access to srv-ops"
  },
  {
    id: "VLN.XX",
    vulnerableAsset: "MAIN.HEADQUARTERS.COM SMB Service",
    name: "REDACTED",,
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MAIN.HEADQUARTERS.COM SMB Service",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MAIN.HEADQUARTERS.COM SMB Service",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MAIN.HEADQUARTERS.COM SMTP Service",
    fromNode: "Default credentials or unauthenticated services",
    toNode: "SMTP Open Relay capabilities"
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MAIN.HEADQUARTERS.COM\JEAN.MICHEL",
    fromNode: "Authenticated access to MAIN.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MAIN.HEADQUARTERS.COM",
    fromNode: "Authenticated access to MAIN.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MAIN.HEADQUARTERS.COM SMB Service",
    fromNode: "Authenticated access to MAIN.HEADQUARTERS.COM",
    toNode: "Global compromise of HEADQUARTERS PKI"
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MAIN.HEADQUARTERS.COM",
    fromNode: "Authenticated access to TECH.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "TECH.HEADQUARTERS.COM",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "TECH.HEADQUARTERS.COM",
    fromNode: "Authenticated access to TECH.HEADQUARTERS.COM",
    toNode: "Domain admin access to TECH.HEADQUARTERS.COM"
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "PROD.HEADQUARTERS.COM SMB Service",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "PROD.HEADQUARTERS.COM SMB Service",
    fromNode: "Guest access enabled on PROD.HEADQUARTERS.COM SMB",
    toNode: "Authenticated access to PROD.HEADQUARTERS.COM"
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "PROD.HEADQUARTERS.COM",
    fromNode: "Authenticated access to PROD.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "PROD.HEADQUARTERS.COM",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "PROD.HEADQUARTERS.COM", // TODO account
    fromNode: "Authenticated access to PROD.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "PROD.HEADQUARTERS.COM",
    fromNode: "Weak password policy on PROD.HEADQUARTERS.COM",
    toNode: "Authenticated access to PROD.HEADQUARTERS.COM"
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "PROD.HEADQUARTERS.COM", // TODO server
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "PROD.HEADQUARTERS.COM", // TODO account
    fromNode: "Authenticated access to PROD.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "PROD.HEADQUARTERS.COM", // TODO account
    fromNode: "Weak password policy on PROD.HEADQUARTERS.COM",
    toNode: "Domain admin access to PROD.HEADQUARTERS.COM"
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "PROD.HEADQUARTERS.COM", // TODO account
    fromNode: "Weak or default credentials spraying on PROD.HEADQUARTERS.COM",
    toNode: "Authenticated access to PROD.HEADQUARTERS.COM"
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "PROD.HEADQUARTERS.COM Domain Controller",
    fromNode: "Authenticated access to PROD.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "PROD.HEADQUARTERS.COM SMB Service",
    fromNode: "Guest access enabled on PROD.HEADQUARTERS.COM SMB Service",
    toNode: "Authenticated access to PROD.HEADQUARTERS.COM"
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "PROD.HEADQUARTERS.COM SMB Service",
    fromNode: "Authenticated access to PROD.HEADQUARTERS.COM",
    toNode: "Domain admin access to PROD.HEADQUARTERS.COM"
  },
  // MASTER.HEADQUARTERS.VLAN
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MASTER.HEADQUARTERS.COM",
    fromNode: "Authenticated access to MASTER.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MASTER.HEADQUARTERS.COM",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MASTER.HEADQUARTERS.COM SMB Service",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MASTER.HEADQUARTERS.COM", // TODO account
    fromNode: "Weak password policy on MASTER.HEADQUARTERS.COM",
    toNode: "Domain admin access to MASTER.HEADQUARTERS.COM"
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MASTER.HEADQUARTERS.COM", // TODO account
    fromNode: "Authenticated access to MASTER.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MASTER.HEADQUARTERS.COM", // TODO account
    fromNode: "Kerberoastable account on MASTER.HEADQUARTERS.COM",
    toNode: "Domain admin access to MASTER.HEADQUARTERS.COM"
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MASTER.HEADQUARTERS.COM SMB Service",
    fromNode: "Guest access enabled on MASTER.HEADQUARTERS.COM SMB Service",
    toNode: "Authenticated access to MASTER.HEADQUARTERS.COM"
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "MASTER.HEADQUARTERS.COM SMB Service",
    fromNode: "Authenticated access to MASTER.HEADQUARTERS.COM",
    toNode: "Domain admin access to MASTER.HEADQUARTERS.COM"
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "WERID.LOCAL SMB Service",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.XX",
    name: "REDACTED",,
    vulnerableAsset: "ENTREPRISE1 Tombouctou",
    fromNode: "Physical ENTREPRISE1 access",
    toNode: "Network access to ENTERPRISE2 network"
  }
] AS vulnData

CALL (vulnData) {
  CREATE
    (vuln:Vulnerability
      {category: "Attack", vuln_id: vulnData.id, name: vulnData.name})

  WITH vuln, vulnData
  CALL (vulnData, vuln) {
    WITH vuln, vulnData
    WHERE vulnData.vulnerableAsset IS NOT NULL
    MATCH (vulnerableAsset {name: vulnData.vulnerableAsset})
    MERGE (vuln)-[:IS_VULN]->(vulnerableAsset)
    RETURN count(*) AS _
  }

  WITH vuln, vulnData
  CALL (vulnData, vuln) {
    WITH vuln, vulnData
    WHERE vulnData.fromNode IS NOT NULL
    MATCH (fromNode {name: vulnData.fromNode})
    MERGE (fromNode)-[:CAN_LEVERAGE]->(vuln)
    RETURN count(*) AS _
  }

  WITH vuln, vulnData
  CALL (vulnData, vuln) {
    WITH vuln, vulnData
    WHERE vulnData.toNode IS NOT NULL
    MATCH (toNode {name: vulnData.toNode})
    MERGE (vuln)-[:GRANTS]->(toNode)
    RETURN count(*) AS _
  }
  RETURN count(*) AS _

}
RETURN count(*) AS _

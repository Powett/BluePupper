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
  (printer:Server
    {category: "Asset", name: "ENTREPRISE1 Tombouctou printer", ip: "TODO"})
MERGE
  (vnc:Service {category: "Asset", name: "ENTREPRISE1 Printer VNC Service", port: 5900})
WITH printer, vnc
MATCH (printVLAN:VLAN {category: "Asset", name: "Print VLAN"})
MERGE (printer)<-[:HAS_MACHINE]-(printVLAN)
MERGE (printer)-[:EXPOSES_SERVICE]->(vnc)
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
    id: "VLN.00",
    name: "Vulnerability number 00",
    vulnerableAsset: null,
    fromNode: "Physical ENTREPRISE1 access",
    toNode: null
  },
  {
    id: "VLN.01",
    name: "Vulnerability number 01",
    vulnerableAsset: null,
    fromNode: "Vulnerability number 00",
    toNode: "HEADQUARTERS WAN"
  },
  {
    id: "VLN.02",
    name: "Vulnerability number 02",
    vulnerableAsset: null,
    fromNode: "Physical ENTREPRISE1 access",
    toNode: "Authenticated access to MAIN.HEADQUARTERS.COM"
  },
  {
    id: "VLN.03",
    name: "Vulnerability number 03",
    vulnerableAsset: null,
    fromNode: "ENTERPRISE1 Tombouctou subnet",
    toNode: null
  },
  {
    id: "VLN.04",
    name: "Vulnerability number 04",
    vulnerableAsset: null,
    fromNode: "ENTERPRISE1 Tombouctou subnet",
    toNode: null
  },
  {
    id: "VLN.05",
    name: "Vulnerability number 05",
    vulnerableAsset: "ENTREPRISE1 Printer VNC Service",
    fromNode: "Vulnerability number 03",
    toNode: "VNC access to srv-ops"
  },
  {
    id: "VLN.06",
    name: "Vulnerability number 06",
    vulnerableAsset: "MAIN.HEADQUARTERS.COM SMB Service",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.07",
    name: "Vulnerability number 07",
    vulnerableAsset: "MAIN.HEADQUARTERS.COM SMB Service",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.08",
    name: "Vulnerability number 08",
    vulnerableAsset: "MAIN.HEADQUARTERS.COM SMB Service",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.09",
    name: "Vulnerability number 09",
    vulnerableAsset: "MAIN.HEADQUARTERS.COM SMTP Service",
    fromNode: "Vulnerability number 03",
    toNode: "SMTP Open Relay capabilities"
  },
  {
    id: "VLN.10",
    name: "Vulnerability number 10",
    vulnerableAsset: "MAIN.HEADQUARTERS.COM\JEAN.MICHEL",
    fromNode: "Authenticated access to MAIN.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.11",
    name: "Vulnerability number 11",
    vulnerableAsset: "MAIN.HEADQUARTERS.COM",
    fromNode: "Authenticated access to MAIN.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.12",
    name: "Vulnerability number 12",
    vulnerableAsset: "MAIN.HEADQUARTERS.COM SMB Service",
    fromNode: "Authenticated access to MAIN.HEADQUARTERS.COM",
    toNode: "Global compromise of HEADQUARTERS PKI"
  },
  {
    id: "VLN.13",
    name: "Vulnerability number 13",
    vulnerableAsset: "MAIN.HEADQUARTERS.COM",
    fromNode: "Authenticated access to TECH.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.14",
    name: "Vulnerability number 14",
    vulnerableAsset: "TECH.HEADQUARTERS.COM",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.15",
    name: "Vulnerability number 15",
    vulnerableAsset: "TECH.HEADQUARTERS.COM",
    fromNode: "Authenticated access to TECH.HEADQUARTERS.COM",
    toNode: "Domain admin access to TECH.HEADQUARTERS.COM"
  },
  {
    id: "VLN.16",
    name: "Vulnerability number 16",
    vulnerableAsset: "PROD.HEADQUARTERS.COM SMB Service",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.17",
    name: "Vulnerability number 17",
    vulnerableAsset: "PROD.HEADQUARTERS.COM SMB Service",
    fromNode: "Vulnerability number 16",
    toNode: "Authenticated access to PROD.HEADQUARTERS.COM"
  },
  {
    id: "VLN.18",
    name: "Vulnerability number 18",
    vulnerableAsset: "PROD.HEADQUARTERS.COM",
    fromNode: "Authenticated access to PROD.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.19",
    name: "Vulnerability number 19",
    vulnerableAsset: "PROD.HEADQUARTERS.COM",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.20",
    name: "Vulnerability number 20",
    vulnerableAsset: "PROD.HEADQUARTERS.COM", // TODO account
    fromNode: "Authenticated access to PROD.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.21",
    name: "Vulnerability number 21",
    vulnerableAsset: "PROD.HEADQUARTERS.COM",
    fromNode: "Vulnerability number 19",
    toNode: "Authenticated access to PROD.HEADQUARTERS.COM"
  },
  {
    id: "VLN.22",
    name: "Vulnerability number 22",
    vulnerableAsset: "PROD.HEADQUARTERS.COM", // TODO server
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.23",
    name: "Vulnerability number 23",
    vulnerableAsset: "PROD.HEADQUARTERS.COM", // TODO account
    fromNode: "Authenticated access to PROD.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.24",
    name: "Vulnerability number 24",
    vulnerableAsset: "PROD.HEADQUARTERS.COM", // TODO account
    fromNode: "Vulnerability number 19",
    toNode: "Domain admin access to PROD.HEADQUARTERS.COM"
  },
  {
    id: "VLN.25",
    name: "Vulnerability number 25",
    vulnerableAsset: "PROD.HEADQUARTERS.COM", // TODO account
    fromNode: "Vulnerability number 21",
    toNode: "Authenticated access to PROD.HEADQUARTERS.COM"
  },
  {
    id: "VLN.26",
    name: "Vulnerability number 26",
    vulnerableAsset: "PROD.HEADQUARTERS.COM Domain Controller",
    fromNode: "Authenticated access to PROD.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.28",
    name: "Vulnerability number 28",
    vulnerableAsset: "PROD.HEADQUARTERS.COM SMB Service",
    fromNode: "Authenticated access to PROD.HEADQUARTERS.COM",
    toNode: "Domain admin access to PROD.HEADQUARTERS.COM"
  },
  {
    id: "VLN.29",
    name: "Vulnerability number 29",
    vulnerableAsset: "MASTER.HEADQUARTERS.COM",
    fromNode: "Authenticated access to MASTER.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.30",
    name: "Vulnerability number 30",
    vulnerableAsset: "MASTER.HEADQUARTERS.COM",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.31",
    name: "Vulnerability number 31",
    vulnerableAsset: "MASTER.HEADQUARTERS.COM SMB Service",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.32",
    name: "Vulnerability number 32",
    vulnerableAsset: "MASTER.HEADQUARTERS.COM", // TODO account
    fromNode: "Vulnerability number 30",
    toNode: "Domain admin access to MASTER.HEADQUARTERS.COM"
  },
  {
    id: "VLN.33",
    name: "Vulnerability number 33",
    vulnerableAsset: "MASTER.HEADQUARTERS.COM", // TODO account
    fromNode: "Authenticated access to MASTER.HEADQUARTERS.COM",
    toNode: null
  },
  {
    id: "VLN.34",
    name: "Vulnerability number 34",
    vulnerableAsset: "MASTER.HEADQUARTERS.COM", // TODO account
    fromNode: "Vulnerability number 33",
    toNode: "Domain admin access to MASTER.HEADQUARTERS.COM"
  },
  {
    id: "VLN.35",
    name: "Vulnerability number 35",
    vulnerableAsset: "MASTER.HEADQUARTERS.COM SMB Service",
    fromNode: "Vulnerability number 31",
    toNode: "Authenticated access to MASTER.HEADQUARTERS.COM"
  },
  {
    id: "VLN.36",
    name: "Vulnerability number 36",
    vulnerableAsset: "MASTER.HEADQUARTERS.COM SMB Service",
    fromNode: "Authenticated access to MASTER.HEADQUARTERS.COM",
    toNode: "Domain admin access to MASTER.HEADQUARTERS.COM"
  },
  {
    id: "VLN.37",
    name: "Vulnerability number 37",
    vulnerableAsset: "WERID.LOCAL SMB Service",
    fromNode: "HEADQUARTERS WAN",
    toNode: null
  },
  {
    id: "VLN.38",
    name: "Vulnerability number 38",
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
This document describes the suggested schema to describe all relevant objects.
# Versioning

| Version | Edits | Ownership     |
| ------- | ----- | ------------- |
| v1.0    | -     | Nathan PELUSO |
|         |       |               |

# High-Level description
This section describes the identified categories, the objects contained, their properties and possible relationships.
## Summary
| Node Type         | Properties         | Relationships                                          |
| ----------------- | ------------------ | ------------------------------------------------------ |
| **BusinessUnit**  | `name`, `external` | `MANAGES`                                              |
| **Site**          | `name`             | `MANAGES`                                              |
| **WAN**           | `name`, `ip_range` | `HAS_VLAN`, `CAN_REACH`, `CAN_LEVERAGE`                |
| **VLAN**          | `name`, `ip_range` | `HAS_VLAN`, `HAS_MACHINE`, `CAN_REACH`, `CAN_LEVERAGE` |
| **Server**        | `name`, `ip`       | `EXPOSES_SERVICE`                                      |
| **Service**       | `name`, `port`     | `HAS_ACCOUNT`                                          |
| **Domain**        | `name`             | `HAS_MACHINE`, `HAS_ACCOUNT`, `HAS_DOMAIN`, `HAS_DC`   |
| **Account**       | `name`             | _None_                                                 |
| **Entry**         | `name`, `type`     | `CAN_LEVERAGE`, `GRANTS`                               |
| **Vulnerability** | `name`, `vuln_id`  | `IS_VULN`, `GRANTS`, `CAN_LEVERAGE`                    |
| **Trophy**        | `name`, `type`     | `IS_TROPHY`, `CAN_LEVERAGE`, `IMPLIES`                 |
## Business hierarchy
`category: Business`

- `BusinessUnit`
	- Describes a company or any scale of business unit. Can be recursively defined.
	- Properties
		- `name`
		- `external`: Tag non-owned companies or units
	- Relationships
		- `MANAGES` -> `{category: Business | Asset}`
- `Site`
	- Describes a physical or logical site within a business unit. Avoid recursive definition.
	- Properties
		- `name`
	- Relationships
		- `MANAGES` -> `{category: Business | Asset}`
## Asset hierarchy
`category: Asset`

- `WAN`
	- Describes a company WAN. Access Control details (VLAN segmentation, firewalls, etc) are abstracted at this level, and to be specified if strictly necessary at lower levels. If has attached `Vulnerability`, make sure the `Vulnerability` cannot be attached in a more precise way. If has attached `Server`, make sure the `Server` cannot be attached in a more precise way.
	- Properties
		- `name`
	- Relationships
		- `CAN_REACH` -> `VLAN | WAN`
		- `HAS_VLAN` -> `VLAN`
		- `CAN_LEVERAGE` -> `Vulnerability`
		- `HAS_MACHINE` -> `Server`
- `VLAN`
	- Describes a VLAN. Try to only describe VLANs necessary to attack paths or global comprehension. Feel free to generalize as a first approach, then iteratively add details when necessary. Can be recursively defined. If has attached `Vulnerability`, make sure the `Vulnerability` cannot be attached in a more generic way. If has attached `Server`, make sure the `Server` cannot be attached in a more precise way.
	- Properties
		- `name`
		- `ip_range`
	- Relationships
		- `CAN_REACH` -> `VLAN | WAN`
		- `HAS_VLAN` -> `VLAN`
		- `CAN_LEVERAGE` -> `Vulnerability`
		- `HAS_MACHINE` -> `Server`
- `Server`
	- Describes a server, (or set of servers with similar configuration, role or vulnerability). Feel free to generalize as a first approach, then iteratively add details when necessary. E.g. if several servers expose SMBv1, you can create a generic "SMB Server" object as a first approximation. Owned by a `VLAN`, `WAN` or `Domain` (if domain-joined).
	- Properties
		- `name`
		- `ip` [optional]
	- Relationships
		- `EXPOSES_SERVICE` -> `Service`
- `Service`
	- Describes a service exposed by one or more servers. Add details only when necessary. If an `Account` is attached, make sure `Service` does not rely on domain authentication.
	- Properties
		- `name`
		- `port`
	- Relationships
		- `HAS_ACCOUNT`
- `Domain`
	- Describes an Active Directory domain. Can be recursively defined.
	- Properties
		- `name`
	- Relationships
		- `HAS_DOMAIN` -> `Domain`
		- `HAS_MACHINE` -> `Server`
		- `HAS_DC` -> `Server` (can be parallel with `HAS_MACHINE`)
		- `HAS_ACCOUNT` -> `Account`
- `Account`
	- Describes an account, for a specific domain or service.
	- Properties
		- `name`
## Attack hierarchy
`category: Attack`
- `Entry`
	- Describes an identified major entry point. Can be physical, network, or other type. `GRANT`s access to assets, and `CAN_LEVERAGE`  `Vulnerability`s.
	- Properties
		- `name`
		- `type`: `Network | Physical` as of latest version
	- Relationships
		- `CAN_LEVERAGE` -> `Vulnerability`
		- `GRANTS` -> `{category: Asset}`
- `Trophy`
	- Describes an achievement that can be obtained by attackers, often a certain level of access to an asset. To be defined more precisely depending on context. To be kept to a minimum for readability purposes. Can imply (`IMPLIES`) other contained trophies. `CAN_LEVERAGE` vulnerabilities (a default trophy for access to any asset was pruned for readability purposes). `IS_TROPHY` of a specific asset, to be defined as precisely as possible.
	- Properties
		- `name`
		- `type`: `NetworkAccess | AuthenticatedAccess | AdminAccess` as of latest version
	- Relationships
		- `IMPLIES` -> `Trophy`
		- `CAN_LEVERAGE` -> `Vulnerability`
		- `IS_TROPHY` -> `{category: Asset}` 
- `Vulnerability`
	- Describes an identified vulnerability. `IS_VULN` of a specific asset, to be defined as precisely as possible. `GRANTS` access to `Trophy`s. In case of chained vulnerabilities, `CAN_LEVERAGE` other vulnerabilities (an intermediary state `Trophy` is omitted for readability purposes).
	- Properties
		- `name`
		- `vuln_id` [optional], if a global vulnerability catalog is defined
	- Relationships
		- `IS_VULN` -> `{category: Asset}`
		- `GRANTS` -> `Trophy`
		- `CAN_LEVERAGE` -> `Vulnerability`
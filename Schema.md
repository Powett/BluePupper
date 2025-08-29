This document describes the suggested schema to describe all relevant objects.
# Versioning

| Version | Edits                                                                          | Ownership |
| ------- | ------------------------------------------------------------------------------ | --------- |
| v1.0    | -                                                                              | Powett    |
| v1.1    | Added [OPTIONAL] tags and `this` to make relationship description more precise |           |

# High-Level description
This section describes the identified categories, the objects contained, their properties and possible relationships.
## Summary
| Node Type         | Properties         | Relationships (direct way)                             |
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
> `category: Business`: Contains all objects related to business structure

- `BusinessUnit`
	- Describes a company or any scale of business unit. Can be recursively defined.
	- Properties
		- `name`
		- `external`: Tag non-owned companies or units
	- Relationships
		- [OPTIONAL] `this` - `MANAGES` -> `{category: Business | Asset}`
- `Site`
	- Describes a physical or logical site within a business unit. Avoid recursive definition.
	- Properties
		- `name`
	- Relationships
		- [OPTIONAL] `this` - `MANAGES` -> `{category: Business | Asset}`

## Asset hierarchy
> `category: Asset`: Contains all objects owned by one of the previous business objects 

- `WAN`
	- Describes a company WAN. Access Control details (VLAN segmentation, firewalls, etc) are abstracted at this level, and to be specified if strictly necessary at lower levels. If has attached `Vulnerability`, make sure the `Vulnerability` cannot be attached in a more precise way. If has attached `Server`, make sure the `Server` cannot be attached in a more precise way.
	- Properties
		- `name`
	- Relationships
		- [OPTIONAL] `this` - `CAN_REACH` -> `VLAN | WAN`
		- [OPTIONAL] `this` - `HAS_VLAN` -> `VLAN`
		- [OPTIONAL] `this` - `HAS_MACHINE` -> `Server`
- `VLAN`
	- Describes a VLAN. Try to only describe VLANs necessary to attack paths or global comprehension. Feel free to generalize as a first approach, then iteratively add details when necessary. Can be recursively defined. If has attached `Vulnerability`, make sure the `Vulnerability` cannot be attached in a more generic way. If has attached `Server`, make sure the `Server` cannot be attached in a more precise way.
	- Properties
		- `name`
		- `ip_range`
	- Relationships
		- [OPTIONAL] `this` - `CAN_REACH` -> `VLAN | WAN`
		- [OPTIONAL] `this` - `HAS_VLAN` -> `VLAN`
		- [OPTIONAL] `this` - `HAS_MACHINE` -> `Server`
- `Server`
	- Describes a server, (or set of servers with similar configuration, role or vulnerability). Feel free to generalize as a first approach, then iteratively add details when necessary. E.g. if several servers expose SMBv1, you can create a generic "SMB Server" object as a first approximation. Owned by a `VLAN`, `WAN` or `Domain` (if domain-joined).
	- Properties
		- `name`
		- `ip` [optional]
	- Relationships
		- [OPTIONAL] `this` - `EXPOSES_SERVICE` -> `Service`
- `Service`
	- Describes a service exposed by one or more servers. Add details only when necessary. If an `Account` is attached, make sure `Service` does not rely on domain authentication.
	- Properties
		- `name`
		- `port`
	- Relationships
		- [OPTIONAL] `this` -`HAS_ACCOUNT`
- `Domain`
	- Describes an Active Directory domain. Can be recursively defined.
	- Properties
		- `name`
	- Relationships
		- `{category: Asset}` - `HAS_DOMAIN` -> `this`
		- [OPTIONAL] `this` - `HAS_MACHINE` -> `Server`
		- [OPTIONAL] `this` - `HAS_DC` -> `Server` (can be parallel with `HAS_MACHINE`)
		- [OPTIONAL] `this` - `HAS_ACCOUNT` -> `Account`
- `Account`
	- Describes an account, for a specific domain or service.
	- Properties
		- `name`
  
## Attack hierarchy
> `category: Attack`: Contains all objects related to attack paths, from entry to achievements
- `Entry`
	- Describes an identified major entry point. Can be physical, network, or other type. `GRANTS` access to assets, and `CAN_LEVERAGE`  `Vulnerability`s.
	- Properties
		- `name`
		- `type`: `Network | Physical` as of latest version
	- Relationships
		- [OPTIONAL] `this` - `CAN_LEVERAGE` -> `Vulnerability`
		- `this` - `GRANTS` -> `Trophy`
- `Trophy`
	- Describes an achievement that can be obtained by attackers, often a certain level of access to an asset. To be defined more precisely depending on context. To be kept to a minimum for readability purposes. Can imply (`IMPLIES`) other contained trophies. `CAN_LEVERAGE` vulnerabilities (a default trophy for access to any asset was pruned for readability purposes). `IS_TROPHY` of a specific asset, to be defined as precisely as possible.
	- Properties
		- `name`
		- `type`: `NetworkAccess | AuthenticatedAccess | AdminAccess` as of latest version
	- Relationships
		- `this` - `IS_TROPHY` -> `{category: Asset}` 
		- [OPTIONAL] `this` - `IMPLIES` -> `Trophy`
		- [OPTIONAL] `this` - `CAN_LEVERAGE` -> `Vulnerability`
- `Vulnerability`
	- Describes an identified vulnerability.
    	- `IS_VULN` of a specific asset, to be defined as precisely as possible.
    	- Possibly `GRANTS` access to `Trophy`s through exploit
    	- Depends on a *context*, that `CAN_LEVERAGE` this vulnerability. This can be another `Vulnerability`, in case of chained vulnerabilities.
	- Properties
		- `name`
		- `vuln_id` [optional], if a global vulnerability catalog is defined
	- Relationships
		- `this` - `IS_VULN` -> `{category: Asset}`
		- `{category: Attack}` - `CAN_LEVERAGE` -> `this`
		- [OPTIONAL] `this` - `GRANTS` -> `Trophy`
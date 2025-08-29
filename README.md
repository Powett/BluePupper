<p align="center"><img src="./bluepupper.png" width="256" alt="BluePupper"></p>

<h1 align="center">BluePupper</h1>

<p align="center">Visualization tool based on Neo4j database to study attack paths in a compromised business infrastructure.</p>

<hr>

# Prerequisites
- Neo4j database and visualizer

# Usage
## Setup
- Host and create a Neo4j database [Installation - Operations Manual](https://neo4j.com/docs/operations-manual/current/installation/)
- Connect to the database instance
- Populate the database
- Use Neo4j tools (console, Bloom, ...) to explore results

## Populate database
### With sample data
Use [predefined sample querie](queries/sample_data.cypher) to cleanup and populate with sample data.
### With obtained data
**TBD** how to format data according to [Schema](Schema.md)

## Example requests
- All exploitable paths from any `Entry` to any `Trophy` of type `AdminAccess`
```cypher
MATCH (start:Entry), (end:Trophy {type: "AdminAccess"})
MATCH p = (start)-[:IMPLIES|GRANTS|CAN_REACH|CAN_LEVERAGE*]->(end)
RETURN p
```
- Shortest paths from any `Entry` to any `Trophy` of type `AdminAccess`
```cypher
MATCH (start:Entry), (end:Trophy {type: "AdminAccess"})
MATCH p = shortestPath((start)-[:IMPLIES|GRANTS|CAN_REACH|CAN_LEVERAGE*]->(end))
RETURN p
```
### Sanity checks requests
These requests allow to check for common errors while populating the database:
- Nodes without properties
```cypher
MATCH (n) WHERE size(keys(n)) = 0 RETURN n
```
- Orphaned nodes (without any relationships)
```cypher
MATCH (n)
WHERE NOT (n)--()
RETURN n
```
- Untyped nodes
```cypher
MATCH (n)
WHERE size(labels(n)) = 0
RETURN n
```
- `Vulnerability`s that cannot be leveraged
```cypher
MATCH (v:Vulnerability)
WHERE NOT ()-[:CAN_LEVERAGE]->(v)
RETURN v
```
- `Vulnerability`s that are not related to any asset
```cypher
MATCH (v:Vulnerability)
WHERE NOT (v)-[:IS_VULN]->()
RETURN v
```


# Schema
Please refer to the schema [here](Schema.md) for details regarding schema and constraints.

# TODO
- [ ] Add explanations on how to convert obtained data to [Schema](Schema.md) format and to a `cypher` query
- [ ] Add Azure/Cloud resources support
- [ ] Find how to enforce schema constraints
	- [ ] Categories
	- [ ] Relationships
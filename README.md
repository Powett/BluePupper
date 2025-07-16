# Description
Visualization tool for attack paths in a business infrastructure.

# Usage
- Host and create a Neo4j database [Installation - Operations Manual](https://neo4j.com/docs/operations-manual/current/installation/)
- Connect to the database instance
- Run attached Cypher query to create sample data
- Use Neo4j tools (console, Bloom, ...) to explore results

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
# Schema
Please refer to [[Schema]] for details regarding schema and constraints.
# # TODO
- [ ] Add Azure/Cloud resources support
- [ ] Find how to enforce schema constraints
	- [ ] Categories
	- [ ] Relationships
---
name: code-graph
description: Build and query a knowledge graph of a codebase. Use when you need impact analysis ("what breaks if I change X?"), to find circular dependencies, to trace who calls a function, or to understand an unfamiliar codebase structurally before changing it.
license: MIT
metadata:
  author: unisone
---

# Code Graph Skill

Turn a codebase into a queryable graph: files, modules, symbols, and the
edges between them. Once the graph exists, whole classes of questions become
trivial that are painful with grep.

## Purpose

Answer structural questions with evidence instead of guessing:

- **Blast radius** — "If I change `auth.ts`, what could break?"
- **Callers** — "Who calls `processPayment()`?"
- **Cycles** — "Are there circular dependencies in this codebase?"
- **Dead ends** — "Is this function reachable from any entry point?"
- **Onboarding** — "What are the core modules and how do they connect?"

## Building the Graph

### Level 1: Import graph (fast, always worth it)

Map which file imports which. Per language:

```bash
# JavaScript/TypeScript — madge gives you the import graph as JSON or image
npx madge --json src/index.ts > import-graph.json
npx madge --image graph.svg src/index.ts   # circular deps highlighted in red

# Python — pydeps
pydeps --show-dot --noshow src/main.py > import-graph.dot

# Go — built in
go list -deps ./... > deps.txt

# Rust — cargo tree (dependency crates, not modules)
cargo tree --edges normal
```

### Level 2: Symbol graph (functions, classes, and calls)

For blast-radius questions you need symbols, not just files:

```bash
# Universal: ctags for symbol definitions
ctags -R --fields=+n -o tags src/

# Then extract call edges with a language-aware pass:
#  - tree-sitter grammars (node, python, go, rust all have them)
#  - or LSP: `references` requests give you exact caller lists
```

If the repo has a language server configured, prefer LSP `textDocument/references`
over regex — it resolves through aliases and re-exports that grep misses.

### Level 3: Store it for repeated queries

For a one-off question, the JSON/DOT output is enough. If you'll query
repeatedly (large refactor, ongoing audit), load it into a graph database:

```bash
pip install kuzu   # embedded graph DB, no server needed
```

```cypher
// Nodes: files and symbols. Edges: IMPORTS, CALLS, DEFINES.
CREATE NODE TABLE File(path STRING, language STRING, PRIMARY KEY(path));
CREATE NODE TABLE Symbol(name STRING, kind STRING, file STRING, line INT64, PRIMARY KEY(name));
CREATE REL TABLE IMPORTS(FROM File TO File);
CREATE REL TABLE CALLS(FROM Symbol TO Symbol);
```

## Query Patterns

Once the graph exists, these are the high-value queries:

**Who depends on X (blast radius)?**
```cypher
// All files that transitively import the changed file
MATCH (changed:File {path: 'src/auth.ts'})<-[:IMPORTS*1..]-(dependent:File)
RETURN DISTINCT dependent.path;
```

**Who calls this function?**
```cypher
MATCH (caller:Symbol)-[:CALLS]->(target:Symbol {name: 'processPayment'})
RETURN caller.name, caller.file, caller.line;
```

**Circular dependencies?**
```cypher
// Any file that can reach itself through imports
MATCH path = (f:File)-[:IMPORTS*2..]->(f)
RETURN [n IN nodes(path) | n.path] AS cycle LIMIT 10;
```
(Madge also flags these directly: `npx madge --circular src/`.)

**Is this code reachable?**
```cypher
// Symbols NOT reachable from entry points = dead-code candidates
MATCH (entry:Symbol) WHERE entry.name IN ['main', 'index']
MATCH (entry)-[:CALLS*0..]->(reachable:Symbol)
WITH collect(reachable) AS reached
MATCH (s:Symbol) WHERE NOT s IN reached
RETURN s.name, s.file, s.line;
```

**What are the core modules?**
Rank files by in-degree (most imported = most central). The top 10 files
are the ones to read first when onboarding.

## Visualizing

- **Mermaid** for docs and PRs: `graph TD` with the top ~20 nodes. Keep it
  small — a 500-node diagram helps nobody.
- **DOT/Graphviz** for full detail: `dot -Tsvg graph.dot -o graph.svg`.
- **Madge images** for quick circular-dependency checks.

## Anti-patterns

- **Building the full graph before a trivial question.** If you just need
  callers of one function, LSP references beat a whole pipeline.
- **Stale graphs.** A graph built last month lies about today's code.
  Rebuild on demand; never cache across refactors.
- **Regex call extraction on aliased imports.** `import {x as y}` defeats
  naive grep. Use the language server or accept the blind spot explicitly.
- **Graph at the wrong granularity.** File-level for architecture questions,
  symbol-level for blast radius. Mixing them muddies both.

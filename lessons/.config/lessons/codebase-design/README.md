# Codebase Design

Module-design vocabulary and structural patterns. Shared language for designing **deep modules** — a lot of behaviour behind a small interface, at a clean seam, testable through that interface — and for judging how those modules stack into call paths.

| Lesson | Role | Read when |
|--------|------|-----------|
| [`deep-modules.md`](deep-modules.md) | The vocabulary (module, interface, depth, seam, adapter, leverage, locality) and the core principles (deletion test, interface-is-test-surface, one-vs-two adapters, make illegal states unrepresentable). **Start here.** | always |
| [`composition.md`](composition.md) | The path *between* modules: what each hop in a call chain adds, whether adjacent layers change the abstraction, and whether a change was absorbed by the existing concepts or accreted beside them (pass-throughs, special-general mixture, connascence across seams, the lava layer). | when a change joins existing code — always, at review time |
| [`deepening.md`](deepening.md) | How to deepen a cluster of shallow modules safely, by dependency category, and how its tests change. | when restructuring an existing cluster |
| [`design-it-twice.md`](design-it-twice.md) | Parallel sub-agent pattern to explore several radically different interfaces before committing. | when the interface is uncertain |

The test-side counterparts live in [`../testing/`](../testing/README.md) — `deep-modules.md` owns the testability *principles*; `testing/` owns the test *mechanics*.

---
name: refactoring
description: Standalone refactoring passes — code organization, API design, code reuse, hygiene — distinct from the in-cycle refactor step of TDD. Use when the user asks to refactor a module/package, reduce coupling, simplify an API, extract shared utilities, clean up dead code, or improve architecture without changing behavior. Triggers on phrases like "refactor X", "clean up X", "simplify X", "split X into modules", "reduce duplication", "improve the API of X".
---

# Refactoring

This skill is for **standalone refactoring passes** — work whose goal is to improve structure while preserving behavior. For the refactor step *inside* a TDD red-green-refactor cycle, see `~/.claude/skills/tdd/refactoring.md` instead.

## Focus Areas

### 1. Code Organization & Modularity
- **Extract cohesive modules**: Identify logical groupings of functionality that can be separated into focused modules.
- **Split large files**: Break files with multiple responsibilities into single-responsibility modules.
- **Reduce coupling**: Identify and minimize tight dependencies between components.
- **Improve cohesion**: Ensure related functionality stays together.

### 2. API Design & Interface Clarity
- **Simplify public interfaces**: Reduce API surface area where appropriate.
- **Consolidate related endpoints**: Group similar functionality under coherent modules.
- **Improve naming**: Ensure functions, classes, and modules have clear, intention-revealing names.
- **Establish clear boundaries**: Define explicit interfaces between subsystems.

### 3. Code Reuse & Shared Utilities
- **Extract common patterns**: Identify repeated code blocks and extract shared utilities.
- **Create helper functions**: Abstract repetitive operations into reusable helpers.
- **Avoid duplication**: Apply DRY judiciously.
- **Consider common libraries**: For widely-used functionality across the codebase.

### 4. Code Hygiene
- **Remove dead code**: Delete unused functions, classes, and variables.
- **Eliminate obsolete tests**: Remove tests for deleted functionality.
- **Clean up commented code**: Remove commented-out code blocks that are no longer relevant.
- **Update stale documentation**: Align comments and docs with current implementation.

## Design Patterns to Consider

When refactoring, consider applying these patterns where appropriate:

- **Factory Pattern**: For complex object creation logic.
- **Strategy Pattern**: For interchangeable algorithms or behaviors.
- **Facade Pattern**: To simplify complex subsystem interfaces.
- **Repository Pattern**: For data access abstraction.
- **Dependency Injection**: To reduce coupling and improve testability.
- **Builder Pattern**: For constructing complex objects step-by-step.
- **Adapter Pattern**: To integrate incompatible interfaces.

## Anti-Patterns to Avoid

Be mindful of over-engineering:

- **Premature abstraction**: Don't create protocols/interfaces used in only one place without clear future need.
- **Speculative generality**: Don't add flexibility "just in case" without concrete requirements.
- **Excessive layering**: Don't create layers of indirection that obscure rather than clarify.
- **Over-modularization**: Don't split code so finely that it becomes hard to follow the flow.
- **Abstract base classes for single implementations**: Wait until you have 2–3 implementations before abstracting.
- **Configuration over convention**: Prefer sensible defaults over requiring configuration.
- **Framework creation**: Resist building internal frameworks unless you have multiple consumers.

## Success Criteria

Quality is not measured by lines of code, but by:

- **Readability**: Can a new developer understand the code flow quickly?
- **Maintainability**: Can changes be made safely without cascading effects?
- **Testability**: Can components be tested in isolation?
- **Clear responsibility**: Does each module have a well-defined, focused purpose?
- **Appropriate abstraction levels**: Are abstractions justified by actual reuse or flexibility needs?
- **Minimal cognitive load**: Does the architecture reduce mental overhead?

## Approach

- **Analyze before acting**: Understand the current structure and dependencies first.
- **Identify pain points**: Look for actual problems, not theoretical ones.
- **Prioritize high-impact changes**: Focus on areas that will yield the most benefit.
- **Refactor incrementally**: Make changes in small, testable steps.
- **Preserve behavior**: Ensure functionality remains unchanged unless explicitly intended.
- **Validate with tests**: Confirm existing tests pass after refactoring.

## Guiding Principles

- **YAGNI**: Only add what's needed now.
- **KISS**: Prefer simple solutions over clever ones.
- **Rule of Three**: Consider abstracting after the third duplication, not the first.
- **Single Responsibility**: Each module should have one reason to change.
- **Open/Closed**: Open for extension, closed for modification — where it makes sense.

## How to Apply This Skill

These are **principles, not a checklist**. Evaluate each one against the specific codebase, architecture, and constraints before applying — discard what doesn't fit, adapt what does. A "best practice" misapplied to the wrong context is worse than no practice at all.

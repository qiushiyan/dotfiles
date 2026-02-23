---
name: review-council
description: Multi-perspective code review using 3-5 parallel subagents with dynamically chosen personas. Each persona argues for their approach, then synthesizes into prioritized recommendations. Use when user wants to review changes from multiple angles, requests "/review-council", asks for multi-perspective review, or wants creative/outside-the-box feedback on their work.
---

# Review Council

Review code changes using 3-5 parallel subagents, each adopting a unique perspective dynamically chosen based on the changes. Personas can be drawn from common archetypes or invented to fit the specific problem domain.

## Workflow

### 1. Gather Changes

Determine what to review:
- If uncommitted changes exist: `git diff` + `git diff --cached`
- If no uncommitted changes: `git show HEAD`
- If user specifies a range: use their specification

Show the user a brief summary of what's being reviewed (files changed, rough scope).

### 2. Analyze and Select Personas

Based on the nature and scope of the changes, select **3-5 personas** that will create productive tension and surface different concerns.

**Guidance on count:**
- 3 personas: Small/focused changes, single-concern fixes
- 4 personas: Medium changes touching multiple areas
- 5 personas: Large/architectural changes, risky areas, or when perspectives genuinely conflict

**Example personas** (use as inspiration, not a fixed pool):
- Security Auditor, Performance Engineer, Devil's Advocate
- User Advocate, Maintainability Expert, Pragmatist
- Innovator, Domain Expert, Test Advocate, API Designer

**Create custom personas when relevant.** If the changes involve specific domains (e.g., "GraphQL Schema Purist" for API changes, "State Machine Formalist" for workflow logic, "Data Pipeline Guardian" for ETL code), invent a fitting perspective rather than forcing a generic one.

Announce selected personas and briefly explain why each was chosen.

### 3. Spawn Parallel Review Agents

Use the Task tool to spawn the selected personas as opus subagents in parallel (single message, multiple tool calls).

Each agent prompt must include:
1. The full diff/changes
2. Their assigned persona and perspective
3. Instruction to be critical and argue for their viewpoint
4. Instruction to think outside the box and suggest alternatives
5. If user specified a focus area, include it
6. Request for a structured output: key concerns, recommendations, and one creative/unconventional suggestion

Example agent prompt structure:
```
You are the [PERSONA] reviewing these changes:

[DIFF]

Your perspective: [PERSPECTIVE DESCRIPTION]

Analyze critically from your viewpoint. Be opinionated and argue for your position.
Think creatively - what unconventional approaches might work better?
[If focus area specified: Focus especially on: FOCUS_AREA]

Provide:
1. Top 3 concerns from your perspective
2. Specific recommendations with code examples if helpful
3. One creative/outside-the-box suggestion
```

### 4. Create Task List for Visibility

Before spawning agents, create a task for each selected persona so user sees progress. Update tasks as agents complete.

### 5. Synthesize Results

After all agents return, present:

**A. Individual Summaries**
For each persona, show:
- Persona name
- Their top concerns (bulleted)
- Their key recommendation

**B. Points of Agreement**
Where multiple personas aligned

**C. Points of Contention**
Where personas disagreed - briefly note the tension

**D. Final Prioritized Recommendations**
Synthesize into actionable list, prioritized by:
1. **Critical**: Security issues, bugs, data loss risks
2. **High**: Performance problems, major UX issues
3. **Medium**: Maintainability, code quality
4. **Low**: Nice-to-haves, style preferences

Include the most compelling creative suggestion if it has merit.

## Example Invocations

- `/review-council` - Review all uncommitted changes
- `/review-council` with "focus on error handling" - Review with specific focus
- `review my changes from multiple perspectives` - Natural language trigger

# Agent Profile Template

**Use this template to create new subagent profiles**

---

# [AGENT-ID]: [Agent Name]

**Agent ID:** [TEAM]-[NUMBER] (e.g., CORE-001, UI-002)  
**Role:** [Primary Role Title]  
**Team:** [Team Name]  
**Status:** 🟢 Available | 🟡 Busy | 🔴 Unavailable

---

## Profile

**Primary Expertise:**
- [Skill 1]
- [Skill 2]
- [Skill 3]

**Secondary Skills:**
- [Additional skill 1]
- [Additional skill 2]

---

## Responsibilities

### [Category 1]
- [Responsibility]
- [Responsibility]

### [Category 2]
- [Responsibility]
- [Responsibility]

### [Category 3]
- [Responsibility]
- [Responsibility]

---

## When to Call This Agent

✅ **Call [AGENT-ID] for:**
- [Use case 1]
- [Use case 2]
- [Use case 3]

❌ **Don't call for:**
- [Wrong use case 1] (use [OTHER-AGENT])
- [Wrong use case 2] (use [OTHER-AGENT])

---

## Invocation Template

```markdown
**Agent:** [AGENT-ID] ([Agent Name])
**Task:** [Brief task description]

**Context:**
- Current State: [What exists]
- Branch: [Git branch]
- Component: [What component]
- Files: [Relevant files]

**Requirements:**
1. [Requirement 1]
2. [Requirement 2]
3. [Requirement 3]

**Deliverables:**
- [ ] [Deliverable 1]
- [ ] [Deliverable 2]
- [ ] [Deliverable 3]

**Timeline:** [If applicable]
**Dependencies:** [If applicable]
```

---

## Example Invocations

### Example 1: [Task Type]

```markdown
**Agent:** [AGENT-ID]  
**Task:** [Specific task]

**Context:**
- Current State: [Details]
- Branch: [branch-name]
- [Other context]

**Requirements:**
1. [Specific requirement]
2. [Performance target]
3. [Constraint]

**Deliverables:**
- [ ] [What to produce]
- [ ] [What to deliver]

**Timeline:** [Time estimate]
```

### Example 2: [Another Task Type]

[Same format as Example 1]

---

## Collaboration Patterns

### With [AGENT-ID] ([Agent Name])
- [How they collaborate]
- [What they coordinate on]

### With [AGENT-ID] ([Agent Name])
- [How they collaborate]
- [What they coordinate on]

---

## Technical Context

### Technologies
- **Primary:** [Main tech stack]
- **Frameworks:** [Frameworks used]
- **Tools:** [Development tools]

### Code Locations
```
path/to/relevant/code/
├── dir1/
└── dir2/
```

### Reference Documentation
- [Link to relevant docs](../path/to/doc.md)
- [External resource](https://example.com)

---

## Key Decisions/Context (Optional)

Important context specific to this agent's domain:

1. **Decision 1** - [Reasoning]
2. **Decision 2** - [Reasoning]

---

## Communication Style

**Preferred Format:**
- [How this agent communicates]
- [What kind of outputs to expect]
- [Level of detail]

**[Work Product] Should Include:**
- [Element 1]
- [Element 2]
- [Element 3]

---

## Availability & Workload

**Current Status:** [Available/Busy/Unavailable]  
**Active Assignments:** [Current tasks or None]  
**Estimated Capacity:** [Time available]

**Priority Queue:**
1. [Priority item 1]
2. [Priority item 2]
3. [Priority item 3]

---

**Last Updated:** YYYY-MM-DD  
**Agent Version:** 1.0

---

## Notes for Template Users

1. Replace all [PLACEHOLDERS] with actual content
2. Remove this "Notes" section when creating real agent
3. Keep profile concise but informative
4. Provide 2-3 concrete example invocations
5. List key collaboration patterns
6. Include technical context relevant to role
7. Update status and availability regularly

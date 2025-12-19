# KOOMPI OS Subagent Directory

**Purpose:** Callable AI subagents for KOOMPI OS development with defined roles and responsibilities.

---

## Quick Reference

| Agent ID | Role | Primary Skills | When to Call |
|----------|------|----------------|--------------|
| **CORE-001** | Core System Architect | Rust, daemon design, D-Bus | System architecture, core features |
| **CORE-002** | Package Manager Specialist | Pacman, AUR, package management | Package system integration |
| **CORE-003** | Snapshot Engineer | Btrfs, snapshots, rollback | Immutability features |
| **UI-001** | Compositor Developer | Rust, Smithay, Wayland | Shell development |
| **UI-002** | KDE Integration Specialist | Plasma, QML, KWin | KDE edition features |
| **UI-003** | Application Developer | Rust/Qt6, desktop apps | Native applications |
| **TEST-001** | Test Automation Lead | Pytest, Cargo test, CI/CD | Testing strategy |
| **TEST-002** | QA Engineer | Manual testing, validation | Quality assurance |
| **DOCS-001** | Technical Writer | Documentation, tutorials | User guides, API docs |
| **DOCS-002** | Architecture Documenter | System design, diagrams | Technical specifications |
| **EDU-001** | Mesh Network Engineer | P2P, libp2p, networking | Education features |
| **OFFICE-001** | Office Suite Architect | Fileverse, Tauri, React | Office suite development |
| **OFFICE-002** | Format Conversion Specialist | DOCX/XLSX/PPTX | MS Office compatibility |
| **INT-001** | DevOps Lead | CI/CD, archiso, releases | Build pipeline, deployment |
| **AI-001** | AI Integration Lead | Gemini API, LLMs | AI assistant features |

---

## How to Use This Directory

### 1. Identify the Task Area
Match your task to the appropriate domain (Core, UI, Testing, etc.)

### 2. Select the Right Agent
Choose the agent whose expertise matches your specific need

### 3. Call the Agent
Use the agent's invocation template (see individual agent files)

### 4. Provide Context
Give the agent:
- Current project state
- Specific task requirements
- Expected deliverables
- Constraints/dependencies

---

## Agent Profiles

### Core System Team

- [CORE-001: Core System Architect](agents/core-001-architect.md)
- [CORE-002: Package Manager Specialist](agents/core-002-packages.md)
- [CORE-003: Snapshot Engineer](agents/core-003-snapshots.md)
- [CORE-004: FFI Developer](agents/core-004-ffi.md)

### UI/UX Team

- [UI-001: Compositor Developer](agents/ui-001-compositor.md)
- [UI-002: KDE Integration Specialist](agents/ui-002-kde.md)
- [UI-003: Application Developer](agents/ui-003-apps.md)
- [UI-004: UX Designer](agents/ui-004-designer.md)

### Testing & QA Team

- [TEST-001: Test Automation Lead](agents/test-001-automation.md)
- [TEST-002: Rust Test Engineer](agents/test-002-rust.md)
- [TEST-003: Python Test Engineer](agents/test-003-python.md)
- [TEST-004: QA Engineer](agents/test-004-qa.md)

### Documentation Team

- [DOCS-001: Technical Writer](agents/docs-001-writer.md)
- [DOCS-002: Architecture Documenter](agents/docs-002-architect.md)
- [DOCS-003: API Documentation Specialist](agents/docs-003-api.md)

### Education Team

- [EDU-001: Mesh Network Engineer](agents/edu-001-mesh.md)
- [EDU-002: Teacher Tools Developer](agents/edu-002-teacher.md)
- [EDU-003: Educational Content Curator](agents/edu-003-content.md)

### Office Suite Team

- [OFFICE-001: Office Suite Architect](agents/office-001-architect.md)
- [OFFICE-002: Format Conversion Specialist](agents/office-002-formats.md)
- [OFFICE-003: Desktop Integration Developer](agents/office-003-desktop.md)
- [OFFICE-004: Frontend Developer](agents/office-004-frontend.md)

### Integration & Release Team

- [INT-001: DevOps Lead](agents/int-001-devops.md)
- [INT-002: ISO Build Engineer](agents/int-002-iso.md)
- [INT-003: Release Manager](agents/int-003-release.md)

### AI Team

- [AI-001: AI Integration Lead](agents/ai-001-integration.md)
- [AI-002: Knowledge Base Engineer](agents/ai-002-knowledge.md)
- [AI-003: Voice Recognition Engineer](agents/ai-003-voice.md)

---

## Agent Invocation Template

```markdown
**Agent:** [AGENT-ID] [Agent Name]
**Task:** [Brief task description]
**Context:**
- Current state: [What's been done]
- Branch: [Git branch]
- Related files: [Relevant files]

**Requirements:**
1. [Specific requirement 1]
2. [Specific requirement 2]

**Deliverables:**
- [ ] [Expected output 1]
- [ ] [Expected output 2]

**Constraints:**
- Timeline: [If applicable]
- Dependencies: [If applicable]
```

---

## Multi-Agent Collaboration

For complex tasks requiring multiple agents:

1. **Define Task Scope** - Break down into component parts
2. **Assign Agents** - Match components to agent expertise
3. **Set Dependencies** - Define execution order
4. **Coordinate** - Use project manager agent for orchestration

**Example: Adding a New Feature**
```
1. DOCS-002: Create technical specification
2. CORE-001: Review and approve architecture
3. CORE-00X: Implement core functionality
4. TEST-001: Create test plan
5. DOCS-001: Write user documentation
6. INT-001: Add to CI/CD pipeline
```

---

## Agent Status

| Agent | Status | Current Assignment | Availability |
|-------|--------|-------------------|--------------|
| All agents | 🟢 Available | None | Ready |

*Status will be updated as agents are assigned tasks*

---

**Directory:** `docs/subagents/`  
**Last Updated:** 2025-12-19  
**Total Agents:** 24

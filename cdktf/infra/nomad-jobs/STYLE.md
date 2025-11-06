# Nomad Job Style Guide — Munchbox Project

## Overview

This guide establishes consistent formatting, commenting, and structural standards for all Nomad job definitions in the Munchbox project. All jobs should follow these conventions to ensure readability, maintainability, and professional presentation for shared repositories.

---

## 1. File Header

Every job file must begin with a descriptive header box comment containing project and author information.

### Format
```hcl
# -------------------------------------------------------------------------------
#  <Job Name> — <Brief Description>
#
#  Project: Munchbox
#  Author: <Your Name>
#
#  <Detailed description of job purpose, key technologies, and notable features.
#   Keep to 2-4 sentences for clarity.>
# -------------------------------------------------------------------------------
```

---

## 2. Comment Styles

**Box Comments (Section Headers)** — Use for major structural divisions (job-level sections, group-level sections, task-level sections)
- Format: `# -------...` (79 chars) or `# -----...` (73 chars) with section name between
- Followed by blank line before code
- ASCII-only

**Single-Line Comments** — Use for logical groupings of related configuration
- Format: `# --- Description ---`
- Placed immediately above code (no blank line)
- Precede conceptual categories: "Workload identity and secrets" groups `identity` + `vault`; "Docker image configuration" covers `config` block
- Use for any related blocks that form a logical unit

**No End-of-Line Comments** — Comments must appear above code blocks only.

---

## 3. Structural Organization

### Job Level

1. File header
2. `job` declaration with metadata (`region`, `datacenters`, `type`, `node_pool`)
3. `update` block for deployment strategy

### Group Level (in order)

1. `count` or group metadata
2. Network configuration (`network`)
3. Placement constraints (`constraint`)
4. Storage configuration (`ephemeral_disk`)
5. Restart behavior (`restart`)
6. Reschedule policy (`reschedule`)

### Task Level (in order)

1. `driver` declaration
2. Workload identity and secrets (`identity`, `vault`)
3. Driver configuration (`config`)
4. Service registration (`service`)
5. Runtime environment (`template`, `env`)
6. Resource allocation (`resources`)
7. Termination configuration (`kill_timeout`, `kill_signal`, `shutdown_delay`)

---

## 4. Box Header Sections

Only the following receive box-style comments:

- **Job-level:** File header + `<Job Name> — <Description>` section
- **Group-level:** `<Group Name>` (e.g., "Runner Group")
- **Task-level:** `<Task Name>` (e.g., "Runner Task")

## 5. Single-Line Comments

Single-line comments should precede logical groupings of related configuration blocks. Use them for:

- **Related blocks within a section:** Group identity + vault blocks, network + constraints, etc.
- **Conceptual categories:** Labels that explain what the following code does
- **Any grouping of related configuration:** Don't overthink it—use a descriptive label

Add new labels as needed for your jobs. Consistency within a job matters more than matching a pre-defined list.

---

## 6. Whitespace and Indentation

- **After box comments:** Always one blank line before code
- **After single-line comments:** No blank line (comment directly above code)
- **Between groups:** One blank line for visual separation
- **Indentation:** 2 spaces, no tabs

---

## 7. Code Style

**Attribute Alignment:**
```hcl
# --- Resource allocation ---
resources {
  cpu    = 2000
  memory = 2048
}
```

**Multiline Strings:**
```hcl
# --- Runtime environment ---
template {
  destination = "secrets/config.env"
  env         = true
  data        = <<-EOT
    VAR1=value1
    VAR2=value2
  EOT
}
```

---

## 8. Checklist

- [ ] Header includes Project and Author
- [ ] All comments use dashes (`-`) not equals (`=`)
- [ ] ASCII-only characters throughout
- [ ] No end-of-line comments
- [ ] Single-line comments directly above code (no blank line)
- [ ] Box comments followed by blank line
- [ ] Professional language appropriate for public repositories
- [ ] Sections follow structural order
- [ ] Proper 2-space indentation
- [ ] Attribute alignment for readability

Current version: 1.0

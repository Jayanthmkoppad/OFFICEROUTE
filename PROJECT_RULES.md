# PROJECT RULES

## Purpose

These rules apply to every code change in the OfficeRoute project.

Follow them for every task.

---

# Engineering Principles

Treat this repository like a production enterprise application.

Never treat it as a demo project.

Code quality is more important than speed.

Understand existing code before making changes.

Never guess.

Verify everything.

---

# Before Making Changes

Always:

- Read the existing implementation.
- Understand the feature.
- Identify dependencies.
- Explain the planned changes.
- List every file that will be modified.
- Wait for approval before editing.

---

# Code Quality

Always write:

- Clean Architecture
- Modular code
- Reusable widgets
- Proper state management
- Null-safe code
- Production-ready code
- Maintainable code
- Well-structured code

Never generate placeholder implementations.

Never generate fake data unless explicitly requested.

---

# File Safety

Never delete existing working code.

Never rewrite unrelated files.

Never duplicate:

- Models
- Services
- Controllers
- Widgets

Always reuse existing architecture.

---

# Error Handling

Never hide exceptions.

Never replace real errors with generic messages.

Always log:

- Exception type
- Exception message
- Stack trace (when useful)
- Root cause

Fix the cause, not only the symptom.

---

# Flutter Standards

After every completed batch run:

flutter pub get

flutter analyze

flutter test

If any issue appears:

Fix it immediately.

Never leave analyzer errors.

---

# Performance

Avoid unnecessary rebuilds.

Avoid duplicated logic.

Keep widgets lightweight.

Optimize Firestore usage.

Avoid unnecessary network calls.

---

# Firebase

Always verify:

- Firebase initialization
- Authentication
- Firestore
- Security Rules
- Current User
- Document IDs
- Collections
- Error handling

Never assume Firebase is configured correctly.

---

# Reporting

After every completed task generate:

## Summary

Files Created

Files Modified

Files Deleted

Issues Found

Issues Fixed

Flutter Analyze Result

Flutter Test Result

Phone Testing Instructions

Remaining Work

Next Recommended Task

---

# Project Documents

Whenever changes are completed update:

- PROJECT_STATUS.md
- CHANGELOG.md

If roadmap changes:

Update ROADMAP.md

If architecture changes:

Update CODEX_MASTER.md

---

# Workflow

ChatGPT acts as:

- System Architect
- Code Reviewer
- Technical Lead

Codex acts as:

- Software Engineer
- Implementation Engineer

Respect existing architecture.

Never redesign without a clear reason.

---

# Final Rule

Every commit should leave the project in a better state than before.

The application must remain buildable, maintainable, and production-ready at every phase.

Stop after completing the requested task.

Wait for approval before continuing to the next phase.
## Debugging Rules

- Never investigate the same root cause repeatedly.
- Maximum three investigation levels.
- Stop after identifying an external dependency.
- Always verify existing fixes before applying new ones.
- Prefer reporting a precise manual action over endless retries.
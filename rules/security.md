# Security Rules

Applied continuously, and gated hard by `/security-review` before merge.

## Mandatory pre-merge checks

- [ ] No hardcoded secrets (API keys, passwords, tokens) — use env / secret manager
- [ ] All user input validated and sanitized at the boundary
- [ ] Parameterized queries only — never string-concatenate SQL
- [ ] Output encoded / escaped to prevent XSS; no unsanitized `innerHTML` / `dangerouslySetInnerHTML`
- [ ] AuthN/AuthZ enforced on every state-changing or sensitive path
- [ ] CSRF protection on state-changing forms; rate limiting on public endpoints
- [ ] Error messages don't leak stack traces, secrets, or internal structure

## Secret management

- Never commit secrets. Validate required secrets exist at startup.
- If a secret may have been exposed: stop, rotate it, then scan the codebase for siblings.

## OWASP Top-10 focus areas

Injection · Broken access control · Cryptographic failures · SSRF · Insecure
deserialization · Security misconfiguration · Vulnerable dependencies.

## Response protocol

On finding a security issue:
1. Stop and surface it with severity (Critical/High/Medium/Low).
2. Fix Critical/High before continuing.
3. Rotate any exposed secret.
4. Sweep for the same class of bug elsewhere.

## Severity → action

| Severity | Action |
|----------|--------|
| Critical | BLOCK merge — fix now |
| High | Fix before merge |
| Medium | Fix when reasonable |
| Low | Note; optional |

# Security policy

## What counts

This repository contains scripts that run on developers' machines and instructions that coding agents follow. Please report privately:

- a script that can be made to run a command, read or write outside the audited project, or leak a secret (keystore password, token) through the project it audits;
- a file in the audited project (a pubspec, manifest, plist, source file, file name) that can inject output into the report in a way that misleads the reader or the agent reading it;
- instructions in `SKILL.md` or a guide that lead an agent to do something unsafe;
- a problem in the starter template's security code (certificate pinning, token storage, log redaction, input validation).

A check that misses a problem in *your app*, or flags correct code, is not a security issue: use the "Missed problem" or "False alarm" issue templates.

## How to report

Use **Security → Report a vulnerability** on the repository page (GitHub private vulnerability reporting). Include the affected file, what an attacker has to control, and a minimal example.

Please do not open a public issue or pull request for it. You will get an answer as soon as a maintainer has reproduced it; a fix is released before the details are published.

## Supported versions

Only the latest release receives security fixes.

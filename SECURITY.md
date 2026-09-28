# Security Policy

## Supported versions

Only the actively maintained image lines receive security fixes:

| Bareos version | Ubuntu images | Alpine images |
|----------------|:-------------:|:-------------:|
| 25             | ✓             | ✓             |
| 24             | ✓             | ✓             |
| 23             | ✓             | ✓             |
| 22 and older   | ✗             | ✗             |

Bareos 22 tags remain published but frozen — no further rebuilds or CVE
patches. Bareos 21 and older have been removed entirely: no tags remain
published under `darkvex/`, and their source directories were removed from
this repository, so there is nothing left to patch.

## Reporting a vulnerability

Please do **not** open a public issue for security problems.

Report them privately through
[GitHub private vulnerability reporting](https://github.com/dark-vex/bareos/security/advisories/new).
Include the affected image and tag, a description of the issue and, if possible, steps to
reproduce it.

You should receive an acknowledgement within 7 days. Fixes are released as rebuilt images
and, when relevant, a published security advisory.

## Scope

This repository covers the container images, entrypoint scripts, compose examples, package
build tooling and CI workflows. Vulnerabilities in Bareos itself should be reported to the
[Bareos project](https://github.com/bareos/bareos/security).

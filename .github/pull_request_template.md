## What changed and why



- [ ] Documentation or metadata only
- [ ] Source or runtime behavior
- [ ] Tests or tooling
- [ ] Repository layout or release export
- [ ] Fixtures, protocol, or interoperability

## Claims and clean-room rules

- [ ] The verdict stays `PARTIAL`, or the PR shows the measured and reviewed
      evidence that justifies a different claim.
- [ ] Each claim says what it rests on: source, synthetic, localhost, measured
      hardware, reference peer, or not measured.
- [ ] No synthetic, localhost, built-in-device, archived, placeholder, or
      skipped result is presented as field interoperability or a product `PASS`.
- [ ] Only public or authorized inputs and original code are used; no
      proprietary or confidential material.
- [ ] No secrets, private captures, personal data, hostnames, or private
      evidence appear in the change or the discussion.
- [ ] Local notes and private evidence are not committed.
- [ ] Any change under `third_party/opus/` or `third_party/jpeg-xs/` is
      described and justified.

## Verification

Commands run and their results:

```text

```

Checks not run, why, and what that leaves uncertain:

```text

```

## For reviewers

- [ ] I have described any runtime, state, UI, protocol, or compatibility risk.
- [ ] I have listed any changed public claim, fixture source, or evidence
      limit.
- [ ] I have noted any effect on the release export. This PR does not imply a
      tag, published artifact, supported release, or field readiness.
- [ ] I have listed any repository-policy files this PR touches.
- [ ] I have asked for the source, clean-room, and release reviews that apply.

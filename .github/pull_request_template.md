## Scope

- [ ] Documentation or metadata only
- [ ] Source or runtime behavior
- [ ] Tests or tooling
- [ ] Public/repository/release boundary
- [ ] Fixture, protocol, or interoperability surface

## Source-alpha and evidence boundary

- [ ] This change preserves the public `PARTIAL` verdict, or explains the
      measured and reviewed evidence required for any different claim.
- [ ] Claims are labeled accurately: source, synthetic, localhost,
      measured hardware, reference peer, or not measured.
- [ ] No synthetic, localhost, built-in-device, archived, placeholder, or
      skip-loud result is presented as field interoperability or product `PASS`.
- [ ] The change remains clean-room: public/authorized inputs and original
      implementation only; no proprietary or confidential material.
- [ ] No secrets, private captures, personal data, hostnames, or internal
      evidence are included in the change or discussion.
- [ ] Private evidence and local workflow records remain outside the tracked
      change.
- [ ] Changes under `Sources/opus-1.5.2/` or `Sources/xs_ref_sw_ed2/` are
      explicitly classified before modification or any public claim.

## Verification

Commands run and result:

```text

```

Checks not run, why, and resulting uncertainty:

```text

```

## Release and reviewer checklist

- [ ] I have described runtime, state, UI, protocol, or compatibility risk.
- [ ] I have identified any changed public claim, fixture provenance, or
      evidence limitation.
- [ ] I have identified any release-boundary impact; this PR does not imply a
      tag, published artifact, supported release, or field readiness.
- [ ] I have listed repository-boundary files affected by this PR.
- [ ] I have requested the applicable source, clean-room, and release review.

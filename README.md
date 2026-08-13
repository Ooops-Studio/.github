# Ooops Studio Community Health

This repository provides the organization-wide GitHub community health defaults used when an Ooops Studio repository does not define its own equivalent file.

It owns contributor guidance, issue and pull request templates, security reporting and the organization profile. Project CI, release workflows, package policies and implementation guidance remain local to each repository.

Issue forms live in `.github/ISSUE_TEMPLATE/` and assign new templated issues to the organization owner. Pull-request review and assignment automation remains repository-local because GitHub Actions workflows are not inherited from an organization `.github` repository.

The public organization profile is maintained in [`profile/README.md`](profile/README.md). Keep its repository and npm package index aligned with the projects that are actually public.

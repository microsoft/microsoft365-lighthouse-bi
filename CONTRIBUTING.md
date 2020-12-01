# Microsoft 365 Lighthouse Business Intelligence Contributor's Guide

Below is our guidance for how to report issues, propose new features, and submit contributions via pull requests (PRs).

## Open Development Workflow

The Microsoft 365 Lighthouse Business Intelligence team is VERY active in this GitHub repository. In fact, we live in it and carry out all our development in the open!

When the team finds issues we file them in the repo. When we propose new ideas or think-up new features, we file new feature requests. When we work on fixes or features, we create branches and work on those improvements. Also, when PRs are reviewed we review in public - including all the good, the bad, and the ugly parts.

The point of doing all this work in public is to ensure that we are holding ourselves to a high degree of transparency, and so that the community sees that we apply the same processes and hold ourselves to the same quality-bar as we do to community-submitted issues and PRs. We also want to make sure that we expose our team culture and "tribal knowledge" that is inherent in any closely-knit team, which often contains considerable value to those new to the project who are trying to figure out "why the heck does this thing look/work like this???"

---

## Reporting Security Issues

**Please do not report security vulnerabilities through public GitHub issues.** Instead, please report them to the Microsoft Security Response Center (MSRC). See [SECURITY.md](./SECURITY.md) for more information.

## Before you start, file an issue

Please follow this simple rule to help us eliminate any unnecessary wasted effort & frustration, and ensure an efficient and effective use of everyone's time - yours, ours, and other community members':

> 👉 If you have a question, think you've discovered an issue, would like to propose a new feature, etc., then find/file an issue **BEFORE** starting work to fix/implement it.

### Search existing issues first

Before filing a new issue, search existing open and closed issues first: This project is moving fast! It is likely someone else has found the problem you're seeing, and someone may be working on or have already contributed a fix!

If no existing item describes your issue/feature, great - please file a new issue:

### File a new Issue

* Don't know whether you're reporting an issue or requesting a feature? File an issue
* Don't understand how to do something? File an issue/Community Guidance Request
* Found an existing issue that describes yours? Great - up vote and add additional commentary / info / repro-steps / etc.
* Got a great idea for a new feature? File an issue/request/idea
* Have a question that you don't see answered in docs, videos, etc.? File an issue
* Want to know if we're planning on building a particular feature? File an issue

When you hit "New Issue", select the type of issue closest to what you want to ask/report

### Complete the template

**Complete the information requested in the issue template, providing as much information as possible**. The more information you provide, the more likely your issue/ask will be understood and implemented. Helpful information includes:

* **If you intend to implement the fix/feature yourself then say so!** If you do not indicate otherwise we will assume that the issue is our to solve, or may label the issue as `Help-Wanted`.
* Prefer error message text where possible or screenshots of errors if text cannot be captured
* **We LOVE detailed repro steps!** What steps do we need to take to reproduce the issue? Assume we love to read repro steps. As much detail as you can stand is probably _barely_ enough detail for us!
* We MUCH prefer text query over screenshots of the query.
* What tools and apps you're using (e.g. VS 2019, VSCode, etc.)

### DO NOT post "+1" comments

> ⚠ DO NOT post "+1", "me too", or similar comments - they just add noise to an issue.

If you don't have any additional info/context to add but would like to indicate that you're affected by the issue, up vote the original issue by clicking its [+😊] button and hitting 👍 (+1) icon. This way we can actually measure how impactful an issue is.

---

## Development

### Fork, Clone, Branch and Create your PR

Once you've discussed your proposed feature/fix/etc. with a team member, and you've agreed an approach or a spec has been written and approved, it's time to start development:

1. Fork the repo if you haven't already
2. Clone your fork locally
3. Create & push a feature branch
4. Create a [Draft Pull Request (PR)](https://github.blog/2019-02-14-introducing-draft-pull-requests/)
5. Work on your changes
6. Build and see if it works. Consult [how to build](./docs/building.md) if you have problems.

### Code Review

When you'd like the team to take a look, (even if the work is not yet fully-complete), mark the PR as 'Ready For Review' so that the team can review your work and provide comments, suggestions, and request changes. It may take several cycles, but the end result will be solid, testable, conformant code that is safe for us to merge.

### Merge

Once your code has been reviewed and approved by the requisite number of team members, it will be merged into the main branch. Once merged, your PR will be automatically closed.

---

## Thank you

Thank you in advance for your contribution! Now, [what's next on the list](https://github.com/microsoft/microsoft365-lighthouse-bi/labels/Help%20Wanted)? 😜

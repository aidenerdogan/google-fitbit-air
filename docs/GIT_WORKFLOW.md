# Solo Git Workflow

Health Passport uses a solo-developer workflow: keep `main` stable, build each task on a focused feature branch, test it, then fast-forward `main`.

## Local Repo Defaults

This checkout is configured with these local Git settings:

```bash
git config --local init.defaultBranch main
git config --local pull.rebase true
git config --local rebase.autoStash true
git config --local fetch.prune true
git config --local merge.ff only
git config --local push.default simple
git config --local branch.autosetuprebase always
```

The important rule is `merge.ff only`: `main` only moves forward to already-tested feature commits. If `main` changes while a feature is open, rebase the feature branch onto `main`, test again, then fast-forward.

## Daily Loop

1. Start from `main`.
2. Create a feature branch for one task.
3. Make small commits with clear messages.
4. Run the relevant tests.
5. Fast-forward `main` to the feature branch.
6. Push `main` to the remote when a remote exists.

## Helper Script

Use the helper script from the repo root:

```bash
./scripts/solo-git.sh status
./scripts/solo-git.sh start passport-timeline-polish
./scripts/solo-git.sh verify
./scripts/solo-git.sh finish
```

`finish` refuses to run from `main`, refuses uncommitted changes, tests before merging, fast-forwards `main`, and pushes only if `origin` exists.

## Local Xcode Files

Xcode may rewrite signing, bundle ID, or plist formatting in tracked files. Keep personal signing values local unless the task is specifically to change shared Xcode settings.

Current local-only files:

```bash
apps/ios/HealthPassport/Config/Info.plist
apps/ios/HealthPassport/HealthPassport.xcodeproj/project.pbxproj
```

Hide local Xcode changes from normal status:

```bash
./scripts/solo-git.sh protect-local-xcode
```

Allow intentional shared Xcode edits again:

```bash
./scripts/solo-git.sh unprotect-local-xcode
```

After unprotecting, inspect the diff carefully and stage only shared project changes.

## Remote Setup

No remote is required for local development, but pushes are blocked until one exists.

After creating a GitHub repository, add it with:

```bash
git remote add origin git@github.com:<owner>/<repo>.git
git push -u origin main
```

After that, `./scripts/solo-git.sh finish` can push `main` automatically.

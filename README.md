# Retain Git History and PR References During Mono-repo Migration
There are several articles about retaining Git history during mono-repo migration. However, I couldn't find any that cover retaining PR references for each commit.

### What do I mean by retaining PR references for each commit?
PR references are information that GitHub holds, not Git itself. While it's possible to retain Git history using existing Git tools, it’s not possible to keep PR references for each commit when migrating an existing repository to a mono-repo. This project aims to solve that problem.

# Approach
- Use git filter-repo to rewrite the commit history:
  - Add PR references to commit messages for each commit.
  - Change all the commit history to be committed under a certain directory, which will be the new directory in the mono-repo.
- Use GitHub’s GraphQL API to retrieve PR references for each commit.

It might seem like a brute-force solution, but sometimes you just have to get the job done! :)

# Steps
## 1. Clone the Repo
You want to perform a clean clone for each history-altering operation. Editing Git history is a dangerous and irreversible process.

The recommended approach is to clone this repo and then clone the repo you want to migrate under this repo. Some intermediate files will be created in this repo, but this won't affect the original repo you want to migrate.

## 2. Add Necessary Information to the Script
In order to proceed, you’ll need to add the following information to the script:

- ORG (GitHub organization name)
- REPO (name of the repository to migrate)
- BRANCH (the branch you want to migrate)
- SUBDIRECTORY_NAME (the directory name for the migrated content in the mono-repo)

## 3. Get All Commits and Their PR References
Run the script gh-mono-repo-migrate.sh, which will automate most of the process.

```bash
bash ../gh-mono-repo-migrate.sh
```
After running this script, the cloned target repo will have PR references for each commit and the correct directory structure for the mono-repo migration.

## 4. Add This Clone as a Remote to the Mono-repo
To integrate the migrated repo into your mono-repo:

```bash
git checkout -b integrate-cool-demo-repo
git remote add temp /path/to/your/tmp/cool-demo
git fetch temp
git merge temp/main --allow-unrelated-histories
```
Now, the target repo is integrated into the mono-repo on a new branch! Push this branch to the mono-repo remote, and you can check the PR references for each commit. If you're happy with the result, you can merge this branch into the main branch of the mono-repo.

# Reference
https://developers.netlify.com/guides/migrating-git-from-multirepo-to-monorepo-without-losing-history/

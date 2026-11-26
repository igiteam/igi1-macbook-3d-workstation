# 🔧 Git Nested Repository Fixer

## Overview

This bash script automatically finds and fixes nested Git repositories within your main Git repository, eliminating the **"repository within repository"** problem that can cause Git operations to fail and confuse version control systems.

## 🔄 Automated Workflow

```text
Main Git Repo ──▶ Find Nested .git folders ──▶ Remove Nested Repos ──▶ Commit Changes
      │                      │                          │                     │
      ▼                      ▼                          ▼                     ▼
Detect nested          Identify all               Remove .git &         Stage & commit
repositories           .git folders               .gitignore            all changes
automatically          recursively                automatically         automatically
```

## 🚀 Key Features

* **🔍 Automatic Detection:** Recursively finds all nested `.git` folders throughout your repository structure.
* **⚡ Smart Filtering:** Intelligently excludes common directories like `node_modules`, build folders, and the main `.git` directory.
* **🔧 Git LFS Awareness:** Detects and reports Git LFS pointer files to prevent accidental data loss.
* **📊 File Analysis:** Counts files in each nested repository to help assess the impact of removal.
* **🤖 Fully Automated:** Automatically removes nested `.git` folders, stages changes, and can commit/push results.
* **🛡️ Safe Operations:** Includes safety checks and user confirmation before destructive operations.

## 🔍 Common Problems Solved

| Problem | Impact |
| :--- | :--- |
| **❌ Git Operations Fail** | Commands like `git add` or `git status` fail due to nested repositories. |
| **🔗 Submodule Confusion** | Nested repos are mistaken for Git submodules, causing tracking issues. |
| **📁 Incomplete Tracking** | Files inside nested repos are ignored and not tracked by the main repository. |
| **🔄 Merge Conflicts** | Nested `.git` folders cause conflicts during merges and rebases. |

## 🛠️ Technical Implementation

* **Bash Scripting** & **File System Operations**
* **Git Commands** & **Git LFS Integration**
* **Recursive Search** (`find`)
* **Interactive User Confirmation**

## 🔧 Script Execution Steps

### Step 1: Repository Validation
Verifies the current directory is a Git repository before proceeding.

```bash
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: This is not a git repository"
    exit 1
fi
```

### Step 2: Git LFS Detection
Checks for Git LFS availability and reports on LFS pointer files.

```bash
if git lfs env | grep -q "git-lfs"; then
    echo "✓ Git LFS is available"
    LFS_AVAILABLE=true
else
    echo "⚠ Git LFS is not available"
    LFS_AVAILABLE=false
fi
```

### Step 3: Recursive Search
Finds all `.git` folders while excluding common directories and the main repository.

```bash
find . -name ".git" -type d | while read gitdir; do
    dirpath=$(dirname "$gitdir")
    # Skip main .git and common exclusions
    if [ "$dirpath" = "." ] || [[ "$dirpath" == *"/.git/"* ]] || \
       [[ "$dirpath" == *"/node_modules/"* ]] || [[ "$dirpath" == *"/build/"* ]]; then
        continue
    fi
```

### Step 4: Analysis & Reporting
Analyzes each nested repository and provides detailed file and Git LFS counts.

```bash
lfs_files=$(find "$dirpath" -type f -exec file {} \; | grep -i "git lfs" | wc -l)
file_count=$(find "$dirpath" -type f | wc -l)
echo "  ⚠ Contains $lfs_files Git LFS pointer files"
echo "  📁 Contains $file_count files"
```

### Step 5: Automatic Cleanup
Removes nested `.git` folders and `.gitignore` files, then stages changes.

```bash
rm -rf "$gitdir"
rm -f "$dirpath/.gitignore"
git add "$dirpath"
((fixed_count++))
echo "  ✓ Removed .git folder from $dirpath"
```

### Step 6: Commit & Push
Automatically commits changes and optionally pushes to the remote repository.

```bash
git commit -m "Fix nested repositories: removed $fixed_count nested .git folders"
git push
```

## 🎯 Smart Exclusion Patterns

The script intelligently skips directories that should not be processed:

```text
- "."                 # Main repository
- "*/node_modules/*"  # Node.js dependencies
- "*/build/*"         # Build directories
- "*/.git/*"          # Git internal directories
```

## ⚠️ Safety Features

* **Git LFS Protection:** Detects Git LFS pointer files and warns about them before removal, preventing accidental loss of large files managed by Git LFS.
* **User Confirmation:** Prompts for confirmation before committing and pushing changes, giving you control over the final steps.
* **File Counting:** Counts files in each nested repository so you can assess the impact before removal.

## 🚀 Usage Examples

### Basic Execution

```bash
chmod +x fix_nested_repos.sh
./fix_nested_repos.sh
```

### Expected Output

```text
=== Finding and fixing nested Git repositories ===
✓ Git LFS is available

Found nested repo: ./subproject
  ⚠ Contains 2 Git LFS pointer files
  📁 Contains 47 files
  Automatically removing .git folder...
  ✓ Removed .git folder from ./subproject

=== Summary ===
Found 1 nested repositories
Fixed 1 nested repositories

=== Current status ===
On branch main
Changes to be committed:
  (use "git reset HEAD ..." to unstage)
        new file:   subproject/file1.py
        new file:   subproject/file2.py

Automatically committing changes...
✓ Changes committed
Automatically pushing changes...
✓ Changes pushed
Done!
```

## 🔧 Solutions Provided & Benefits

* **✅ Unified Repository:** Every file in previously nested directories becomes part of the main repository's version control.
* **✅ Clean Git Operations:** Eliminates errors and conflicts caused by nested repositories during Git commands, merges, and rebases.
* **✅ Proper Submodule Alternative:** Provides a straightforward alternative to Git submodules when you want all code in one repository.
* **✅ Reliable CI/CD:** Build systems and deployment pipelines run smoothly without nested repository issues.

## 🎯 Perfect Use Cases

* **Monorepo Migration:** Consolidating multiple repositories into a single monorepo.
* **Project Mergers:** Combining separate projects that became nested over time.
* **CI/CD Fixes:** Resolving build failures caused by nested Git repositories.
* **Team Collaboration:** Ensuring all team members share a consistent repository structure.
* **Repository Cleanup:** Periodic maintenance to keep repository structure clean.

## 🔍 Alternative Approaches

While this script merges nested repositories directly into your main repository, you can also manage sub-projects using:

### Git Submodules

```bash
# Convert nested repo to a submodule
git submodule add <repository-url> <path>
git commit -m "Add submodule"
```

### Git Subtrees

```bash
# Merge nested repo as a subtree
git subtree add --prefix=<path> <repository-url> <branch> --squash
```

## 🎉 Final Result

Running this script leaves you with a clean, unified Git repository:
* All nested `.git` folders removed
* All files properly tracked by the main repository
* Git LFS pointers detected and reported
* Changes committed and pushed cleanly with a clear summary

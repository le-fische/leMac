# leMac Monorepo Developer & Migration Guide 

This guide explains how to migrate any existing Mac project into the `leMac` monorepo, work on it, and commit/push changes to GitHub.

---

## 🏗 Repository Structure

```
leMac/
├── leNotch/              # Dynamic Island & Notch utility app
├── MiniBar/              # Lightweight collapsible menu bar manager
├── <YourProjectName>/    # Your newly migrated project
├── README.md             # Monorepo catalog of all Mac mini projects
└── MONOREPO_GUIDE.md     # This developer guide
```

---

## 📦 Step-by-Step: How to Move a Project into `leMac`

### Step 1: Clean Up the Source Project First
Before moving your project folder into `leMac`, delete heavy build caches, DerivedData, and any nested `.git` folders to keep the repo clean and lightweight:

```bash
cd "/Users/le/Documents/Projects/<YourProjectName>"

# Remove existing build artifacts
rm -rf build DerivedData .build Pods

# Remove nested git history (if you want it fully unified inside leMac)
rm -rf .git
```

---

### Step 2: Move the Project into `leMac`

Move the project directory into `/Users/le/Documents/Projects/leMac/`:

```bash
mv "/Users/le/Documents/Projects/<YourProjectName>" "/Users/le/Documents/Projects/leMac/<YourProjectName>"
```

*(Optional)* If you or any existing scripts/aliases rely on the old folder path, create a symlink:
```bash
ln -s "/Users/le/Documents/Projects/leMac/<YourProjectName>" "/Users/le/Documents/Projects/<YourProjectName>"
```

---

### Step 3: Add a Project `README.md`
Inside `/Users/le/Documents/Projects/leMac/<YourProjectName>/README.md`, ensure there is a brief summary:
* Project title & purpose
* Tech stack (Swift, SwiftUI, AppKit, etc.)
* How to build and run (`xcodebuild`, `swift run`, or `./build.sh`)

---

### Step 4: Register in Root `README.md`
Add a 1-line entry in the Projects Catalog table in `/Users/le/Documents/Projects/leMac/README.md`:

```markdown
| [**YourProject**](YourProject/) | Brief 1-line description of what it does. | Swift, AppKit | Active |
```

---

## 🛠 Working on Projects inside `leMac`

### Opening in Xcode:
You can open any sub-project directly in Xcode:
```bash
# Example for leNotch
open /Users/le/Documents/Projects/leMac/leNotch/boringNotch.xcodeproj

# Example for your project
open /Users/le/Documents/Projects/leMac/<YourProjectName>/<YourProjectName>.xcodeproj
```

### Building via Terminal:
Always specify `build/` inside `leMac` or your sub-folder to keep derived data isolated:
```bash
cd /Users/le/Documents/Projects/leMac/<YourProjectName>

# Xcode project build
xcodebuild -project <YourProjectName>.xcodeproj -scheme <SchemeName> -configuration Release -derivedDataPath ./build build

# Swift package build
swift build -c release
```

---

## 🚀 Committing and Pushing to GitHub

Since `leMac` is a single unified monorepo ([https://github.com/le-fische/leMac](https://github.com/le-fische/leMac)), you commit and push everything from the root:

```bash
cd /Users/le/Documents/Projects/leMac

# 1. Review status
git status

# 2. Stage changes (you can stage everything or just your project folder)
git add <YourProjectName>/
git add README.md

# 3. Commit with a descriptive message
git commit -m "Add <YourProjectName> to leMac monorepo"

# 4. Push directly to main branch
git push origin main
```

---

## 🤖 Instructions for AI Agents (Prompt Template)

When instructing an AI assistant to work on any project in `leMac`, give it this prompt:

> *"This project is part of the `leMac` monorepo located at `/Users/le/Documents/Projects/leMac/<ProjectName>`. Please work directly within that directory, do not create external folders, and make sure any commits are pushed to `leMac` on branch `main`."*

# Setting Up GitHub Repository

Follow these steps to push this repository to GitHub.

## Option 1: Using GitHub CLI (Recommended)

If you have GitHub CLI (`gh`) installed:

```bash
cd ~/cursor_workspace/nordvpn_helper

# Create repository on GitHub (will prompt for visibility: public/private)
gh repo create nordvpn --source=. --public --push

# Or for private repository:
# gh repo create nordvpn --source=. --private --push
```

## Option 2: Manual Setup

### Step 1: Create Repository on GitHub

1. Go to https://github.com/new
2. Repository name: `nordvpn` (or your preferred name)
3. Description: "Automatically pauses NordVPN when connecting to WiFi networks with captive portals"
4. Choose Public or Private
5. **DO NOT** initialize with README, .gitignore, or license (we already have these)
6. Click "Create repository"

### Step 2: Add Remote and Push

```bash
cd ~/cursor_workspace/nordvpn_helper

# Add your GitHub username here
GITHUB_USERNAME="ashwinraghavachari"

# Add remote (replace YOUR_USERNAME with your actual GitHub username)
git remote add origin https://github.com/${GITHUB_USERNAME}/nordvpn.git

# Or if using SSH:
# git remote add origin git@github.com:${GITHUB_USERNAME}/nordvpn.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### Step 3: Verify

Check your repository on GitHub - you should see all files uploaded.

## Quick Command Reference

```bash
# Check current status
git status

# View commit history
git log --oneline

# View remote
git remote -v

# Push changes
git push

# Pull changes (if working from multiple locations)
git pull
```

#!/bin/bash

# Quick script to push to GitHub repository 'nordvpn'

set -e

cd "$(dirname "$0")"

echo "Pushing to GitHub repository 'nordvpn'..."
echo ""

# Get GitHub username from user or git config
GITHUB_USER=$(git config --get user.name 2>/dev/null || echo "")

if [ -z "$GITHUB_USER" ]; then
    read -p "Enter your GitHub username: " GITHUB_USER
fi

if [ -z "$GITHUB_USER" ]; then
    echo "Error: GitHub username required"
    exit 1
fi

REPO_URL="https://github.com/${GITHUB_USER}/nordvpn.git"

echo "Repository URL: $REPO_URL"
echo ""

# Check if remote exists
if git remote get-url origin &>/dev/null; then
    echo "Remote 'origin' already exists. Updating..."
    git remote set-url origin "$REPO_URL"
else
    echo "Adding remote 'origin'..."
    git remote add origin "$REPO_URL"
fi

# Ensure we're on main branch
git branch -M main 2>/dev/null || true

# Push to GitHub
echo "Pushing to GitHub..."
git push -u origin main

echo ""
echo "✅ Successfully pushed to GitHub!"
echo "View your repository at: $REPO_URL"

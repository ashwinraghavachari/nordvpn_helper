#!/bin/bash

# Script to set up GitHub repository for NordVPN Captive Portal Handler

set -e

REPO_NAME="nordvpn"
CURRENT_DIR=$(pwd)

echo "=========================================="
echo "GitHub Repository Setup"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "nordvpn_captive_portal_handler.sh" ]; then
    echo "Error: Please run this script from the nordvpn_helper directory"
    exit 1
fi

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "Error: Git repository not initialized"
    exit 1
fi

# Check for GitHub CLI
if command -v gh &> /dev/null; then
    echo "✅ GitHub CLI found"
    echo ""
    echo "Choose an option:"
    echo "1) Create public repository"
    echo "2) Create private repository"
    echo "3) Skip (manual setup)"
    read -p "Enter choice [1-3]: " choice
    
    case $choice in
        1)
            echo "Creating public repository..."
            gh repo create "$REPO_NAME" --source=. --public --push
            echo "✅ Repository created and pushed!"
            ;;
        2)
            echo "Creating private repository..."
            gh repo create "$REPO_NAME" --source=. --private --push
            echo "✅ Repository created and pushed!"
            ;;
        3)
            echo "Skipping GitHub CLI setup"
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
else
    echo "GitHub CLI not found. Using manual setup."
    echo ""
    read -p "Enter your GitHub username: " GITHUB_USERNAME
    
    if [ -z "$GITHUB_USERNAME" ]; then
        echo "Error: GitHub username required"
        exit 1
    fi
    
    echo ""
    echo "Please create the repository on GitHub first:"
    echo "1. Go to: https://github.com/new"
    echo "2. Repository name: $REPO_NAME"
    echo "3. Choose Public or Private"
    echo "4. DO NOT initialize with README, .gitignore, or license"
    echo "5. Click 'Create repository'"
    echo ""
    read -p "Press Enter after you've created the repository..."
    
    # Check if remote already exists
    if git remote get-url origin &> /dev/null; then
        echo "Remote 'origin' already exists. Removing..."
        git remote remove origin
    fi
    
    # Add remote
    echo "Adding remote..."
    git remote add origin "https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"
    
    # Set branch to main
    git branch -M main 2>/dev/null || true
    
    # Push
    echo "Pushing to GitHub..."
    git push -u origin main
    
    echo ""
    echo "✅ Repository pushed to GitHub!"
    echo "View it at: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="

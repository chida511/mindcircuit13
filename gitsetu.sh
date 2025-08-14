#!/bin/bash
set -e

# Variables
GIT_USER="chida511"
GIT_REPO="mindcircuit13"
BRANCH="main"
COMMIT_MSG="Test commit: minor change for pipeline testing"
REPO_PATH="/root/devops/"

# Navigate to your project directory
cd $REPO_PATH || { echo "Directory $REPO_PATH not found!"; exit 1; }

# Ensure this is a git repository
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
    git remote add origin https://github.com/$GIT_USER/$GIT_REPO.git
fi

# Pull latest changes
echo "Pulling latest changes from remote..."
git checkout $BRANCH || git checkout -b $BRANCH
git pull origin $BRANCH

# Make a small test change (create a temp file)
echo "This is a test change for Git workflow" >> testfile.txt

# Stage changes
echo "Staging changes..."
git add .

# Commit changes
echo "Committing changes..."
git commit -m "$COMMIT_MSG" || echo "No changes to commit"

# Push to GitHub
echo "Pushing changes to GitHub..."
git push https://github.com/$GIT_USER/$GIT_REPO.git $BRANCH

echo "✅ Git workflow completed successfully!"


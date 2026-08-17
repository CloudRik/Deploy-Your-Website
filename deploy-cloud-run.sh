#!/bin/bash
# ==============================================================================
# Google Cloud Skill Lab: Deploy Your Website on Cloud Run
# Automated One-Click Solver Script
# ==============================================================================

set -e # Exit immediately if a command exits with a non-zero status

echo "=================================================="
echo " Starting Google Cloud Run Lab Automation Script "
echo "=================================================="

# Auto-detect Project ID & Region
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
LOCATION=$(gcloud config get-value compute/region 2>/dev/null)

# Fallback values if empty
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

if [ -z "$LOCATION" ]; then
    LOCATION="europe-west1"
fi

echo ""
echo "Configuration Summary:"
echo "  Project ID : $PROJECT_ID"
echo "  Region     : $LOCATION"
echo "=================================================="
echo ""

# --- Task 1: Clone the source repository & install dependencies ---
echo "[Task 1/6] Cloning source repository..."
cd ~
if [ ! -d "monolith-to-microservices" ]; then
    git clone https://github.com/googlecodelabs/monolith-to-microservices.git
fi
cd ~/monolith-to-microservices

echo "[Task 1/6] Running setup script..."
./setup.sh

# --- Task 2: Create Docker Repository & Build Image v1.0.0 ---
echo "[Task 2/6] Enabling Google Cloud APIs..."
gcloud services enable artifactregistry.googleapis.com \
                       cloudbuild.googleapis.com \
                       run.googleapis.com

echo "[Task 2/6] Creating Artifact Registry repository..."
gcloud artifacts repositories create monolith-demo \
    --repository-format=docker \
    --location=$LOCATION \
    --description="Docker repository for monolith demo" || true

echo "[Task 2/6] Configuring Docker authentication..."
gcloud auth configure-docker $LOCATION-docker.pkg.dev --quiet

echo "[Task 2/6] Building image v1.0.0 with Cloud Build..."
cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag $LOCATION-docker.pkg.dev/${PROJECT_ID}/monolith-demo/monolith:1.0.0

# --- Task 3: Deploy Container to Cloud Run ---
echo "[Task 3/6] Deploying monolith service (v1.0.0) to Cloud Run..."
gcloud run deploy monolith \
    --image $LOCATION-docker.pkg.dev/${PROJECT_ID}/monolith-demo/monolith:1.0.0 \
    --region $LOCATION \
    --allow-unauthenticated

# --- Task 4: Create Revision with Lower Concurrency ---
echo "[Task 4/6] Updating deployment with concurrency = 1..."
gcloud run deploy monolith \
    --image $LOCATION-docker.pkg.dev/${PROJECT_ID}/monolith-demo/monolith:1.0.0 \
    --region $LOCATION \
    --concurrency 1

# --- Task 5: Make Changes & Build Version 2.0.0 ---
echo "[Task 5/6] Updating source code..."
cd ~/monolith-to-microservices/react-app/src/pages/Home
if [ -f "index.js.new" ]; then
    mv index.js.new index.js
fi

echo "[Task 5/6] Building React app..."
cd ~/monolith-to-microservices/react-app
npm run build:monolith

echo "[Task 5/6] Submitting build for image v2.0.0..."
cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag $LOCATION-docker.pkg.dev/${PROJECT_ID}/monolith-demo/monolith:2.0.0

# --- Task 6: Zero Downtime Update to Version 2.0.0 ---
echo "[Task 6/6] Deploying version 2.0.0 to Cloud Run..."
gcloud run deploy monolith \
    --image $LOCATION-docker.pkg.dev/${PROJECT_ID}/monolith-demo/monolith:2.0.0 \
    --region $LOCATION

echo ""
echo "=================================================="
echo " 🎉 LAB COMPLETED SUCCESSFULLY! Check your score. "
echo "=================================================="

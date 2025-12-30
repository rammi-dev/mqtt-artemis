#!/bin/bash
# =============================================================================
# Build and Push IoT Load Tester
# =============================================================================
# Builds Docker image and pushes to Google Artifact Registry
# Only keeps the latest version to minimize storage costs
#
# Usage:
#   ./scripts/iot-load-tester/build.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../../apps/iot-load-tester"

# Configuration
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
REGION="us-central1"
REPOSITORY="iot-load-tester"
IMAGE_NAME="iot-load-tester"
TAG="latest"

# Full image path
REGISTRY="$REGION-docker.pkg.dev"
FULL_IMAGE="$REGISTRY/$PROJECT_ID/$REPOSITORY/$IMAGE_NAME:$TAG"

echo "=============================================="
echo "Building IoT Load Tester"
echo "=============================================="
echo "Project:    $PROJECT_ID"
echo "Region:     $REGION"
echo "Repository: $REPOSITORY"
echo "Image:      $FULL_IMAGE"
echo "=============================================="

# Check if repository exists, create if not
echo "Checking Artifact Registry repository..."
if ! gcloud artifacts repositories describe "$REPOSITORY" --location="$REGION" &>/dev/null; then
    echo "Creating Artifact Registry repository: $REPOSITORY"
    gcloud artifacts repositories create "$REPOSITORY" \
        --repository-format=docker \
        --location="$REGION" \
        --description="IoT Load Testing Tool images"
    
    # Set cleanup policy to keep only 1 version
    echo "Setting cleanup policy to keep only latest version..."
    cat > /tmp/cleanup-policy.json << 'EOF'
{
  "name": "keep-latest-only",
  "action": {"type": "Delete"},
  "condition": {
    "tagState": "any",
    "olderThan": "0s"
  },
  "mostRecentVersions": {
    "keepCount": 1
  }
}
EOF
    gcloud artifacts repositories set-cleanup-policies "$REPOSITORY" \
        --location="$REGION" \
        --policy=/tmp/cleanup-policy.json \
        --no-dry-run 2>/dev/null || echo "Note: Cleanup policy requires gcloud >= 450.0.0"
fi

# Configure Docker authentication
echo "Configuring Docker authentication..."
gcloud auth configure-docker "$REGISTRY" --quiet

# Build the image from app directory
echo "Building Docker image..."
docker build -t "$FULL_IMAGE" "$APP_DIR"

# Push to Artifact Registry
echo "Pushing to Artifact Registry..."
docker push "$FULL_IMAGE"

# Cleanup old untagged images
echo "Cleaning up old images..."
OLD_DIGESTS=$(gcloud artifacts docker images list "$REGISTRY/$PROJECT_ID/$REPOSITORY/$IMAGE_NAME" \
    --include-tags \
    --format="get(digest)" \
    --filter="NOT tags:*" 2>/dev/null || true)

if [ -n "$OLD_DIGESTS" ]; then
    for digest in $OLD_DIGESTS; do
        echo "  Deleting untagged image: $digest"
        gcloud artifacts docker images delete "$REGISTRY/$PROJECT_ID/$REPOSITORY/$IMAGE_NAME@$digest" --quiet 2>/dev/null || true
    done
fi

echo ""
echo "=============================================="
echo "Build Complete!"
echo "=============================================="
echo "Image: $FULL_IMAGE"
echo ""
echo "To deploy to GKE:"
echo "  INGRESS_IP=\$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo "  helm upgrade --install iot-load-tester charts/iot-load-tester -n edge \\"
echo "    --set image.repository=$REGISTRY/$PROJECT_ID/$REPOSITORY/$IMAGE_NAME \\"
echo "    --set image.tag=$TAG \\"
echo "    --set domain=\"\${INGRESS_IP}.nip.io\""

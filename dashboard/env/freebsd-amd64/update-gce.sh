#!/bin/bash
set -x -e

readonly PROJECT=bold-impulse-830
readonly TARBALL=freebsd-10.1-amd64-gce.tar.gz
readonly GCSBUCKET=xinu-tv-go-builder-data
readonly GCSURL=gs://${GCSBUCKET:?}/${TARBALL:?}
readonly GCEZONE=us-central1-f
readonly GCLOUD="gcloud compute -q --project=${PROJECT:?} --zone=${GCEZONE:?}"

# Upload new raw disk image to GCS.
gsutil cp -a public-read ${TARBALL:?} ${GCSURL:?}

# Rebuild GCE from GCS image.
${GCLOUD:?} images delete freebsd-10-1-amd64 
${GCLOUD:?} images create freebsd-10-1-amd64 --source-uri ${GCSURL:?}

# Restart VM.  Delete allowed to fail if no VM running.
${GCLOUD:?} instances delete freebsd-10-1 || true
${GCLOUD:?} instances create --image=freebsd-10-1-amd64 freebsd-10-1
sleep 5
# See if there's console output.
${GCLOUD:?} instances get-serial-port-output freebsd-10-1


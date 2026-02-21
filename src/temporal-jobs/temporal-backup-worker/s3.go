// ============================================================================
// S3 Upload Activities
// ============================================================================
//
// Package: main
// Purpose: Upload backup files to S3-compatible storage for off-site redundancy
//
// These activities upload locally-created backups to the s3-orchestrator service,
// which proxies to OCI Object Storage. This provides off-site backup redundancy
// beyond the local /mnt/gdrive NFS share.
//
// Activities:
//   - UploadToS3: Uploads a single backup file to S3 with a given key prefix
//   - CleanupOldS3Backups: Removes S3 objects older than the retention period
//
// Configuration (environment variables):
//   - S3_ENDPOINT: S3-compatible endpoint URL (e.g., http://s3-orchestrator.service.consul:9000)
//   - S3_BUCKET: Target bucket name (e.g., "unified")
//   - S3_ACCESS_KEY: Access key ID for authentication
//   - S3_SECRET_KEY: Secret access key for authentication
//
// Author: Alex
// Repository: munchbox/temporal-backup-worker
// ============================================================================

package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	s3types "github.com/aws/aws-sdk-go-v2/service/s3/types"
	"go.temporal.io/sdk/activity"
)

// newS3Client creates an S3 client configured for the s3-orchestrator endpoint.
func newS3Client() (*s3.Client, error) {
	endpoint := os.Getenv("S3_ENDPOINT")
	accessKey := os.Getenv("S3_ACCESS_KEY")
	secretKey := os.Getenv("S3_SECRET_KEY")

	if endpoint == "" || accessKey == "" || secretKey == "" {
		return nil, fmt.Errorf("S3_ENDPOINT, S3_ACCESS_KEY, and S3_SECRET_KEY must be set")
	}

	return s3.New(s3.Options{
		BaseEndpoint: &endpoint,
		Region:       "us-east-1", // required but ignored by s3-orchestrator
		Credentials:  credentials.NewStaticCredentialsProvider(accessKey, secretKey, ""),
		UsePathStyle: true,
	}), nil
}

// UploadToS3 uploads a local backup file to S3 storage.
//
// The file is uploaded with a key constructed from the prefix and the original
// filename. For example, a file at /mnt/gdrive/nomad-snapshots/nomad-20260221.snap
// with prefix "backups/nomad" becomes "backups/nomad/nomad-20260221.snap".
//
// If the upload fails with 507 InsufficientStorage (quota exceeded), the oldest
// backup under the same key prefix is deleted and the upload is retried. This
// repeats up to 3 times to free enough space.
//
// Parameters:
//   - localPath: Full path to the local backup file
//   - keyPrefix: S3 key prefix (e.g., "backups/nomad", "backups/consul", "backups/postgres")
//
// Returns:
//   - string: The S3 key where the file was uploaded
//   - error: Non-nil if the upload fails
func UploadToS3(ctx context.Context, localPath string, keyPrefix string) (string, error) {
	logger := activity.GetLogger(ctx)

	bucket := os.Getenv("S3_BUCKET")
	if bucket == "" {
		return "", fmt.Errorf("S3_BUCKET must be set")
	}

	client, err := newS3Client()
	if err != nil {
		return "", err
	}

	info, err := os.Stat(localPath)
	if err != nil {
		return "", fmt.Errorf("failed to stat file %s: %w", localPath, err)
	}

	key := keyPrefix + "/" + filepath.Base(localPath)

	const maxEvictions = 3
	for attempt := 0; attempt <= maxEvictions; attempt++ {
		file, err := os.Open(localPath)
		if err != nil {
			return "", fmt.Errorf("failed to open file %s: %w", localPath, err)
		}

		logger.Info("Uploading to S3", "key", key, "size_bytes", info.Size(), "bucket", bucket)

		_, err = client.PutObject(ctx, &s3.PutObjectInput{
			Bucket:        &bucket,
			Key:           &key,
			Body:          file,
			ContentLength: aws.Int64(info.Size()),
		})
		file.Close()

		if err == nil {
			logger.Info("S3 upload complete", "key", key, "size_bytes", info.Size())
			return key, nil
		}

		if !isQuotaError(err) || attempt == maxEvictions {
			return "", fmt.Errorf("failed to upload %s to s3://%s/%s: %w", localPath, bucket, key, err)
		}

		logger.Warn("S3 quota exceeded, evicting oldest backup", "prefix", keyPrefix, "attempt", attempt+1)
		if evictErr := deleteOldestObject(ctx, client, bucket, keyPrefix, key); evictErr != nil {
			return "", fmt.Errorf("failed to upload (quota exceeded) and could not evict: upload: %w, evict: %v", err, evictErr)
		}
	}

	return "", fmt.Errorf("failed to upload %s after %d eviction attempts", localPath, maxEvictions)
}

// isQuotaError checks whether an S3 error is a 507 InsufficientStorage response.
func isQuotaError(err error) bool {
	return strings.Contains(err.Error(), "InsufficientStorage") || strings.Contains(err.Error(), "507")
}

// deleteOldestObject finds and deletes the oldest object under the given prefix,
// skipping the key currently being uploaded.
func deleteOldestObject(ctx context.Context, client *s3.Client, bucket, prefix, skipKey string) error {
	logger := activity.GetLogger(ctx)

	searchPrefix := prefix + "/"
	var objects []s3types.Object

	paginator := s3.NewListObjectsV2Paginator(client, &s3.ListObjectsV2Input{
		Bucket: &bucket,
		Prefix: &searchPrefix,
	})
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return fmt.Errorf("failed to list objects under %s: %w", prefix, err)
		}
		for _, obj := range page.Contents {
			k := aws.ToString(obj.Key)
			if k != skipKey && !strings.HasSuffix(k, "/") {
				objects = append(objects, obj)
			}
		}
	}

	if len(objects) == 0 {
		return fmt.Errorf("no objects to evict under %s", prefix)
	}

	sort.Slice(objects, func(i, j int) bool {
		return objects[i].LastModified.Before(*objects[j].LastModified)
	})

	oldest := aws.ToString(objects[0].Key)
	logger.Info("Evicting oldest S3 backup for space", "key", oldest, "age_days",
		int(time.Since(*objects[0].LastModified).Hours()/24))

	_, err := client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: &bucket,
		Key:    &oldest,
	})
	if err != nil {
		return fmt.Errorf("failed to delete %s: %w", oldest, err)
	}

	return nil
}

// CleanupOldS3Backups removes backup objects from S3 older than the retention period.
//
// Lists all objects under the "backups/" prefix and deletes those whose
// LastModified time is older than the retention period.
//
// Parameters:
//   - retentionDays: Number of days to retain S3 backups
//
// Returns:
//   - error: Non-nil if listing or deletion fails
func CleanupOldS3Backups(ctx context.Context, retentionDays int) error {
	logger := activity.GetLogger(ctx)

	bucket := os.Getenv("S3_BUCKET")
	if bucket == "" {
		return fmt.Errorf("S3_BUCKET must be set")
	}

	client, err := newS3Client()
	if err != nil {
		return err
	}

	cutoff := time.Now().AddDate(0, 0, -retentionDays)
	prefix := "backups/"
	deleted := 0

	logger.Info("Cleaning up old S3 backups", "retention_days", retentionDays, "cutoff", cutoff)

	paginator := s3.NewListObjectsV2Paginator(client, &s3.ListObjectsV2Input{
		Bucket: &bucket,
		Prefix: &prefix,
	})

	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return fmt.Errorf("failed to list S3 objects: %w", err)
		}

		for _, obj := range page.Contents {
			if obj.LastModified != nil && obj.LastModified.Before(cutoff) {
				key := aws.ToString(obj.Key)

				// Only delete backup files, not prefixes
				if strings.HasSuffix(key, "/") {
					continue
				}

				_, err := client.DeleteObject(ctx, &s3.DeleteObjectInput{
					Bucket: &bucket,
					Key:    obj.Key,
				})
				if err != nil {
					logger.Warn("Failed to delete old S3 backup", "key", key, "error", err)
					continue
				}

				logger.Info("Deleted old S3 backup", "key", key,
					"age_days", int(time.Since(*obj.LastModified).Hours()/24))
				deleted++
			}
		}
	}

	logger.Info("S3 cleanup complete", "deleted_count", deleted)
	return nil
}

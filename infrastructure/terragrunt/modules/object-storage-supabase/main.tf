# -----------------------------------------------------------------------------
# OBJECT-STORAGE-SUPABASE MODULE
# -----------------------------------------------------------------------------
#
# Manages a Supabase Storage bucket via the management API (the provider
# exchanges the PAT for a project service-role JWT). Used because Supabase's
# S3 endpoint is path-prefixed and doesn't implement the bucket sub-APIs, so
# neither the aws nor minio S3 routes work.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "supabase_storage_bucket" "this" {
  project_ref        = var.project_ref
  name               = var.bucket_name
  public             = var.public
  file_size_limit    = var.file_size_limit
  allowed_mime_types = var.allowed_mime_types
}

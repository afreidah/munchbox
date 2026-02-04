# Kavita

Self-hosted digital reading platform with a built-in web reader supporting
EPUB, PDF, and comic book formats. Serves the book library that Readarr
populates on the gdrive-secondary NFS mount, offering progress tracking and
user management. Runs on an Oracle Cloud ARM node since it has no dependency
on local storage.

## Dependencies

- **Readarr** -- populates the book library that Kavita serves

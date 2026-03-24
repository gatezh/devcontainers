# Adding a New Image

## Devcontainer Image

1. Create `devcontainer-{name}/.devcontainer/Dockerfile`
2. Create `devcontainer-{name}/.devcontainer/devcontainer.json`
3. Create `devcontainer-{name}/README.md`
4. Create `.github/workflows/build-devcontainer-{name}.yml`
5. Update root `README.md` with new image entry

## Standalone Docker Image

1. Create `{image-name}/Dockerfile` (no `.devcontainer/` subdirectory)
2. Create `{image-name}/README.md`
3. Create `.github/workflows/build-{image-name}.yml`
4. Update root `README.md` with new image entry

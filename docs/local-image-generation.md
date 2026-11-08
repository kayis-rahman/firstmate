# Local image generation

`bin/fm-image-gen.sh` is the only supported command for a worker that generates a local image.
It launches the built Go helper from `bin/go-pilot/image-gen`.
Build the helper with `bin/fm-go-pilot-build.sh` after updating Firstmate.
The wrapper centralizes the local machine rules instead of leaving workers to invoke an engine directly.

## Engines

The helper reads MLX Serve at `http://127.0.0.1:11234/v1/models` and selects a model only when its advertised capabilities include image generation.
MLX Serve currently hosts text and decision models, so it is not selected unless an image-capable model is installed.
The mflux adapter uses the already-installed Z-Image Turbo command with its local model directory, low-RAM mode, and offline cache.
It does not install, download, or remove a model or engine.

Pass `--engine auto` to prefer an image-capable MLX Serve model and otherwise use the configured mflux root.
Pass `--engine mflux` or `--engine mlx-serve` only to require that engine.
MLX Serve output is capped at 1536 px per side.
The verified mflux command accepts one image reference per job.

## Guards

Before starting a job, the helper refuses when free memory from `memory_pressure` is below 10 percent.
A state lock prevents another image job from running concurrently.
Every started job appends its UTC time, engine, output path, and exit result to the local image-generation log under `state/`.

## Configuration

[`config/image-engine`](configuration.md#local-image-generation-configimage-engine) is local and gitignored.
Its first line is `auto`, `mflux`, or `mlx-serve`.
Its second line is the mflux installation root.
No machine path belongs in tracked files.

## Adding an engine

Add a Go adapter with explicit capability detection, guard coverage, and a stubbed-engine Go test.
Do not make workers invoke a new engine directly.
Document its configuration contract in `docs/configuration.md` and keep this page focused on current operator behavior.

## MLX-Serve-only rule

Use MLX Serve alone when it has an image-capable model and no explicit exception applies.
The captain explicitly waived that rule for the Ironveil concept and art work because the installed local mflux Z-Image Turbo setup was the approved image engine.
A later exception requires the captain's explicit approval.

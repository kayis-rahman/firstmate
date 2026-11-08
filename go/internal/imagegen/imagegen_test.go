package imagegen

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type fakeRunner struct {
	models string
	memory string
	run    []string
}

func (fake *fakeRunner) Output(name string, args ...string) ([]byte, error) {
	switch name {
	case "curl":
		if strings.HasSuffix(args[len(args)-1], "/v1/models") {
			return []byte(fake.models), nil
		}
		return []byte(`{"data":[{"b64_json":"UE5H"}]}`), nil
	case "memory_pressure":
		return []byte(fake.memory), nil
	}
	return nil, errors.New("unexpected command")
}

func (fake *fakeRunner) Run(command, _ []string) error {
	fake.run = command
	for index, arg := range command {
		if arg == "--output" {
			return os.WriteFile(command[index+1], []byte("PNG"), 0o644)
		}
	}
	return errors.New("missing output")
}

func world(t *testing.T, engine string) (paths, string) {
	t.Helper()
	root := t.TempDir()
	mflux := filepath.Join(root, "mflux")
	if err := os.MkdirAll(filepath.Join(mflux, "venv", "bin"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(mflux, "model"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(mflux, "venv", "bin", "mflux-generate-z-image-turbo"), nil, 0o755); err != nil {
		t.Fatal(err)
	}
	config := filepath.Join(root, "config")
	if err := os.MkdirAll(config, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(config, "image-engine"), []byte(engine+"\n"+mflux+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	return paths{config: config, state: filepath.Join(root, "state")}, mflux
}

func options(root string) Options {
	return Options{Prompt: "test", Out: filepath.Join(root, "out.png"), Engine: "auto"}
}

func TestRefusesLowMemory(t *testing.T) {
	locations, _ := world(t, "mflux")
	runner := &fakeRunner{memory: "System-wide memory free percentage: 9%"}
	err := run(options(t.TempDir()), locations, runner)
	if err == nil || !strings.Contains(err.Error(), "free memory is 9%") {
		t.Fatalf("expected measured low-memory refusal, got %v", err)
	}
}

func TestRefusesExistingLock(t *testing.T) {
	locations, _ := world(t, "mflux")
	if err := os.MkdirAll(filepath.Join(locations.state, "image-gen.lock"), 0o755); err != nil {
		t.Fatal(err)
	}
	runner := &fakeRunner{memory: "System-wide memory free percentage: 74%"}
	err := run(options(t.TempDir()), locations, runner)
	if err == nil || !strings.Contains(err.Error(), "another image job") {
		t.Fatalf("expected lock refusal, got %v", err)
	}
}

func TestAutoSelection(t *testing.T) {
	locations, mflux := world(t, "auto")
	root := t.TempDir()
	runner := &fakeRunner{models: `{"data":[]}`, memory: "System-wide memory free percentage: 74%"}
	if err := run(options(root), locations, runner); err != nil {
		t.Fatal(err)
	}
	if len(runner.run) == 0 || runner.run[0] != filepath.Join(mflux, "venv", "bin", "mflux-generate-z-image-turbo") {
		t.Fatalf("auto did not select mflux: %#v", runner.run)
	}
	if !strings.Contains(strings.Join(runner.run, " "), "--base-model z-image-turbo --low-ram") {
		t.Fatalf("mflux invocation lost its verified flags: %#v", runner.run)
	}

	locations, _ = world(t, "auto")
	runner = &fakeRunner{models: `{"data":[{"id":"local-image","capabilities":["image_generation"]}]}`, memory: "System-wide memory free percentage: 74%"}
	out := options(t.TempDir())
	if err := run(out, locations, runner); err != nil {
		t.Fatal(err)
	}
	image, err := os.ReadFile(out.Out)
	if err != nil || string(image) != "PNG" {
		t.Fatalf("MLX Serve stub did not write image: %q, %v", image, err)
	}
	if len(runner.run) != 0 {
		t.Fatalf("auto did not prefer image-capable MLX Serve: %#v", runner.run)
	}
}

func TestMLXServeCapsDimensions(t *testing.T) {
	locations, _ := world(t, "auto")
	runner := &fakeRunner{models: `{"data":[{"id":"local-image","capabilities":["image_generation"]}]}`}
	options := options(t.TempDir())
	options.Width = 1537
	err := run(options, locations, runner)
	if err == nil || !strings.Contains(err.Error(), "capped at 1536 px") {
		t.Fatalf("expected MLX Serve cap refusal, got %v", err)
	}
}

func TestMissingEngineMessage(t *testing.T) {
	root := t.TempDir()
	locations := paths{config: filepath.Join(root, "config"), state: filepath.Join(root, "state")}
	if err := os.MkdirAll(locations.config, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(locations.config, "image-engine"), []byte("auto\n"+filepath.Join(root, "missing")+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	err := run(options(root), locations, &fakeRunner{models: `{"data":[]}`})
	if err == nil || !strings.Contains(err.Error(), "MLX Serve has no image-capable model") || !strings.Contains(err.Error(), "mflux root") {
		t.Fatalf("expected missing engine message, got %v", err)
	}
}

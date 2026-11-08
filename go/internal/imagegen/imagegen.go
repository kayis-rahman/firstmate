// Package imagegen owns Firstmate's guarded local image-generation command.
package imagegen

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

const mlxServeURL = "http://127.0.0.1:11234"

type Options struct {
	Prompt, Out, Engine string
	References          []string
	Width, Height       int
	Seed                *int
}

type Config struct {
	Engine, MfluxRoot string
}

type commandRunner interface {
	Output(string, ...string) ([]byte, error)
	Run([]string, []string) error
}

type systemRunner struct{}

func (systemRunner) Output(name string, args ...string) ([]byte, error) {
	return exec.Command(name, args...).Output()
}

func (systemRunner) Run(command, environment []string) error {
	cmd := exec.Command(command[0], command[1:]...)
	overridden := make(map[string]bool, len(environment))
	for _, entry := range environment {
		if key, _, ok := strings.Cut(entry, "="); ok {
			overridden[key] = true
		}
	}
	env := os.Environ()
	filtered := make([]string, 0, len(env))
	for _, entry := range env {
		if key, _, ok := strings.Cut(entry, "="); ok && overridden[key] {
			continue
		}
		filtered = append(filtered, entry)
	}
	cmd.Env = append(filtered, environment...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

type paths struct {
	config, state string
}

func Run(options Options) error {
	root := os.Getenv("FM_HOME")
	if root == "" {
		root = os.Getenv("FM_ROOT")
	}
	if root == "" {
		root = filepath.Clean(filepath.Join(filepath.Dir(os.Args[0]), ".."))
	}
	config := os.Getenv("FM_CONFIG_OVERRIDE")
	if config == "" {
		config = filepath.Join(root, "config")
	}
	state := os.Getenv("FM_STATE_OVERRIDE")
	if state == "" {
		state = filepath.Join(root, "state")
	}
	return run(options, paths{config: config, state: state}, systemRunner{})
}

func run(options Options, locations paths, runner commandRunner) (err error) {
	if err := validate(options); err != nil {
		return err
	}
	config, err := readConfig(filepath.Join(locations.config, "image-engine"))
	if err != nil {
		return err
	}
	models, _ := runner.Output("curl", "--fail", "--silent", "--show-error", "--max-time", "3", mlxURL()+"/v1/models")
	imageModel := findImageModel(models)
	engine, err := selectEngine(options.Engine, config, imageModel)
	if err != nil {
		return err
	}
	if err := validateEngine(engine, config, imageModel, options); err != nil {
		return err
	}
	memory, err := runner.Output("memory_pressure")
	if err != nil {
		return fmt.Errorf("could not read free memory percentage: %w", err)
	}
	free, line, ok := freeMemory(memory)
	if !ok {
		return fmt.Errorf("could not read free memory percentage: %s", strings.TrimSpace(string(memory)))
	}
	if free < 10 {
		return fmt.Errorf("refusing image generation: free memory is %d%% (minimum 10%%; %s)", free, line)
	}
	if err := os.MkdirAll(locations.state, 0o755); err != nil {
		return err
	}
	lock := filepath.Join(locations.state, "image-gen.lock")
	if err := os.Mkdir(lock, 0o755); err != nil {
		if os.IsExist(err) {
			return errors.New("refusing image generation: another image job is active")
		}
		return err
	}
	defer func() {
		_ = os.Remove(lock)
		logJob(filepath.Join(locations.state, "image-gen.log"), engine, options.Out, err)
	}()
	if err := os.MkdirAll(filepath.Dir(options.Out), 0o755); err != nil {
		return err
	}
	switch engine {
	case "mflux":
		command := mfluxCommand(config.MfluxRoot, options)
		return runner.Run(command, []string{"HOME=" + filepath.Join(config.MfluxRoot, "home"), "HF_HOME=" + filepath.Join(config.MfluxRoot, "hf"), "HF_HUB_OFFLINE=1"})
	case "mlx-serve":
		return generateMLX(runner, imageModel, options)
	default:
		return fmt.Errorf("unknown engine: %s", engine)
	}
}

func mlxURL() string {
	if url := os.Getenv("FM_MLX_SERVE_URL"); url != "" {
		return url
	}
	return mlxServeURL
}

func validate(options Options) error {
	if options.Prompt == "" || options.Out == "" {
		return errors.New("--prompt and --out are required")
	}
	if !strings.EqualFold(filepath.Ext(options.Out), ".png") {
		return errors.New("--out must name a PNG")
	}
	if options.Width < 0 || options.Height < 0 {
		return errors.New("--width and --height must be positive")
	}
	for _, reference := range options.References {
		if info, err := os.Stat(reference); err != nil || info.IsDir() {
			return fmt.Errorf("reference does not exist: %s", reference)
		}
	}
	switch options.Engine {
	case "", "auto", "mflux", "mlx-serve":
		return nil
	default:
		return errors.New("--engine must be mflux, mlx-serve, or auto")
	}
}

func readConfig(path string) (Config, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return Config{Engine: "auto"}, nil
	}
	if err != nil {
		return Config{}, err
	}
	lines := strings.Split(string(data), "\n")
	config := Config{Engine: strings.TrimSpace(lines[0])}
	if len(lines) > 1 {
		config.MfluxRoot = strings.TrimSpace(lines[1])
	}
	switch config.Engine {
	case "", "auto", "mflux", "mlx-serve":
		if config.Engine == "" {
			config.Engine = "auto"
		}
		return config, nil
	default:
		return Config{}, fmt.Errorf("%s has an invalid engine: %s", path, config.Engine)
	}
}

type modelResponse struct {
	Data []struct {
		ID           string   `json:"id"`
		Capabilities []string `json:"capabilities"`
	} `json:"data"`
}

func findImageModel(data []byte) string {
	var models modelResponse
	if json.Unmarshal(data, &models) != nil {
		return ""
	}
	for _, model := range models.Data {
		for _, capability := range model.Capabilities {
			if strings.Contains(strings.ToLower(capability), "image") {
				return model.ID
			}
		}
	}
	return ""
}

func selectEngine(requested string, config Config, imageModel string) (string, error) {
	if requested == "" || requested == "auto" {
		requested = config.Engine
	}
	if requested == "auto" {
		if imageModel != "" {
			return "mlx-serve", nil
		}
		if config.MfluxRoot != "" {
			if info, err := os.Stat(config.MfluxRoot); err == nil && info.IsDir() {
				return "mflux", nil
			}
		}
		return "", errors.New("no local image engine: MLX Serve has no image-capable model and config/image-engine has no existing mflux root")
	}
	return requested, nil
}

func validateEngine(engine string, config Config, imageModel string, options Options) error {
	switch engine {
	case "mflux":
		if config.MfluxRoot == "" {
			return errors.New("mflux needs the install root on line 2 of config/image-engine")
		}
		if _, err := os.Stat(filepath.Join(config.MfluxRoot, "venv", "bin", "mflux-generate-z-image-turbo")); err != nil {
			return errors.New("mflux install is missing venv/bin/mflux-generate-z-image-turbo under its configured root")
		}
		if info, err := os.Stat(filepath.Join(config.MfluxRoot, "model")); err != nil || !info.IsDir() {
			return errors.New("mflux install is missing model under its configured root")
		}
		if len(options.References) > 1 {
			return errors.New("mflux accepts one reference image per job")
		}
	case "mlx-serve":
		if imageModel == "" {
			return fmt.Errorf("MLX Serve has no image-capable model at %s/v1/models", mlxURL())
		}
		if options.Width > 1536 || options.Height > 1536 {
			return errors.New("MLX Serve images are capped at 1536 px per side")
		}
		if len(options.References) > 0 {
			return errors.New("MLX Serve references are not supported by this wrapper yet")
		}
	}
	return nil
}

var freePercentage = regexp.MustCompile(`free percentage:\s*([0-9]+)%`)

func freeMemory(data []byte) (int, string, bool) {
	for _, line := range strings.Split(string(data), "\n") {
		if match := freePercentage.FindStringSubmatch(line); match != nil {
			percent, _ := strconv.Atoi(match[1])
			return percent, strings.TrimSpace(line), true
		}
	}
	return 0, "", false
}

func mfluxCommand(root string, options Options) []string {
	command := []string{filepath.Join(root, "venv", "bin", "mflux-generate-z-image-turbo"), "--model", filepath.Join(root, "model"), "--base-model", "z-image-turbo", "--low-ram", "--prompt", options.Prompt}
	if len(options.References) == 1 {
		command = append(command, "--image", options.References[0])
	}
	if options.Width > 0 {
		command = append(command, "--width", strconv.Itoa(options.Width))
	}
	if options.Height > 0 {
		command = append(command, "--height", strconv.Itoa(options.Height))
	}
	if options.Seed != nil {
		command = append(command, "--seed", strconv.Itoa(*options.Seed))
	}
	return append(command, "--output", options.Out)
}

func generateMLX(runner commandRunner, model string, options Options) error {
	width, height := options.Width, options.Height
	if width == 0 {
		width = 1024
	}
	if height == 0 {
		height = 1024
	}
	request, _ := json.Marshal(map[string]string{"model": model, "prompt": options.Prompt, "size": fmt.Sprintf("%dx%d", width, height), "response_format": "b64_json"})
	response, err := runner.Output("curl", "--fail", "--silent", "--show-error", "--max-time", "600", "-H", "Content-Type: application/json", "-d", string(request), mlxURL()+"/v1/images/generations")
	if err != nil {
		return err
	}
	var decoded struct {
		Data []struct {
			B64 string `json:"b64_json"`
		} `json:"data"`
	}
	if err := json.Unmarshal(response, &decoded); err != nil || len(decoded.Data) == 0 || decoded.Data[0].B64 == "" {
		return errors.New("MLX Serve did not return b64_json")
	}
	image, err := base64.StdEncoding.DecodeString(decoded.Data[0].B64)
	if err != nil {
		return err
	}
	return os.WriteFile(options.Out, image, 0o644)
}

func logJob(path, engine, output string, jobError error) {
	exitCode := 0
	if jobError != nil {
		exitCode = 1
	}
	file, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer file.Close()
	_, _ = fmt.Fprintf(file, "%s engine=%s output=%s exit=%d\n", time.Now().UTC().Format(time.RFC3339), engine, output, exitCode)
}

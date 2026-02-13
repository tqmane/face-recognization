# GPU Inference Architecture

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         HomeScreen (UI)                          │
│  • Engine Selection (Histogram, TFLite, ONNX, DirectML, Server) │
│  • Device Selection (CPU, GPU, DirectML, NNAPI, CoreML, etc.)   │
│  • Test Set Loading                                              │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ├──────────────────────────────────────────────┐
                  │                                              │
                  ▼                                              ▼
┌─────────────────────────────────┐      ┌────────────────────────────────┐
│   GpuCapabilityChecker          │      │     ModelManager               │
│  (Platform Detection)           │      │   (Model Download/Path)        │
│                                 │      │                                │
│  • detectPlatform()             │      │  • getModelPath()              │
│  • availableTfliteDevices       │      │  • downloadModel()             │
│  • availableOnnxDevices         │      │                                │
│  • isDirectMLAvailable          │      └────────────────────────────────┘
│  • isNNAPIAvailable             │
└─────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                      InferenceEngine                             │
│                    (Abstract Interface)                          │
│                                                                  │
│  • initialize()                                                  │
│  • compareImages(path1, path2) -> double                        │
│  • runSyntheticBenchmark() -> PerfStats                         │
│  • dispose()                                                     │
└────┬─────────────┬─────────────┬──────────────┬─────────────────┘
     │             │             │              │
     ▼             ▼             ▼              ▼
┌──────────┐ ┌──────────┐ ┌─────────────┐ ┌───────────────┐
│Histogram │ │ TFLite   │ │ OnnxEngine  │ │OnnxDirectML   │
│Engine    │ │Engine    │ │             │ │Engine         │
└──────────┘ └────┬─────┘ └──────┬──────┘ └───────┬───────┘
                  │              │                 │
                  │              │                 │
                  ▼              ▼                 ▼
         ┌──────────────┐ ┌─────────────┐ ┌──────────────┐
         │GPU Delegate  │ │NNAPI/CoreML │ │DirectML FFI  │
         │   (Mobile)   │ │  Provider   │ │   Bindings   │
         └──────────────┘ └─────────────┘ └──────────────┘
```

## Data Flow

### Engine Initialization Flow

```
User Selects Engine & Device
         │
         ▼
  GpuCapabilityChecker
  checks availability
         │
         ▼
  Engine Constructor
  (modelPath, device)
         │
         ▼
   engine.initialize()
         │
         ├──> Try GPU/Accelerator
         │    │
         │    ├──> Success ─────┐
         │    │                 │
         │    └──> Fail ────────┤
         │                      │
         └──> Fallback to CPU ──┘
                      │
                      ▼
            Track actualDevice
                      │
                      ▼
        Display "Model (Engine-Device)"
```

### Inference Flow

```
User Runs Benchmark
         │
         ▼
  Load Test Pairs
         │
         ▼
For Each Image Pair:
         │
         ├──> Load Image 1 ──> Preprocess ──> Embed ──┐
         │                                            │
         └──> Load Image 2 ──> Preprocess ──> Embed ──┤
                                                      │
                                                      ▼
                                              Cosine Similarity
                                                      │
                                                      ▼
                                            Compare to Threshold
                                                      │
                                                      ▼
                                            Record Result (TP/TN/FP/FN)
                                                      │
                                                      ▼
                                              Aggregate Stats
                                                      │
                                                      ▼
                                        Export to JSON/CSV
```

## Platform-Specific Implementations

### Windows
```
OnnxDirectMLEngine
       │
       ├──> OnnxDirectMLFFI.initialize()
       │    │
       │    ├──> Try load DirectML DLL
       │    │    │
       │    │    ├──> Found ──> Use DirectML provider
       │    │    │
       │    │    └──> Not Found ──> Log warning
       │    │
       │    └──> Fallback to XNNPACK
       │
       ├──> Create OrtSession with provider
       │
       └──> actualDevice = "DirectML" | "XNNPACK" | "CPU"
```

### Android
```
TfliteEngine (device="GPU")
       │
       ├──> Create GpuDelegateV2
       │    │
       │    ├──> Success ──> Add to InterpreterOptions
       │    │
       │    └──> Fail ──> Log error, remove delegate
       │
       ├──> Create Interpreter with options
       │    │
       │    ├──> Success ──> actualDevice = "GPU"
       │    │
       │    └──> Fail ──> Retry without delegate, actualDevice = "CPU"
       │
       └──> Return initialized engine

OnnxEngine (device="NNAPI")
       │
       ├──> Create OrtSessionOptions
       │
       ├──> appendNnapiProvider()
       │    │
       │    ├──> Success ──> actualDevice = "NNAPI"
       │    │
       │    └──> Fail ──> appendCPUProvider(), actualDevice = "CPU"
       │
       └──> Create OrtSession with options
```

### iOS/macOS
```
TfliteEngine (device="GPU")
       │
       ├──> Create GpuDelegate (Metal)
       │    │
       │    └──> Add to InterpreterOptions
       │
       └──> actualDevice = "GPU" | "CPU"

OnnxEngine (device="CoreML")
       │
       ├──> Create OrtSessionOptions
       │
       ├──> appendCoreMLProvider()
       │    │
       │    └──> Use Apple Neural Engine/GPU
       │
       └──> actualDevice = "CoreML" | "CPU"
```

## Resource Management

### Singleton Pattern (OrtEnv)
```
┌─────────────────────────────────┐
│         OrtEnv.instance         │
│      (Singleton, App-wide)      │
│                                 │
│  • init() - Called once         │
│  • release() - Never called by  │
│              individual engines │
└────┬───────────────────┬────────┘
     │                   │
     ▼                   ▼
┌──────────┐      ┌──────────┐
│OnnxEngine│      │DirectML  │
│ Session  │      │Engine    │
│          │      │Session   │
│dispose():│      │          │
│ session  │      │dispose():│
│  .release│      │ session  │
│ opts     │      │  .release│
│  .release│      │ opts     │
│          │      │  .release│
└──────────┘      └──────────┘
```

### Per-Engine Resources
```
TfliteEngine
       │
       ├──> _interp (Interpreter)
       │    └──> close() on dispose
       │
       └──> _gpuDelegate (if used)
            └──> delete() on dispose

OnnxEngine / DirectMLEngine
       │
       ├──> _session (OrtSession)
       │    └──> release() on dispose
       │
       ├──> _opts (OrtSessionOptions)
       │    └──> release() on dispose
       │
       └──> OrtEnv.instance
            └──> NOT released (singleton)
```

## Error Handling

### GPU Initialization Errors
```
Try Initialize GPU
       │
       ├──> Success
       │    └──> actualDevice = requested device
       │
       └──> Fail
            │
            ├──> Log error with details
            │
            ├──> Fallback to CPU
            │    └──> actualDevice = "CPU"
            │
            └──> Continue execution (no crash)
```

### Model Loading Errors
```
Load Model
       │
       ├──> File exists
       │    └──> Load bytes
       │
       └──> File missing
            │
            └──> Throw exception with message:
                 "モデルがダウンロードされていません"
                 User shown error in UI
                 Can navigate to Model Management screen
```

## Performance Monitoring

```
runSyntheticBenchmark(runs=100)
       │
       ├──> Warmup (30 iterations)
       │    └──> Discard results
       │
       ├──> Benchmark runs
       │    │
       │    └──> For each run:
       │         ├──> Start timer
       │         ├──> Run inference
       │         ├──> Stop timer
       │         └──> Record latency
       │
       ├──> Sort latencies
       │
       └──> Calculate stats:
            ├──> Mean
            ├──> P50 (median)
            ├──> P90
            ├──> Min
            ├──> Max
            └──> FPS = 1000 / mean_ms
```

## UI State Management

```
HomeScreen State
       │
       ├──> _selectedEngine: String
       │    └──> Controls which engine to create
       │
       ├──> _selectedDevice: String
       │    └──> Passed to engine constructor
       │
       ├──> _updateAvailableDevice()
       │    │
       │    └──> When engine changes:
       │         ├──> Get available devices for engine
       │         └──> Update _selectedDevice if invalid
       │
       └──> _createEngine()
            │
            └──> Switch on _selectedEngine:
                 ├──> "tflite" ──> TfliteEngine(device: _selectedDevice)
                 ├──> "onnx" ──> OnnxEngine(device: _selectedDevice)
                 ├──> "onnx_directml" ──> DirectMLEngine(device: _selectedDevice)
                 └──> etc.
```

## Key Design Decisions

1. **Singleton OrtEnv**: Prevents crashes from multiple init/release calls
2. **Fallback Pattern**: Ensures app always works, even without GPU
3. **Actual Device Tracking**: Shows user what's really being used, not what was requested
4. **Platform Abstraction**: GpuCapabilityChecker centralizes platform detection
5. **Minimal Changes**: Enhanced existing engines rather than complete rewrite
6. **Error Resilience**: Try-catch with fallback at every GPU initialization point

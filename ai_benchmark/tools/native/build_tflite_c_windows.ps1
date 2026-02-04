Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppRoot = Resolve-Path (Join-Path $ScriptDir '..\..')
$RepoRoot = Resolve-Path (Join-Path $AppRoot '..')

$TfSrc = if ($env:TENSORFLOW_SOURCE_DIR) { $env:TENSORFLOW_SOURCE_DIR } elseif ($env:TF_SOURCE_DIR) { $env:TF_SOURCE_DIR } else { Join-Path $RepoRoot '..\tensorflow_src' }
$BuildDir = if ($env:BUILD_DIR) { $env:BUILD_DIR } else { Join-Path $RepoRoot '..\tflite_build_c_windows' }

if (-not (Test-Path $TfSrc)) {
  Write-Error "TensorFlowソースが見つかりません: $TfSrc`n環境変数 TENSORFLOW_SOURCE_DIR で tensorflow checkout のパスを指定してください。"
}

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

cmake -S (Join-Path $TfSrc 'tensorflow\lite\c') -B $BuildDir `
  -DTFLITE_C_BUILD_SHARED_LIBS=ON `
  -DTF_SOURCE_DIR=$TfSrc `
  -DTENSORFLOW_SOURCE_DIR=$TfSrc `
  -DCMAKE_BUILD_TYPE=Release

cmake --build $BuildDir --target tensorflowlite_c --config Release

# 生成物名は環境/ジェネレータで変わる可能性があるため探索
$candidates = @(
  Get-ChildItem -Path $BuildDir -Recurse -File -Filter '*tensorflowlite_c*.dll' -ErrorAction SilentlyContinue
  Get-ChildItem -Path $BuildDir -Recurse -File -Filter 'libtensorflowlite_c*.dll' -ErrorAction SilentlyContinue
) | Select-Object -ExpandProperty FullName -Unique

if (-not $candidates -or $candidates.Count -eq 0) {
  Write-Error "ビルド成果物 *.dll が見つかりません (BUILD_DIR=$BuildDir)"
}

# 一番それっぽいものを採用
$outDll = $candidates | Sort-Object Length | Select-Object -First 1

$blobsDir = Join-Path $AppRoot 'blobs'
New-Item -ItemType Directory -Force -Path $blobsDir | Out-Null
Copy-Item -Force -Path $outDll -Destination (Join-Path $blobsDir 'libtensorflowlite_c-win.dll')

Write-Host "OK: $blobsDir\libtensorflowlite_c-win.dll を更新しました"
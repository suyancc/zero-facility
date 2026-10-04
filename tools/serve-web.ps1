$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
if(-not (Test-Path "exports/web/index.html")){throw "Build Web first with tools/build-web.ps1"}
Get-Content -Raw tools/serve_web.py | py -3.11 -


# PowerShell Script to Bootstrap Remote State (S3 + DynamoDB) and Initialize Terraform Backend
$ErrorActionPreference = 'Stop'

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " Bootstrapping Terraform Remote State (S3 + DynamoDB Locking)    " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir
$BootstrapDir = Join-Path $RootDir "terraform\bootstrap"
$TerraformDir = Join-Path $RootDir "terraform"

Write-Host "`n[Step 1/3] Initializing and applying Terraform Bootstrap..." -ForegroundColor Yellow
Push-Location $BootstrapDir
try {
    terraform init -input=false
    terraform apply -auto-approve -input=false

    $BucketName = (terraform output -raw s3_bucket_name).Trim()
    $TableName  = (terraform output -raw dynamodb_table_name).Trim()
    $Region     = (terraform output -raw aws_region).Trim()
}
finally {
    Pop-Location
}

Write-Host "`nSuccessfully created/verified Remote State Resources:" -ForegroundColor Green
Write-Host "  S3 Bucket:     $BucketName" -ForegroundColor White
Write-Host "  DynamoDB Table: $TableName" -ForegroundColor White
Write-Host "  AWS Region:    $Region" -ForegroundColor White

Write-Host "`n[Step 2/3] Generating backend.hcl configuration..." -ForegroundColor Yellow
$BackendConfigFile = Join-Path $TerraformDir "backend.hcl"
$BackendContent = @"
bucket         = "$BucketName"
key            = "scale-to-zero-fleet/terraform.tfstate"
region         = "$Region"
dynamodb_table = "$TableName"
encrypt        = true
"@

Set-Content -Path $BackendConfigFile -Value $BackendContent -Encoding UTF8
Write-Host "Backend configuration written to: $BackendConfigFile" -ForegroundColor Green

Write-Host "`n[Step 3/3] Reconfiguring Terraform root backend..." -ForegroundColor Yellow
Push-Location $TerraformDir
try {
    terraform init -reconfigure -backend-config="backend.hcl"
}
finally {
    Pop-Location
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host " Remote State Backend Initialization Complete!                  " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

#Requires -Version 5.1
<#
.SYNOPSIS
    Staddress AI API — PowerShell サンプル（統合スクリプト）

.DESCRIPTION
    Windows 標準の PowerShell 5.1 / PowerShell 7+ で、追加ツール（curl・jq）なしに
    Staddress AI API を呼び出すサンプル。Invoke-RestMethod のみを使用する。

.EXAMPLE
    ./staddress.ps1 -Usage
.EXAMPLE
    ./staddress.ps1 -Single "六本木ヒルズ 森タワー 52F"
.EXAMPLE
    ./staddress.ps1 -Single "東京都渋谷区道玄坂1-2 マンション桜 101号" -PostalCode "150-0043"
.EXAMPLE
    ./staddress.ps1 -Batch .\batch-sample.json
#>
[CmdletBinding(DefaultParameterSetName = 'Help')]
param(
    [Parameter(ParameterSetName = 'Usage')]
    [switch]$Usage,

    [Parameter(ParameterSetName = 'Single', Mandatory = $true, Position = 0)]
    [string]$Single,

    [Parameter(ParameterSetName = 'Single')]
    [string]$PostalCode,

    [Parameter(ParameterSetName = 'Batch', Mandatory = $true, Position = 0)]
    [string]$Batch,

    [Parameter(ParameterSetName = 'Help')]
    [switch]$Help,

    # 接続オプション（全コマンド共通）。指定時は環境変数 / .env より優先。
    [string]$Key,

    [string]$Server
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path

function Show-Help {
    @'
Staddress AI API — PowerShell サンプル

使い方:
  ./staddress.ps1 [オプション]

オプション:
  -Usage                          利用状況を取得 (GET /api/v1/usage)
  -Single <住所> [-PostalCode <郵便番号>]
                                  単件住所解析 (POST /api/v1/addresses/parse)
  -Batch <ファイル>               一括住所解析 (POST /api/v1/addresses/parse/batch)
                                  JSON ファイルを指定（サンプル: batch-sample.json）
  -Help                           このメッセージを表示

接続オプション（優先順位: 引数 > 環境変数 / .env > 対話入力）:
  -Key <APIキー>                  STADDRESS_API_KEY を指定
  -Server <ベースURL>             STADDRESS_BASE_URL を指定

例:
  ./staddress.ps1 -Usage
  ./staddress.ps1 -Server https://api.staddress.com -Key sk_xxx -Usage
  ./staddress.ps1 -Single "六本木ヒルズ 森タワー 52F"
  ./staddress.ps1 -Single "東京都渋谷区道玄坂1-2 マンション桜 101号" -PostalCode "150-0043"
  ./staddress.ps1 -Batch .\batch-sample.json

一括 JSON ファイル形式:
  {"items": [{"id": "...", "address": "...", "postalCode": "..."}]}
  または items 配列のみ: [{"id": "...", "address": "..."}]
  ※ 最大100件。postalCode は任意。

認証・接続先の解決順:
  1. 引数 -Key / -Server
  2. 環境変数 / .env の STADDRESS_API_KEY / STADDRESS_BASE_URL
  3. いずれも無ければ対話入力（API キーは非表示で入力）

公式 API: https://staddress.com/api
'@ | Write-Host
}

function Fail {
    param([string]$Message, [int]$Code)
    Write-Host "Error: $Message" -ForegroundColor Red
    exit $Code
}

# リポジトリルートの .env を読み込み、未設定の環境変数のみを補完する
function Import-DotEnv {
    $envPath = Join-Path $RootDir '.env'
    if (-not (Test-Path $envPath)) { return }

    foreach ($line in (Get-Content -Path $envPath -Encoding UTF8)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }

        $idx = $trimmed.IndexOf('=')
        if ($idx -lt 1) { continue }

        $key = $trimmed.Substring(0, $idx).Trim()
        $val = $trimmed.Substring($idx + 1).Trim()

        if ($val.Length -ge 2) {
            $first = $val[0]
            $last = $val[$val.Length - 1]
            if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
                $val = $val.Substring(1, $val.Length - 2)
            }
        }

        if (-not (Test-Path "env:$key")) {
            Set-Item -Path "env:$key" -Value $val
        }
    }
}

function Get-Config {
    Import-DotEnv

    # ベース URL: 引数 -Server > 環境変数 / .env > 対話入力
    if (-not [string]::IsNullOrWhiteSpace($Server)) {
        $baseUrl = $Server
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:STADDRESS_BASE_URL)) {
        $baseUrl = $env:STADDRESS_BASE_URL
    }
    else {
        $baseUrl = Read-Host "STADDRESS_BASE_URL を入力してください（既定: https://api.staddress.com）"
        if ([string]::IsNullOrWhiteSpace($baseUrl)) {
            $baseUrl = 'https://api.staddress.com'
        }
    }

    # API キー: 引数 -Key > 環境変数 / .env > 対話入力（非表示）
    if (-not [string]::IsNullOrWhiteSpace($Key)) {
        $apiKey = $Key
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:STADDRESS_API_KEY)) {
        $apiKey = $env:STADDRESS_API_KEY
    }
    else {
        $secure = Read-Host "STADDRESS_API_KEY を入力してください" -AsSecureString
        $apiKey = (New-Object System.Management.Automation.PSCredential('staddress', $secure)).GetNetworkCredential().Password
    }

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        Fail "STADDRESS_API_KEY が設定されていません。" 2
    }

    return @{
        BaseUrl = $baseUrl.TrimEnd('/')
        ApiKey  = $apiKey
    }
}

function Invoke-Staddress {
    param(
        [string]$Method,
        [string]$Path,
        $Body
    )

    $config = Get-Config
    $uri = "$($config.BaseUrl)$Path"
    $headers = @{ 'X-Api-Key' = $config.ApiKey }

    try {
        if ($null -ne $Body) {
            $json = $Body | ConvertTo-Json -Depth 20
            # 日本語の文字化けを避けるため UTF-8 バイト列で送信する
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $resp = Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers `
                -ContentType 'application/json; charset=utf-8' -Body $bytes
        }
        else {
            $resp = Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
        }

        $resp | ConvertTo-Json -Depth 20
    }
    catch {
        $detail = $null
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $detail = $_.ErrorDetails.Message
        }

        if ($detail) {
            try {
                $detail = $detail | ConvertFrom-Json | ConvertTo-Json -Depth 20
            }
            catch {
                # JSON でなければそのまま表示
            }
            Write-Host $detail
        }
        else {
            Write-Host "Error: API リクエストに失敗しました: $($_.Exception.Message)" -ForegroundColor Red
        }
        exit 1
    }
}

function Invoke-Single {
    if ([string]::IsNullOrWhiteSpace($Single)) {
        Fail "住所を指定してください。例: ./staddress.ps1 -Single `"六本木ヒルズ 森タワー 52F`"" 2
    }

    $body = @{ input = $Single }
    if (-not [string]::IsNullOrWhiteSpace($PostalCode)) {
        $body.postalCode = $PostalCode
    }

    Invoke-Staddress -Method 'POST' -Path '/api/v1/addresses/parse' -Body $body
}

function Invoke-Batch {
    if (-not (Test-Path $Batch)) {
        Fail "ファイルが見つかりません: $Batch" 2
    }

    try {
        $raw = Get-Content -Path $Batch -Raw -Encoding UTF8
        $parsed = $raw | ConvertFrom-Json
    }
    catch {
        Fail "無効な JSON 形式: $Batch（{`"items`": [...]} 形式、または items 配列を指定してください）" 2
    }

    if ($parsed -is [System.Array]) {
        $items = $parsed
    }
    elseif ($parsed.PSObject.Properties.Name -contains 'items') {
        $items = $parsed.items
    }
    else {
        Fail "{`"items`": [...]} 形式、または items 配列を指定してください。" 2
    }

    $count = @($items).Count
    if ($count -eq 0) {
        Fail "items が空です。" 2
    }
    if ($count -gt 100) {
        Fail "items は最大100件です（現在: $count 件）。" 2
    }

    $body = @{ items = $items }
    Invoke-Staddress -Method 'POST' -Path '/api/v1/addresses/parse/batch' -Body $body
}

switch ($PSCmdlet.ParameterSetName) {
    'Usage'  { Invoke-Staddress -Method 'GET' -Path '/api/v1/usage' -Body $null }
    'Single' { Invoke-Single }
    'Batch'  { Invoke-Batch }
    default  { Show-Help }
}

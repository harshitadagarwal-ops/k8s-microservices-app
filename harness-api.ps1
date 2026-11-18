# Small helper for Harness REST calls. Reads HARNESS_API_KEY from .env; never prints it.
param(
    [Parameter(Mandatory)] [string] $Method,
    [Parameter(Mandatory)] [string] $Path,          # e.g. /pipeline/api/pipelines/xyz
    [string] $Query = "",                           # extra query string (without leading &)
    [string] $BodyFile = "",                        # optional file whose contents are sent as the body
    [string] $ContentType = "application/json",
    [string] $OutFile = ""                          # optional: write raw response here
)
$line = Get-Content (Join-Path $PSScriptRoot ".env") | Where-Object { $_ -match '^\s*(export\s+)?HARNESS_API_KEY\s*=' } | Select-Object -First 1
if (-not $line) { throw "HARNESS_API_KEY not found in .env" }
$key = ($line -split '=', 2)[1].Trim().Trim('"').Trim("'")
$acct = "gLXLxjTmQhGmdJXhAORKag"
$scope = "accountIdentifier=$acct&orgIdentifier=Worker_Agents_Hackathon&projectIdentifier=Team_KubePilots"
$uri = "https://app.harness.io$Path" + "?" + $scope + $(if ($Query) { "&$Query" } else { "" })
$headers = @{ "x-api-key" = $key; "Harness-Account" = $acct }
$args = @{ Method = $Method; Uri = $uri; Headers = $headers; ContentType = $ContentType; TimeoutSec = 60; UseBasicParsing = $true }
# Send raw UTF-8 bytes with an explicit charset. Passing a string body makes Windows
# PowerShell 5.1 encode it as ISO-8859-1, which corrupts non-ASCII characters (e.g. the
# warning/arrow symbols in the pipeline's jq commands).
if ($BodyFile) {
    $args.Body = [System.IO.File]::ReadAllBytes((Resolve-Path $BodyFile))
    if ($ContentType -notmatch "charset") { $args.ContentType = "$ContentType; charset=utf-8" }
}
try {
    $resp = Invoke-WebRequest @args
    # Decode the response as UTF-8 explicitly ($resp.Content can mis-decode non-ASCII).
    $ms = New-Object System.IO.MemoryStream; $resp.RawContentStream.CopyTo($ms)
    $text = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
    if ($OutFile) { [System.IO.File]::WriteAllText($OutFile, $text, (New-Object System.Text.UTF8Encoding $false)) ; "saved $($text.Length) chars to $OutFile (HTTP $($resp.StatusCode))" }
    else { $text }
} catch {
    "HTTP ERROR: " + $_.Exception.Message
    if ($_.ErrorDetails) { $_.ErrorDetails.Message.Substring(0, [Math]::Min(800, $_.ErrorDetails.Message.Length)) }
}

# Records why Preflight CI step containers exit (OOMKilled, Error + exit code, etc).
# Polls the harness-preflight namespace every 3s and appends new terminations to a log.
$env:AWS_PROFILE = "avyka-mfa"
$out = Join-Path $env:TEMP "preflight-pod-watch.log"
"watch started $(Get-Date -Format o)" | Out-File $out -Encoding utf8
$seen = @{}
while ($true) {
    $json = kubectl get pods -n harness-preflight -o json --request-timeout=10s 2>$null
    if ($json) {
        $pods = ($json | ConvertFrom-Json).items
        foreach ($p in $pods) {
            $node = $p.spec.nodeName
            foreach ($cs in $p.status.containerStatuses) {
                foreach ($t in @($cs.state.terminated, $cs.lastState.terminated)) {
                    if ($t) {
                        $key = "$($p.metadata.name)/$($cs.name)/$($t.finishedAt)"
                        if (-not $seen.ContainsKey($key)) {
                            $seen[$key] = 1
                            $line = "$(Get-Date -Format o) pod=$($p.metadata.name) node=$node container=$($cs.name) reason=$($t.reason) exitCode=$($t.exitCode) msg=$($t.message)"
                            $line | Out-File $out -Append -Encoding utf8
                        }
                    }
                }
            }
            # capture step-container memory limits once per pod
            $lk = "limits/$($p.metadata.name)"
            if (-not $seen.ContainsKey($lk)) {
                $seen[$lk] = 1
                foreach ($c in $p.spec.containers) {
                    "$(Get-Date -Format o) pod=$($p.metadata.name) container=$($c.name) image=$($c.image) memLimit=$($c.resources.limits.memory) cpuLimit=$($c.resources.limits.cpu)" | Out-File $out -Append -Encoding utf8
                }
            }
        }
    }
    Start-Sleep -Seconds 3
}

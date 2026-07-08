param(
  [string]$Namespace = $(if ($env:NAMESPACE) { $env:NAMESPACE } else { "yas-dev" }),
  [string]$ServiceUrl = $(if ($env:SERVICE_URL) { $env:SERVICE_URL } else { "http://product/product/api/v1/products" }),
  [string]$AllowedPod = $(if ($env:ALLOWED_POD) { $env:ALLOWED_POD } else { "curl-order" }),
  [string]$DeniedPod = $(if ($env:DENIED_POD) { $env:DENIED_POD } else { "curl-unauthorized" }),
  [string]$AllowedExpectedStatus = $(if ($env:ALLOWED_EXPECTED_STATUS) { $env:ALLOWED_EXPECTED_STATUS } else { "401" }),
  [string]$DeniedExpectedStatus = $(if ($env:DENIED_EXPECTED_STATUS) { $env:DENIED_EXPECTED_STATUS } else { "403" }),
  [string]$Timeout = $(if ($env:TIMEOUT) { $env:TIMEOUT } else { "120s" }),
  [string]$KeepPods = $(if ($env:KEEP_PODS) { $env:KEEP_PODS } else { "false" })
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Invoke-Kubectl {
  & kubectl @args
  if ($LASTEXITCODE -ne 0) {
    throw "kubectl command failed: kubectl $($args -join ' ')"
  }
}

function Cleanup {
  if ($KeepPods -eq "true") {
    return
  }

  & kubectl delete -f "$ScriptDir/curl-order-pod.yaml" --ignore-not-found=true *> $null
  & kubectl delete -f "$ScriptDir/curl-unauthorized-pod.yaml" --ignore-not-found=true *> $null
}

function Wait-ForPod {
  param([string]$PodName)

  Invoke-Kubectl wait --for=condition=Ready "pod/$PodName" -n $Namespace --timeout=$Timeout
}

function Get-CurlStatusFromPod {
  param([string]$PodName)

  $status = & kubectl exec $PodName -n $Namespace -c curl -- curl -sS -o /tmp/authz-response-body -D /tmp/authz-response-headers -w "%{http_code}" $ServiceUrl
  if ($LASTEXITCODE -ne 0) {
    throw "curl from pod $PodName failed"
  }

  return ($status | Out-String).Trim()
}

function Show-ResponseFromPod {
  param([string]$PodName)

  Write-Host "----- ${PodName}: response headers -----"
  & kubectl exec $PodName -n $Namespace -c curl -- sh -c "cat /tmp/authz-response-headers 2>/dev/null || true"
  Write-Host "----- ${PodName}: response body -----"
  & kubectl exec $PodName -n $Namespace -c curl -- sh -c "cat /tmp/authz-response-body 2>/dev/null || true"
  Write-Host ""
}

function Assert-Status {
  param(
    [string]$PodName,
    [string]$ExpectedStatus,
    [string]$Description
  )

  $actualStatus = Get-CurlStatusFromPod $PodName
  Show-ResponseFromPod $PodName

  if ($actualStatus -ne $ExpectedStatus) {
    throw "FAIL: ${Description}: expected HTTP $ExpectedStatus, got HTTP $actualStatus"
  }

  Write-Host "PASS: ${Description}: got HTTP $actualStatus"
}

try {
  Write-Host "Applying curl test pods in namespace $Namespace..."
  Invoke-Kubectl apply -f "$ScriptDir/curl-order-pod.yaml"
  Invoke-Kubectl apply -f "$ScriptDir/curl-unauthorized-pod.yaml"

  Write-Host "Waiting for curl test pods to be ready..."
  Wait-ForPod $AllowedPod
  Wait-ForPod $DeniedPod

  Write-Host "Testing $ServiceUrl"
  Assert-Status $AllowedPod $AllowedExpectedStatus "allowed pod $AllowedPod can reach the service through Istio"
  Assert-Status $DeniedPod $DeniedExpectedStatus "unauthorized pod $DeniedPod is blocked by Istio"

  Write-Host "AuthorizationPolicy connectivity test passed."
}
finally {
  Cleanup
}

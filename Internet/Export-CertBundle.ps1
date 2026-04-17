<#
.SYNOPSIS
Creates one PEM CA bundle so apps can trust HTTPS in Netskope-intercepted networks.

.DESCRIPTION
In many enterprise environments, Netskope inspects HTTPS traffic by decrypting and re-signing
connections with an enterprise certificate. Windows usually trusts that certificate because it
is in the OS certificate store.

The problem: many developer tools (Python, Node.js, curl, Git, containerized apps) do not
always use the Windows certificate store directly. They often expect a PEM certificate bundle.
That mismatch causes TLS errors even when your browser works.
See: https://community.netskope.com/next-gen-swg-2/configuring-developer-tools-with-netskope-ssl-inspection-8493

This script exports trusted CA certificates from Windows stores and writes them into one PEM
bundle file (default: corp_certs.pem). You can point tools to this file to mitigate TLS trust 
failures caused by interception.

.PARAMETER Path
Output path for the generated PEM bundle.
Defaults to ./corp_certs.pem (current working directory).
Supports local paths and UNC/fileshare paths (for example, \\server\share\corp_certs.pem).

.INPUTS
None. This script does not accept pipeline input.

.OUTPUTS
None. The script writes a PEM file to disk at the path provided.

.NOTES
WSL/Ubuntu note:
Even when running Linux tools in WSL, traffic still goes through your corporate network path.
If Netskope is intercepting HTTPS, WSL commands can fail with TLS trust errors unless Linux
tools are configured to trust the same CA chain.

Shell context note:
Unless otherwise noted, command examples use PowerShell on Windows.

Trust scope note:
The generated bundle includes all trusted root and intermediate CA certificates from the
current user and local machine Windows stores. Use it for enterprise developer tooling and
private container images, but avoid redistributing it as a public application bundle unless
you intend to trust that full certificate set.

7 common WSL break points:
- apt update / apt install
- curl and wget
- git clone/fetch over HTTPS
- pip install
- npm install / npx
- Maven/Gradle dependency downloads
- Docker builds started from WSL

Common error messages this helps with:
- SSL: CERTIFICATE_VERIFY_FAILED
- unable to get local issuer certificate
- self signed certificate in certificate chain

This script is a mitigation for trust issues caused by HTTPS interception. It does not disable
certificate verification.

.EXAMPLE
# 1) Generate the certificate bundle (default: ./corp_certs.pem)
./Export-CertBundle.ps1

# 2) Optional: generate it at a custom path
./Export-CertBundle.ps1 -Path C:\tmp\corp_certs.pem

.EXAMPLE
# Python (requests, pip)
# Mitigation: point Python/OpenSSL tools to the generated PEM bundle.
$env:SSL_CERT_FILE = "$PWD/corp_certs.pem"
python -c "import requests; print(requests.get('https://pypi.org').status_code)"
pip --cert "$PWD/corp_certs.pem" install requests

.EXAMPLE
# Node.js and npm
# Mitigation: add extra trusted CAs for Node runtime and npm registry calls.
$env:NODE_EXTRA_CA_CERTS = "$PWD/corp_certs.pem"
node -e "require('https').get('https://registry.npmjs.org', r => console.log(r.statusCode))"
npm config set cafile "$PWD/corp_certs.pem"

.EXAMPLE
# curl
# Mitigation: pass the bundle explicitly for TLS verification.
curl.exe --cacert "$PWD/corp_certs.pem" https://example.com

.EXAMPLE
# Git (clone/fetch over HTTPS)
# Mitigation: configure Git to trust the bundle.
git config --global http.sslCAInfo "$PWD/corp_certs.pem"
git ls-remote https://github.com/git/git.git

.EXAMPLE
# Docker build/runtime (Linux base images)
# Mitigation: copy the certificate and update container trust store.
# Assumption: corp_certs.pem is in the Docker build context (usually the current build directory).
# Dockerfile
# FROM ubuntu:24.04
# COPY corp_certs.pem /usr/local/share/ca-certificates/corp_certs.crt
# RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates

.EXAMPLE
# 1) LocalStack container: npm install fails with Netskope TLS errors
# Symptom examples: CERTIFICATE_VERIFY_FAILED, self signed certificate in certificate chain
# Mitigation: copy the generated bundle into the image, update OS trust, and point Node/npm to it.
# Assumption: corp_certs.pem is in the Docker build context when using COPY.
# Dockerfile
# FROM localstack/localstack:latest
# USER root
# COPY corp_certs.pem /usr/local/share/ca-certificates/corp_certs.crt
# RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates
# ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
# ENV NPM_CONFIG_CAFILE=/etc/ssl/certs/ca-certificates.crt
# USER localstack
#
# 2) Example run commands if the file is mounted instead of baked into the image:
# 1) Start LocalStack with the certificate mounted.
# 2) Run a follow-up command in the running container to rebuild the CA bundle.
#    This is required because mounting alone does not update /etc/ssl/certs/ca-certificates.crt.
# 3) Reliability note: for repeatable environments, baking the certificate into the image is
#    usually more reliable than runtime updates.
# docker run -d --name localstack ^
#   -v "$PWD/corp_certs.pem:/usr/local/share/ca-certificates/corp_certs.crt" ^
#   -e NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt ^
#   -e NPM_CONFIG_CAFILE=/etc/ssl/certs/ca-certificates.crt ^
#   localstack/localstack:latest
# docker exec -u root localstack sh -lc "update-ca-certificates"

.EXAMPLE
# Java tools (Maven/Gradle) workaround
# Java often expects a Java truststore, not a PEM bundle. A simple workaround on Windows is
# to use the Windows trust store directly:
$env:JAVA_TOOL_OPTIONS = "-Djavax.net.ssl.trustStoreType=Windows-ROOT"
mvn -v

.EXAMPLE
# WSL Ubuntu (Linux shell on Windows)
# Motivation: browsers may work while WSL CLI tools fail because they use Linux trust settings.
# Mitigation: install the generated bundle into Ubuntu's CA store, then validate.
# In WSL bash:
# sudo cp /mnt/c/tmp/corp_certs.pem /usr/local/share/ca-certificates/corp_certs.crt
# (Places certificate in the source directory)
# 
# sudo update-ca-certificates
# (Compiles all certificates from /usr/local/share/ca-certificates/ into the master bundle at /etc/ssl/certs/ca-certificates.crt)
# 
# curl https://example.com
# git ls-remote https://github.com/git/git.git
#
# Optional per-tool overrides (if an app still fails):
# Note: these point to /etc/ssl/certs/ca-certificates.crt (the compiled bundle), NOT the source directory.
# export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
# export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
# export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
# export NPM_CONFIG_CAFILE=/etc/ssl/certs/ca-certificates.crt
# export GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt
# export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

#>
[CmdletBinding()]
param (
    [Parameter()]
    [string] $Path = "./corp_certs.pem"
)

try
{
    $ParentDir = Split-Path -LiteralPath $Path -Parent
    if ([string]::IsNullOrWhiteSpace($ParentDir))
    {
        $ParentDir = "."
    }

    if (!(Test-Path -LiteralPath $ParentDir -PathType Container -ErrorAction Stop))
    {
        throw "The directory '$ParentDir' does not exist. Please provide a valid path."
    }

    $ResolvedParent = (Resolve-Path -LiteralPath $ParentDir -ErrorAction Stop).Path
    $Path = Join-Path -Path $ResolvedParent -ChildPath (Split-Path -LiteralPath $Path -Leaf)
}
catch
{
    Write-Error "Invalid output path '$Path'. $_"
    exit 1
}

try 
{
    $CertS = @(
        (Get-ChildItem Cert:\CurrentUser\Root -ErrorAction Stop)
        (Get-ChildItem Cert:\LocalMachine\Root -ErrorAction Stop)
        (Get-ChildItem Cert:\CurrentUser\CA -ErrorAction Stop)
        (Get-ChildItem Cert:\LocalMachine\CA -ErrorAction Stop)
    ) |
        Where-Object { $_.RawData -ne $null } |
        Sort-Object -Property Thumbprint -Unique
}
catch 
{
    Write-Error "Failed to read one or more Windows certificate stores. $_"
    exit 1
}

if (!$CertS) 
{
    Write-Error "No certificates with raw data were found in the selected Windows certificate stores."
    exit 1
}

try 
{
    $CertBundle = foreach ($Cert in $CertS) 
    {
        "-----BEGIN CERTIFICATE-----"
        [System.Convert]::ToBase64String($Cert.RawData, "InsertLineBreaks") -replace "`r`n", "`n"
        "-----END CERTIFICATE-----"
        ""
    }

    $CertBundle -join "`n" | Out-File -Encoding ascii $Path -NoNewline -ErrorAction Stop
    if ($VerbosePreference)    {
        Write-Verbose "Successfully wrote certificate bundle to: $Path"
    }
}
catch 
{
    Write-Error "Failed to write certificate bundle to: $Path`n$_"
    exit 1
}

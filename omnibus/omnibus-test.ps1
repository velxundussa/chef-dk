# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

$channel = "$Env:CHANNEL"
If ([string]::IsNullOrEmpty($channel)) { $channel = "unstable" }

$product = "$Env:PRODUCT"
If ([string]::IsNullOrEmpty($product)) { $product = "chefdk" }

$version = "$Env:VERSION"
If ([string]::IsNullOrEmpty($version)) { $version = "latest" }

. C:\buildkite-agent\bin\load-omnibus-toolchain.ps1

If ($env:OMNIBUS_WINDOWS_ARCH -eq "x86") {
  $architecture = "i386"
}
ElseIf ($env:OMNIBUS_WINDOWS_ARCH -eq "x64") {
  $architecture = "x86_64"
}

Write-Output "--- Downloading $channel $product $version"
$download_url = C:\opscode\omnibus-toolchain\embedded\bin\mixlib-install.bat download --url --channel "$channel" "$product" --version "$version" --architecture "$architecture"
$package_file = "$Env:Temp\$(Split-Path -Path $download_url -Leaf)"
Invoke-WebRequest -OutFile "$package_file" -Uri "$download_url"

Write-Output "--- Checking that $package_file has been signed."
If ((Get-AuthenticodeSignature "$package_file").Status -eq 'Valid') {
  Write-Output "Verified $package_file has been signed."
}
Else {
  Write-Output "Exiting with an error because $package_file has not been signed. Check your omnibus project config."
  exit 1
}

Write-Output "--- Installing $channel $product $version"
Start-Process "$package_file" /quiet -Wait

Write-Output "--- Running verification for $channel $product $version"

# Ensure the calling environment (disapproval look Bundler) does not
# infect our Ruby environment created by the `chef` cli.
$env_vars = "_ORIGINAL_GEM_PATH", "BUNDLE_BIN_PATH", "BUNDLE_GEMFILE", "GEM_HOME", "GEM_PATH", "GEM_ROOT", "RUBYLIB", "RUBYOPT", "RUBY_ENGINE", "RUBY_ROOT", "RUBY_VERSION", "BUNDLER_VERSION"
foreach ($env_var in $env_vars) {
  # Remove-Item Env:$env_var
}

# Ensure the msys2 build dlls are not on the path
$Env:PATH="C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\opscode\chefdk\bin"

# Run this last so the correct exit code is propagated
chef verify
If ($lastexitcode -ne 0) { Exit $lastexitcode }

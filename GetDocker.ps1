<# 
.SYNOPSIS

Automates the Windows containers and Docker installation process documented 
at https://aka.ms/containers to save us all a bit of typing.

.DESCRIPTION

This script will configure your Windows Server 2016 TP5 system for running Docker. I've
automated the steps documented on the Microsoft site for installing containers and tried
to provide a relatively idempotent way to run this script and have the system configured
as needed.

.PARAMETER Path

The directory you want docker installed into.

.PARAMETER Url

Overrides the default download location for Docker since this is all in beta.
Defaults to https://aka.ms/tp5/b

.NOTES

In the initial blog post there are a few restart steps so I tried to push those
into one initial step when the directory is first created.  If anything is missing
from this script feel free to make a pull request or log an issue for changes.
#>
param (
    $Url = "https://aka.ms/tp5/b",
    $Path = "C:\Program Files\Docker"
)

function prep_environment {
    If (!(Test-Path $Path)) {
        Write-Host "Creating Docker program directory..."
        New-Item -Type Directory -Path $Path -Force *>$null
    }
    $EnvPath = $env:path
    if (!($EnvPath -match '$Path')) {
        Write-Host "Adding Docker path to environment variables..."
        [Environment]::SetEnvironmentVariable("Path", $env:Path + ";${Path}", [EnvironmentVariableTarget]::Machine)
    }
}

function download_docker {
    Write-Host "Downloading dockerd.exe..."
    Invoke-WebRequest -Uri ${Url}\dockerd -OutFile ${Path}\dockerd.exe
    Write-Host "Downloading docker.exe..."
    Invoke-WebRequest -Uri ${Url}\docker -OutFile ${Path}\docker.exe
}

function configure_service {
    $service = (Get-Service docker -ErrorVariable serviceError -ErrorAction SilentlyContinue).Status
    if ($serviceError) {
        Write-Host "Registering Docker service..."
        dockerd --register-service
    }
    if ($service -ne 'Running') {
        Write-Host "Attempting to start Docker service..."
        Start-Service docker
        Get-Service Docker
    } else {
        Write-Host "Docker is ${service}."
    }
}

# Check if the Containers role is installed.
If (!(Get-WindowsFeature 'Containers').Installed) {
    Write-Host "Windows feature 'Containers' not installed. Installing..."
    Install-WindowsFeature Containers
    If ((Get-WindowsFeature 'Containers').Installed) {
        prep_environment
        Write-Host "Windows feature 'Containers' successfully installed."
        Write-Host "You must restart your computer. Type 'Restart-Computer -Force' to reboot"
        Write-Host "then run this script again."
        Write-Host "Exiting..."
        break
    } else {
        Write-Host "Windows feature 'Containers' did not install correctly.  Please try again."
        break
    }
} else {
    If (!(Test-Path "${Path}\dockerd.exe")) {
        download_docker
    }
    configure_service

}




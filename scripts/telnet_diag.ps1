<#
.SYNOPSIS
    华为/H3C 交换机 Telnet 诊断脚本
    通过 TCP 直连交换机执行命令，无需安装 Telnet 客户端

.PARAMETER Ip
    交换机 IP 地址

.PARAMETER Port
    Telnet 端口，默认 23

.PARAMETER Password
    交换机 Telnet 密码

.PARAMETER Commands
    要执行的命令数组。留空则执行默认诊断命令集。

.PARAMETER OutputFile
    输出文件路径（可选），不指定则输出到控制台

.PARAMETER Timeout
    每条命令等待超时（毫秒），默认 5000

.EXAMPLE
    .\telnet_diag.ps1 -Ip 172.16.20.217 -Password "xxx" -Commands "display version","display interface brief"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Ip,

    [int]$Port = 23,

    [Parameter(Mandatory=$true)]
    [string]$Password,

    [string[]]$Commands,

    [string]$OutputFile,

    [int]$Timeout = 5000
)

$ErrorActionPreference = "Stop"
$encoder = New-Object System.Text.ASCIIEncoding

# Default diagnostic commands if not specified
if (-not $Commands -or $Commands.Count -eq 0) {
    $Commands = @(
        "screen-length 0 temporary",
        "display version",
        "display device",
        "display ip interface brief",
        "display interface brief"
    )
}

function Write-ColorOutput {
    param([string]$Text, [string]$Color = "White")
    if ($OutputFile) {
        $Text | Out-File -FilePath $OutputFile -Append -Encoding UTF8
    } else {
        Write-Host $Text -ForegroundColor $Color
    }
}

function Send-Command {
    param(
        [System.Net.Sockets.NetworkStream]$Stream,
        [string]$Command,
        [int]$WaitMs = $Timeout
    )

    Write-ColorOutput ">>> $Command" "Yellow"

    # Send command
    $cmdBytes = $encoder.GetBytes("$Command`r`n")
    $Stream.Write($cmdBytes, 0, $cmdBytes.Length)

    # Wait for response
    Start-Sleep -Milliseconds $WaitMs

    # Handle paging: send space to continue when "More" appears
    $maxPages = 50
    $pageCount = 0
    $buffer = New-Object byte[] 65536
    $allOutput = ""

    do {
        Start-Sleep -Milliseconds 800
        $hasData = $false
        while ($Stream.DataAvailable) {
            $hasData = $true
            $read = $Stream.Read($buffer, 0, $buffer.Length)
            $response = $encoder.GetString($buffer, 0, $read)
            $allOutput += $response
        }

        if ($allOutput -match "---- More ----$") {
            $pageCount++
            if ($pageCount -ge $maxPages) { break }
            # Send space to continue
            $spaceByte = $encoder.GetBytes(" ")
            $Stream.Write($spaceByte, 0, $spaceByte.Length)
            Start-Sleep -Milliseconds 500
            $hasData = $true  # Continue loop
        }
    } while ($hasData)

    # Clean up escape sequences and "More" artifacts
    $allOutput = $allOutput -replace '\x1B\[\d+D', ''  # Remove cursor movement
    $allOutput = $allOutput -replace '---- More ----', ''
    $allOutput = $allOutput -replace '\x1B\[\d+D', ''
    $allOutput = $allOutput.Trim()

    Write-ColorOutput $allOutput "White"
    Write-ColorOutput "" "White"

    return $allOutput
}

# ========== Main ==========
try {
    $client = New-Object System.Net.Sockets.TcpClient
    $client.ReceiveTimeout = 8000
    $client.SendTimeout = 5000

    Write-ColorOutput "[连接 $Ip`:$Port ...]" "Cyan"
    $client.Connect($Ip, $Port)
    $stream = $client.GetStream()

    # Read initial banner and wait for password prompt
    Start-Sleep -Milliseconds 1500
    $buffer = New-Object byte[] 65536
    $banner = ""
    while ($stream.DataAvailable) {
        $read = $stream.Read($buffer, 0, $buffer.Length)
        $banner += $encoder.GetString($buffer, 0, $read)
    }
    Write-ColorOutput $banner "DarkGray"

    # Send password
    Write-ColorOutput "[认证中...]" "Cyan"
    $passBytes = $encoder.GetBytes("$Password`r`n")
    $stream.Write($passBytes, 0, $passBytes.Length)
    Start-Sleep -Milliseconds 2000

    # Read login result
    $loginResponse = ""
    while ($stream.DataAvailable) {
        $read = $stream.Read($buffer, 0, $buffer.Length)
        $loginResponse += $encoder.GetString($buffer, 0, $read)
    }
    Write-ColorOutput $loginResponse "DarkGray"

    # Check login success
    if ($loginResponse -match "Error|failed|invalid|incorrect") {
        Write-ColorOutput "[登录失败！请检查密码]" "Red"
        exit 1
    }

    if ($loginResponse -match "<.+>" -or $loginResponse -match "\[.+\]") {
        Write-ColorOutput "[登录成功]" "Green"
    }

    # Execute commands
    foreach ($cmd in $Commands) {
        try {
            $result = Send-Command -Stream $stream -Command $cmd
        } catch {
            Write-ColorOutput "[命令执行异常: $_]" "Red"
        }
    }

} catch {
    Write-ColorOutput "[错误: $_]" "Red"
} finally {
    # Send quit
    try {
        $quitBytes = $encoder.GetBytes("quit`r`n")
        $stream.Write($quitBytes, 0, $quitBytes.Length)
        Start-Sleep -Milliseconds 500
    } catch {}

    if ($client.Connected) {
        $client.Close()
    }
    Write-ColorOutput "`n[连接已关闭]" "Cyan"
}

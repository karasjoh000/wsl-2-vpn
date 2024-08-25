$ProxyInfo = @"
export http_proxy="http_proxy here or exclude line"
export ftp_proxy="..."
export https_proxy="..."
export socks_proxy="..."
export no_proxy="no proxy here or exlude line"
"@


## Find all profiles that are wsl 2
# get a list of profiles 
$wslOutput = wsl.exe -l -v | Out-String
# for some reason there is null characters in ouput so removing those. 
$wslOutput = $wslOutput -replace [char]0, ''
# the lines also have extra newlines in there. Remove those too.
$lines = $wslOutput -split "`r`n" | Where-Object { $_.Trim() -ne "" }
$dataRows = $lines[1..($lines.Length - 1)]
# remove * where it is present
$dataRowsClean = $dataRows -replace '\*', ''
# remove leading and trailing spaces
$dataRowsClean = $dataRowsClean | ForEach-Object { $_.Trim() }
# Replace multiple spaces with a single space
$dataRowsClean = $dataRowsClean | ForEach-Object { $_ -replace '\s+', ' ' }
# empty array to store wsl 2 profiles
$wsl2profiles = @()
# find wsl 2 profiles 
foreach ($entry in $dataRowsClean) {
    $profile = $entry -split ' '
    if ($profile[2] -eq "2") {
        $wsl2profiles += $profile[0]
    }
}


## Add routes for wsl 2 profiles in order to fix vpn issue
## credits go to https://live.paloaltonetworks.com/t5/globalprotect-discussions/globalprotect-blocks-the-network-traffic-of-wsl2/m-p/507821/highlight/true#M2955
foreach ($profile in $wsl2profiles) {
    $var= wsl.exe -d $profile -e /bin/bash --noprofile --norc -c "/sbin/ip -o -4 addr list eth0"
    $wsl_addr = $var.split()[6].split('/')[0]
    $var2 = wsl.exe -d $profile -e /bin/bash --noprofile --norc -c "/sbin/ip -o route show table main default"
    $wsl_gw = $var2.split()[2]
    $ifindex = Get-NetRoute -DestinationPrefix $wsl_gw/32 | Select-Object -ExpandProperty "IfIndex"
    $routemetric = Get-NetRoute -DestinationPrefix $wsl_gw/32 | Select-Object -ExpandProperty "RouteMetric"
    route add $wsl_addr mask 255.255.255.255 $wsl_addr metric $routemetric if $ifindex
}

## Get dns server from the vpn adapter or default whichever is default (Lowest InterfaceMetric)
# Assuming the default interface has a dnsserver
# Assuming /etc/wsl.conf: [network]\ngenerateResolvConf = false
$firstIf = Get-NetIPInterface | Where-Object { $_.ConnectionState -eq "Connected" } | Sort-Object -Property InterfaceMetric | Select-Object -First 1
$firstIfIndex = $firstIf.InterfaceIndex
$dnsServers = Get-DnsClientServerAddress -InterfaceIndex $firstIfIndex -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses
$dnsServersStringArray = $dnsServers | ForEach-Object { "nameserver $_" }
foreach ($profile in $wsl2profiles) {
    wsl.exe -d $profile -u root -e /bin/bash --noprofile --norc -c "rm -rf /etc/resolv.conf"
    foreach ($dns in $dnsServersStringArray) {
        wsl.exe -d $profile -u root -e /bin/bash --noprofile --norc -c "echo $dns >> /etc/resolv.conf"
    }
}

## set proxy varaiables in /etc/environment and /etc/profile
# only matches palto alto and cisco anyconnect vpns. Feel free to add any other into match.
$firstIfDescription = Get-NetAdapter | Where-Object { $_.ifIndex -eq $firstIfIndex } | Where-Object { ($_.InterfaceDescription -match "PANGP Virtual Ethernet|Cisco AnyConnect") -and ($_.Status -eq "Up") }
foreach ($profile in $wsl2profiles) {
    if ($firstIfDescription -eq $null -or $firstIfDescription.Count -eq 0) {
        # remove proxy info 
        wsl.exe -d $profile -u root -e /bin/bash --noprofile --norc -c "sed -i '/export http_proxy/d' /etc/environment"
        wsl.exe -d $profile -u root -e /bin/bash --noprofile --norc -c "sed -i '/export ftp_proxy/d' /etc/environment"
        wsl.exe -d $profile -u root -e /bin/bash --noprofile --norc -c "sed -i '/export https_proxy/d' /etc/environment"
        wsl.exe -d $profile -u root -e /bin/bash --noprofile --norc -c "sed -i '/export socks_proxy/d' /etc/environment"
        wsl.exe -d $profile -u root -e /bin/bash --noprofile --norc -c "sed -i '/export no_proxy/d' /etc/environment"
        wsl.exe -d $profile -u root -e /bin/bash --noprofile --norc -c "sed -i '/export http_proxy/d' /etc/profile"
        wsl.exe -d $profile -u root -e /bin/bash --noprofile --norc -c "sed -i '/export ftp_proxy/d' /etc/profile"
        wsl.exe -d $profile -u root -e /bin/bash --noprofile --norc -c "sed -i '/export https_proxy/d' /etc/profile"
        wsl.exe -d $profile -u root -e /bin/bash --noprofile --norc -c "sed -i '/export socks_proxy/d' /etc/profile"
        wsl.exe -d $profile -u root -e /bin/bash --noprofile --norc -c "sed -i '/export no_proxy/d' /etc/profile"
    
    } else {
        foreach ($proxy in $ProxyInfo -split "`r`n|`n|`r") {
            wsl.exe -d $profile -u root -e /bin/bash --noprofile --norc -c "echo $proxy >> /etc/environment"
            wsl.exe -d $profile -u root -e /bin/bash --noprofile --norc -c "echo $proxy >> /etc/profile"
        }
    }
}

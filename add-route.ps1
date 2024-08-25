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
    $var=C:\Windows\System32\wsl.exe -d $profile -e /bin/bash --noprofile --norc -c "/sbin/ip -o -4 addr list eth0"
    $wsl_addr = $var.split()[6].split('/')[0]
    $var2 = C:\Windows\System32\wsl.exe -d $profile -e /bin/bash --noprofile --norc -c "/sbin/ip -o route show table main default"
    $wsl_gw = $var2.split()[2]
    $ifindex = Get-NetRoute -DestinationPrefix $wsl_gw/32 | Select-Object -ExpandProperty "IfIndex"
    $routemetric = Get-NetRoute -DestinationPrefix $wsl_gw/32 | Select-Object -ExpandProperty "RouteMetric"
    route add $wsl_addr mask 255.255.255.255 $wsl_addr metric $routemetric if $ifindex
}

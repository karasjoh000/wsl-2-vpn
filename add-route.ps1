# get all wsl profiles that have wsl verison 2
# $wsl_profiles = wsl.exe -l -v
# $wsl_profiles = $wsl_profiles -split "`n" | Select-String -Pattern "(\w+)-(\d+.\d+)" | ForEach-Object { $_.Matches.Groups[1].Value + "-" + $_.Matches.Groups[2].Value }

$var=C:\Windows\System32\wsl.exe -d Ubuntu-24.04 -e /bin/bash --noprofile --norc -c "/sbin/ip -o -4 addr list eth0"
$wsl_addr = $var.split()[6].split('/')[0]
$var2 = C:\Windows\System32\wsl.exe -d Ubuntu-24.04 -e /bin/bash --noprofile --norc -c "/sbin/ip -o route show table main default"
$wsl_gw = $var2.split()[2]
$ifindex = Get-NetRoute -DestinationPrefix $wsl_gw/32 | Select-Object -ExpandProperty "IfIndex"
$routemetric = Get-NetRoute -DestinationPrefix $wsl_gw/32 | Select-Object -ExpandProperty "RouteMetric"
route add $wsl_addr mask 255.255.255.255 $wsl_addr metric $routemetric if $ifindex
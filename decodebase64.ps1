


$file = ".\credreport.txt"
$data = Get-Content $file
[System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($data)) >> credout.txt

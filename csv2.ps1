Import-Csv -Delimiter " " -Header a,b,c,d,e report.csv foreach{ Write-Host $_.d }